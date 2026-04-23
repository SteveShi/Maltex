import Foundation

// MARK: - Tracker Source Data Structures

struct TrackerSource: Identifiable, Hashable, Codable {
    var id: String { url }
    let label: String
    let url: String
    let isCDN: Bool
}

struct TrackerSourceGroup: Identifiable {
    let id: String
    let label: String
    let sources: [TrackerSource]
}

// MARK: - Preset Tracker Sources

/// Predefined tracker sources from popular open-source tracker list repositories.
/// Mirrors the structure used in motrix-next's `trackerSources.ts`.
enum TrackerPresets {
    static let groups: [TrackerSourceGroup] = [
        TrackerSourceGroup(
            id: "ngosang",
            label: "ngosang/trackerslist",
            sources: [
                TrackerSource(
                    label: "trackers_best.txt",
                    url: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "trackers_best_ip.txt",
                    url: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "trackers_all.txt",
                    url: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "trackers_all_ip.txt",
                    url: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "trackers_best.txt",
                    url: "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best.txt",
                    isCDN: true
                ),
                TrackerSource(
                    label: "trackers_best_ip.txt",
                    url: "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt",
                    isCDN: true
                ),
                TrackerSource(
                    label: "trackers_all.txt",
                    url: "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_all.txt",
                    isCDN: true
                ),
                TrackerSource(
                    label: "trackers_all_ip.txt",
                    url: "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_all_ip.txt",
                    isCDN: true
                ),
            ]
        ),
        TrackerSourceGroup(
            id: "xiu2",
            label: "XIU2/TrackersListCollection",
            sources: [
                TrackerSource(
                    label: "best.txt",
                    url: "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/best.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "all.txt",
                    url: "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "http.txt",
                    url: "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/http.txt",
                    isCDN: false
                ),
                TrackerSource(
                    label: "best.txt",
                    url: "https://cdn.jsdelivr.net/gh/XIU2/TrackersListCollection/best.txt",
                    isCDN: true
                ),
                TrackerSource(
                    label: "all.txt",
                    url: "https://cdn.jsdelivr.net/gh/XIU2/TrackersListCollection/all.txt",
                    isCDN: true
                ),
                TrackerSource(
                    label: "http.txt",
                    url: "https://cdn.jsdelivr.net/gh/XIU2/TrackersListCollection/http.txt",
                    isCDN: true
                ),
            ]
        ),
    ]

    /// All preset source URLs as a flat set for quick lookup
    static let allPresetURLs: Set<String> = {
        Set(groups.flatMap { $0.sources.map(\.url) })
    }()

    /// Default selected source URLs for first launch
    static let defaultSelectedURLs: [String] = [
        "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best.txt"
    ]
}

// MARK: - Tracker Fetch Result

struct TrackerFetchResult {
    struct Failure {
        let url: String
        let reason: String
    }

    let trackers: [String]
    let failures: [Failure]

    var allSucceeded: Bool { failures.isEmpty }
    var hasData: Bool { !trackers.isEmpty }
}

// MARK: - Tracker Probe

/// Reachability status of a single tracker URL.
enum TrackerProbeStatus: String, Sendable {
    case unknown   // Not yet probed or non-probeable protocol
    case checking  // Probe in progress
    case online    // HTTP HEAD succeeded
    case offline   // HTTP HEAD failed or timed out
}

/// A single tracker entry with probe state, for display in the probe list.
struct TrackerEntry: Identifiable {
    var id: String { url }
    let url: String
    let protocolScheme: String
    var status: TrackerProbeStatus

    /// Whether this tracker can be probed (HTTP/HTTPS only).
    /// UDP/WS/WSS trackers can't be checked via HTTP HEAD.
    var isProbeable: Bool {
        let scheme = protocolScheme.lowercased()
        return scheme == "http" || scheme == "https"
    }

    /// Extracts protocol scheme from a tracker URL (e.g. "udp", "http", "https").
    static func parseProtocol(from url: String) -> String {
        guard let match = url.range(of: #"^(\w+)://"#, options: .regularExpression) else {
            return "unknown"
        }
        return String(url[match]).replacingOccurrences(of: "://", with: "")
    }

    /// Builds tracker entries from a newline-separated tracker string.
    static func fromTrackerString(_ text: String) -> [TrackerEntry] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { url in
                TrackerEntry(
                    url: url,
                    protocolScheme: parseProtocol(from: url),
                    status: .unknown
                )
            }
    }
}

