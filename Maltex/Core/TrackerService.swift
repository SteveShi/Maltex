import Foundation

// MARK: - TrackerService

/// Service for fetching BT tracker lists from remote sources and merging them.
/// Inspired by motrix-next's `tracker.ts` and `tracker.rs` approach.
@MainActor
@Observable
final class TrackerService {
    private(set) var isSyncing = false
    private(set) var isProbing = false

    /// Generation counter to discard results from cancelled probes.
    private var probeGeneration = 0

    /// Fetches tracker lists from the given source URLs concurrently,
    /// merges and deduplicates them.
    ///
    /// - Parameters:
    ///   - sourceURLs: URLs pointing to plain-text tracker list files
    ///   - proxyConfig: Optional proxy configuration
    /// - Returns: A structured result with merged trackers and per-URL failures
    func fetchTrackers(
        from sourceURLs: [String],
        proxyHost: String? = nil,
        proxyPort: String? = nil
    ) async -> TrackerFetchResult {
        guard !sourceURLs.isEmpty else {
            return TrackerFetchResult(trackers: [], failures: [])
        }

        isSyncing = true
        defer { isSyncing = false }

        let session = buildSession(proxyHost: proxyHost, proxyPort: proxyPort)
        defer { session.finishTasksAndInvalidate() }

        var allBodies: [String] = []
        var failures: [TrackerFetchResult.Failure] = []

        // Fetch sources concurrently using TaskGroup
        let results = await withTaskGroup(
            of: (String, Result<String, Error>).self,
            returning: [(String, Result<String, Error>)].self
        ) { group in
            for urlString in sourceURLs {
                group.addTask { [session] in
                    do {
                        let body = try await self.fetchSingle(
                            urlString: urlString, session: session)
                        return (urlString, .success(body))
                    } catch {
                        return (urlString, .failure(error))
                    }
                }
            }

            var collected: [(String, Result<String, Error>)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for (url, result) in results {
            switch result {
            case .success(let body):
                allBodies.append(body)
            case .failure(let error):
                failures.append(
                    TrackerFetchResult.Failure(url: url, reason: error.localizedDescription))
            }
        }

        let merged = Self.mergeTrackers(allBodies)
        return TrackerFetchResult(trackers: merged, failures: failures)
    }

    // MARK: - Tracker Probing

    /// Probes each tracker URL sequentially for reachability.
    /// HTTP/HTTPS trackers get a HEAD request; UDP/WS/WSS are marked as `unknown`.
    /// Calls `onStatusUpdate` after each tracker is probed so the UI can update progressively.
    ///
    /// - Parameters:
    ///   - entries: The tracker entries to probe
    ///   - onStatusUpdate: Called with (url, status) after each probe completes
    func probeTrackers(
        entries: [TrackerEntry],
        onStatusUpdate: @escaping @Sendable (String, TrackerProbeStatus) -> Void
    ) async {
        let gen = probeGeneration + 1
        probeGeneration = gen
        isProbing = true

        let client = buildProbeSession()
        defer {
            client.finishTasksAndInvalidate()
            if gen == probeGeneration {
                isProbing = false
            }
        }

        for entry in entries {
            // Abort if a newer probe or cancel has occurred
            guard gen == probeGeneration else { return }

            let status = await probeSingle(url: entry.url, session: client)
            // Check again after async work
            guard gen == probeGeneration else { return }
            onStatusUpdate(entry.url, status)
        }
    }

    /// Cancels any in-progress probe by bumping the generation counter.
    func cancelProbe() {
        probeGeneration += 1
        isProbing = false
    }

    // MARK: - Private

    /// Probes a single tracker URL. Non-HTTP protocols return `.unknown`.
    private nonisolated func probeSingle(url: String, session: URLSession) async -> TrackerProbeStatus {
        let scheme = TrackerEntry.parseProtocol(from: url).lowercased()
        guard scheme == "http" || scheme == "https" else {
            return .unknown
        }

        guard let requestURL = URL(string: url) else {
            return .offline
        }

        var request = URLRequest(url: requestURL, timeoutInterval: 5)
        request.httpMethod = "HEAD"

        do {
            let (_, _) = try await session.data(for: request)
            return .online
        } catch {
            return .offline
        }
    }

    private func buildProbeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }

    private nonisolated func fetchSingle(urlString: String, session: URLSession) async throws
        -> String
    {
        // Append cache-busting timestamp like motrix-next does
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let separator = urlString.contains("?") ? "&" : "?"
        let requestURLString = "\(urlString)\(separator)t=\(timestamp)"

        guard let url = URL(string: requestURLString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
            !(200..<300).contains(httpResponse.statusCode)
        {
            throw URLError(.badServerResponse)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return body
    }

    private func buildSession(proxyHost: String?, proxyPort: String?) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        if let host = proxyHost, !host.isEmpty,
            let portStr = proxyPort, let port = Int(portStr), port > 0
        {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy: host,
                kCFNetworkProxiesHTTPSPort: port,
            ]
        }

        return URLSession(configuration: config)
    }

    /// Merges multiple raw tracker list texts, splits by newlines,
    /// trims whitespace, removes empty lines, and deduplicates.
    nonisolated static func mergeTrackers(_ rawTexts: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for text in rawTexts {
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for line in lines where !seen.contains(line) {
                seen.insert(line)
                result.append(line)
            }
        }

        return result
    }

    /// Validates whether a string is a valid HTTP/HTTPS URL
    /// suitable for use as a tracker source.
    nonisolated static func isValidTrackerSourceURL(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased()
        else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
}
