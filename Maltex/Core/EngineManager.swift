import Foundation

@MainActor
class EngineManager {
    static let shared = EngineManager()
    private var process: Process?

    var userDataPath: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0]
        return appSupport.appendingPathComponent("Maltex", isDirectory: true)
    }

    var sessionPath: URL {
        userDataPath.appendingPathComponent("download.session")
    }

    var configPath: URL {
        userDataPath.appendingPathComponent("aria2.conf")
    }

    var logPath: URL {
        userDataPath.appendingPathComponent("aria2.log")
    }

    var appLogPath: URL {
        userDataPath.appendingPathComponent("maltex.log")
    }

    var stderrPath: URL {
        userDataPath.appendingPathComponent("aria2_stderr.log")
    }

    func start(settings: SettingsStore = SettingsStore()) {
        stop()  // Ensure clean start
        // Pre-flight: Kill any rogue aria2c processes that might be holding the port
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-9", "aria2c"]
        try? task.run()
        task.waitUntilExit()
        
        // 1. Prepare environment
        try? FileManager.default.createDirectory(
            at: userDataPath, withIntermediateDirectories: true)

        // 2. Locate binary
        let bundleBin = Bundle.main.url(forResource: "aria2c", withExtension: nil)
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
#if arch(arm64)
        let archFolder = "arm64"
#else
        let archFolder = "x64"
#endif
        let devBin = currentDir.appendingPathComponent(
            "extra/darwin/\(archFolder)/engine/aria2c")
        let binURL = bundleBin ?? devBin

        guard FileManager.default.fileExists(atPath: binURL.path) else {
            let msg = "[Engine] CRITICAL: binary not found"
            try? msg.appendLineToURL(fileURL: appLogPath)
            return
        }

        // 3. Setup Process (Using minimal reliable arguments)
        let process = Process()
        process.executableURL = binURL

        var args = [
            "--enable-rpc",
            "--rpc-listen-all=false",
            "--rpc-listen-port=\(settings.rpcPort)",
            "--rpc-allow-origin-all=true",
            "--dir=\(settings.downloadPath.isEmpty ? "/tmp" : settings.downloadPath)",
            "--log=\(logPath.path)",
            "--log-level=notice",
            "--max-concurrent-downloads=\(settings.maxConcurrentDownloads)",
            "--max-connection-per-server=\(settings.maxConnectionPerServer)",
            "--split=\(settings.maxConnectionPerServer)",
            "--disable-ipv6=true", // Avoid IPv6 bind errors
            "--content-disposition-default-utf8=true",
        ]

        // Only add session support if the file exists and is not empty
        if FileManager.default.fileExists(atPath: sessionPath.path),
           let attr = try? FileManager.default.attributesOfItem(atPath: sessionPath.path),
           (attr[.size] as? UInt64 ?? 0) > 0 {
            args.append("--input-file=\(sessionPath.path)")
        }
        args.append("--save-session=\(sessionPath.path)")

        if !settings.trackerServers.isEmpty {
            let trackers = settings.trackerServers.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
            if !trackers.isEmpty {
                args.append("--bt-tracker=\(trackers)")
            }
        }

        if !settings.rpcSecret.isEmpty {
            args.append("--rpc-secret=\(settings.rpcSecret)")
        }

        if settings.maxOverallDownloadLimit > 0 {
            args.append("--max-overall-download-limit=\(settings.maxOverallDownloadLimit)K")
        }
        if settings.maxOverallUploadLimit > 0 {
            args.append("--max-overall-upload-limit=\(settings.maxOverallUploadLimit)K")
        }
        if settings.proxyEnabled && !settings.proxyHost.isEmpty {
            let proxyUrl = "\(settings.proxyHost):\(settings.proxyPort)"
            args.append("--all-proxy=\(proxyUrl)")
            if !settings.proxyUser.isEmpty {
                args.append("--all-proxy-user=\(settings.proxyUser)")
                args.append("--all-proxy-passwd=\(settings.proxyPass)")
            }
        }

        process.arguments = args

        // Setup logging to file handles
        if !FileManager.default.fileExists(atPath: stderrPath.path) {
            FileManager.default.createFile(atPath: stderrPath.path, contents: nil)
        }
        if let fileHandle = try? FileHandle(forWritingTo: stderrPath) {
            process.standardError = fileHandle
        }

        let fullCmd = "\(binURL.path) \(args.joined(separator: " "))"
        try? "[Engine] CMD: \(fullCmd)".appendLineToURL(fileURL: appLogPath)
        print("[Engine] Starting: \(binURL.path)")

        do {
            try process.run()
            self.process = process
            let msg = "[Engine] Process started with PID: \(process.processIdentifier)"
            try? msg.appendLineToURL(fileURL: appLogPath)
            print(msg)
            
            // Check if it's still running after a split second
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if process.isRunning {
                    print("[Engine] Process is still running smoothly.")
                } else {
                    let exitCode = process.terminationStatus
                    let errorMsg = "[Engine] CRITICAL: Process exited immediately with code \(exitCode)"
                    try? errorMsg.appendLineToURL(fileURL: self.appLogPath)
                    print(errorMsg)
                }
            }
        } catch {
            let msg = "[Engine] Failed to run: \(error.localizedDescription)"
            try? msg.appendLineToURL(fileURL: appLogPath)
            print(msg)
        }
    }

    func stop() {
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
    }

    func restart() {
        start()
    }
}

extension String {
    func appendLineToURL(fileURL: URL) throws {
        let line = self + "\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }
}
