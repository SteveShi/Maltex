import Foundation
import Combine
import Darwin

@MainActor
class EngineManager: ObservableObject {
    static let shared = EngineManager()

    @Published private(set) var isRunning = false
    @Published private(set) var lastMessage = ""
    @Published private(set) var activeBinaryPath = ""

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

    var pidPath: URL {
        userDataPath.appendingPathComponent("aria2.pid")
    }

    func start(settings: SettingsStore = SettingsStore()) {
        guard process == nil || process?.isRunning == false else {
            print("[Engine] Already running, skip start")
            return
        }

        process = nil
        isRunning = false

        try? FileManager.default.createDirectory(
            at: userDataPath, withIntermediateDirectories: true)
        stopPreviousManagedProcessIfNeeded()

        guard let binURL = resolveBinaryURL(settings: settings),
              FileManager.default.fileExists(atPath: binURL.path)
        else {
            let msg = String(localized: "未找到可用的 Aria2 可执行文件")
            lastMessage = msg
            try? "[Engine] \(msg)".appendLineToURL(fileURL: appLogPath)
            return
        }

        let process = Process()
        process.executableURL = binURL
        let args = buildArguments(settings: settings)
        process.arguments = args

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
            isRunning = true
            activeBinaryPath = binURL.path
            lastMessage = String(localized: "Aria2 内核已启动")
            writeManagedPID(process.processIdentifier)

            let msg = "[Engine] Process started with PID: \(process.processIdentifier)"
            try? msg.appendLineToURL(fileURL: appLogPath)
            print(msg)

            process.terminationHandler = { [weak self] terminatedProcess in
                Task { @MainActor in
                    guard let self else { return }
                    self.isRunning = false
                    self.lastMessage = String(
                        format: String(localized: "Aria2 内核已停止，退出码 %d"),
                        terminatedProcess.terminationStatus
                    )
                    if self.process === terminatedProcess {
                        self.process = nil
                        self.removeManagedPID()
                    }
                }
            }

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
            let msg = String(
                format: String(localized: "Aria2 启动失败: %@"),
                error.localizedDescription
            )
            lastMessage = msg
            try? "[Engine] \(msg)".appendLineToURL(fileURL: appLogPath)
            print(msg)
        }
    }

    func stop(waitForExit: Bool = false) {
        if process?.isRunning == true {
            process?.terminate()
            if waitForExit {
                process?.waitUntilExit()
            }
        }
        process = nil
        isRunning = false
        lastMessage = String(localized: "Aria2 内核已停止")
        removeManagedPID()
    }

    func restart() {
        let settings = SettingsStore()
        restart(settings: settings)
    }

    func restart(settings: SettingsStore) {
        stop(waitForExit: true)
        usleep(200_000)
        start(settings: settings)
    }

    private func buildArguments(settings: SettingsStore) -> [String] {
        var args = [
            "--enable-rpc",
            "--rpc-listen-all=\(settings.rpcListenAll ? "true" : "false")",
            "--rpc-listen-port=\(settings.rpcPort)",
            "--rpc-allow-origin-all=\(settings.rpcAllowOriginAll ? "true" : "false")",
            "--dir=\(settings.downloadPath.isEmpty ? "/tmp" : settings.downloadPath)",
            "--log=\(logPath.path)",
            "--log-level=notice",
            "--max-concurrent-downloads=\(settings.maxConcurrentDownloads)",
            "--max-connection-per-server=\(settings.maxConnectionPerServer)",
            "--split=\(settings.maxConnectionPerServer)",
            "--min-split-size=\(settings.minSplitSize)M",
            "--max-tries=\(settings.maxTries)",
            "--retry-wait=\(settings.retryWait)",
            "--timeout=\(settings.timeout)",
            "--connect-timeout=\(settings.connectTimeout)",
            "--disk-cache=\(settings.diskCache)M",
            "--max-download-result=\(settings.maxDownloadResult)",
            "--file-allocation=\(settings.fileAllocation)",
            "--continue=\(settings.continueDownloads ? "true" : "false")",
            "--auto-file-renaming=\(settings.autoFileRenaming ? "true" : "false")",
            "--allow-overwrite=\(settings.allowOverwrite ? "true" : "false")",
            "--check-certificate=\(settings.checkCertificate ? "true" : "false")",
            "--disable-ipv6=true",
            "--content-disposition-default-utf8=\(settings.contentDispositionDefaultUTF8 ? "true" : "false")",
            "--save-session-interval=\(settings.saveSessionInterval)",
        ]

        if !settings.userAgent.isEmpty {
            args.append("--user-agent=\(settings.userAgent)")
        }
        if !settings.referer.isEmpty {
            args.append("--referer=\(settings.referer)")
        }

        if FileManager.default.fileExists(atPath: sessionPath.path),
           let attr = try? FileManager.default.attributesOfItem(atPath: sessionPath.path),
           (attr[.size] as? UInt64 ?? 0) > 0
        {
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

        args.append("--listen-port=\(settings.btPort)")
        args.append("--dht-listen-port=\(settings.dhtPort)")
        args.append("--enable-dht=true")
        args.append("--bt-enable-lpd=true")
        args.append("--enable-peer-exchange=true")
        args.append("--bt-max-peers=\(settings.btMaxPeers)")
        args.append("--bt-request-peer-speed-limit=\(settings.btRequestPeerSpeedLimit)K")
        args.append("--seed-ratio=\(settings.seedRatio)")
        if settings.seedTime > 0 {
            args.append("--seed-time=\(settings.seedTime)")
        }

        if !settings.upnpEnabled {
            args.append("--disable-upnp=true")
        }
        if settings.btSaveMetadata {
            args.append("--bt-save-metadata=true")
        }
        if settings.btForceEncryption {
            args.append("--bt-require-crypto=true")
            args.append("--bt-min-crypto-level=arc4")
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
            let proxyURL = "\(settings.proxyHost):\(settings.proxyPort)"
            args.append("--all-proxy=\(proxyURL)")
            if !settings.proxyUser.isEmpty {
                args.append("--all-proxy-user=\(settings.proxyUser)")
                args.append("--all-proxy-passwd=\(settings.proxyPass)")
            }
        }

        let extraArguments = settings.extraAria2Arguments
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        args.append(contentsOf: extraArguments)
        return args
    }

    private func resolveBinaryURL(settings: SettingsStore) -> URL? {
        switch settings.aria2BinarySource {
        case .bundled:
            return bundledBinaryURL()
        case .commandLine:
            return commandLineBinaryURL()
        case .custom:
            guard !settings.customAria2Path.isEmpty else { return nil }
            return URL(fileURLWithPath: settings.customAria2Path)
        }
    }

    private func bundledBinaryURL() -> URL? {
        if let bundleBin = Bundle.main.url(forResource: "aria2c", withExtension: nil) {
            return bundleBin
        }
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
#if arch(arm64)
        let archFolder = "arm64"
#else
        let archFolder = "x64"
#endif
        return currentDir.appendingPathComponent("extra/darwin/\(archFolder)/engine/aria2c")
    }

    private func commandLineBinaryURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/aria2c",
            "/usr/local/bin/aria2c",
            "/usr/bin/aria2c",
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        return nil
    }

    private func writeManagedPID(_ pid: Int32) {
        try? "\(pid)".write(to: pidPath, atomically: true, encoding: .utf8)
    }

    private func removeManagedPID() {
        try? FileManager.default.removeItem(at: pidPath)
    }

    private func stopPreviousManagedProcessIfNeeded() {
        guard let pidString = try? String(contentsOf: pidPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidString),
              pid > 0
        else {
            return
        }

        guard kill(pid, 0) == 0 else {
            removeManagedPID()
            return
        }

        kill(pid, SIGTERM)
        usleep(300_000)

        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }
        removeManagedPID()
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
