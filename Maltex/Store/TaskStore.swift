import struct AnyCodable.AnyCodable
@preconcurrency import Aria2Kit

private typealias AnyEncodable = Aria2Kit.AnyEncodable
import Combine
import Foundation
import SwiftUI
import UserNotifications

// MARK: - JSON-RPC Response Wrappers

/// Standard JSON-RPC 2.0 response wrapper. The `id` field is decoded permissively
/// because the spec allows string / number / null.
struct Aria2Response<T: Codable>: Codable {
    let id: AnyCodable?
    let jsonrpc: String
    let result: T?
    let error: Aria2RPCError?
}

struct Aria2RPCError: Codable {
    let code: Int
    let message: String
}

/// 重复下载检测信息：当 aria2 报告 "Same info hash already exists" 时保存上下文，
/// 用于向用户展示确认弹窗并支持强制重新下载。
struct DuplicateDownloadInfo: Identifiable {
    let id = UUID()
    let uri: String
    let options: [String: String]
    let torrentBase64: String?

    /// 是否可以自动重下载（仅磁力链接可从 URI 提取 info hash 用于定位旧任务）。
    var canAutoRedownload: Bool {
        torrentBase64 == nil && uri.lowercased().hasPrefix("magnet:")
    }
}

@MainActor
class TaskStore: ObservableObject {
    @Published var tasks: [DownloadTask] = []
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var shouldPresentEngineError = false
    @Published var lastAddedGid: String?

    // Bug 1: 磁力链接元数据下载完成后，派生下载任务准备弹出确认弹窗的 GID
    @Published var pendingMagnetConfirmGid: String?
    // Bug 2: 重复下载检测后待用户确认的下载信息
    @Published var pendingDuplicateDownload: DuplicateDownloadInfo?

    // Bug 1: 正在等待元数据下载的磁力链接元数据任务 GID 集合
    private var pendingMagnetMetadataGids: Set<String> = []

    /// 当前所有正在下载任务的实时下载速度之和（字节/秒），用于 Dock 图标等聚合展示。
    var totalDownloadSpeed: Int64 {
        tasks.filter { $0.status == .active && !$0.isSeeding }
            .reduce(Int64(0)) { $0 + $1.downloadSpeed }
    }

    // History
    let historyStore = HistoryStore()

    private var aria2: Aria2
    private var timer: AnyCancellable?
    private var isEngineBootstrapping = false
    private var hasRequestedNotificationPermission = false

    // 复用 JSONDecoder 避免每次新建
    private let decoder = JSONDecoder()

    // 任务添加/完成时间（aria2 RPC 不提供，由应用记录并持久化）
    private static let addedDatesKey = "taskAddedDates"
    private static let completedDatesKey = "taskCompletedDates"
    private var addedDates: [String: Date] = [:]
    private var completedDates: [String: Date] = [:]

    // 用于 addUri 等动作的串行队列，避免对单线程 RPC 形成并发风暴
    private var actionQueueTask: Task<Void, Never>? = nil

    init(rpcHost: String = "localhost", rpcPort: Int = 16800, rpcSecret: String = "") {
        let settings = SettingsStore()
        let actualHost = settings.rpcHost.isEmpty ? rpcHost : settings.rpcHost
        let actualPort = settings.rpcPort
        let actualSecret = settings.rpcSecret

        print("[TaskStore] Initializing Aria2Kit on \(actualHost):\(actualPort) ssl=\(settings.rpcSSL)")

        self.aria2 = Aria2(
            ssl: settings.rpcSSL,
            host: actualHost,
            port: UInt16(actualPort),
            token: actualSecret.isEmpty ? nil : actualSecret)

        loadTaskDates()
        startPolling()
    }

    private func loadTaskDates() {
        if let raw = UserDefaults.standard.dictionary(forKey: Self.addedDatesKey) {
            addedDates = raw.compactMapValues { ($0 as? Double).map { Date(timeIntervalSince1970: $0) } }
        }
        if let raw = UserDefaults.standard.dictionary(forKey: Self.completedDatesKey) {
            completedDates = raw.compactMapValues { ($0 as? Double).map { Date(timeIntervalSince1970: $0) } }
        }
    }

    private func saveTaskDates() {
        UserDefaults.standard.set(
            addedDates.mapValues { $0.timeIntervalSince1970 }, forKey: Self.addedDatesKey)
        UserDefaults.standard.set(
            completedDates.mapValues { $0.timeIntervalSince1970 }, forKey: Self.completedDatesKey)
    }

    func startEngineOnLaunchIfNeeded(settings: SettingsStore) async {
        configureRPC(settings: settings)
        guard settings.aria2StartOnLaunch else { return }

        isEngineBootstrapping = true
        isConnected = false
        lastError = nil
        shouldPresentEngineError = false
        EngineManager.shared.start(settings: settings)

        let ready = await waitForConfiguredRPC(settings: settings, timeout: 6)
        isEngineBootstrapping = false
        if ready {
            fetchTasks()
            if settings.autoResumeTasks {
                aria2.call(method: .unpauseAll, params: []).response { _ in }
            }
        } else if EngineManager.shared.isRunning {
            lastError = String(localized: "无法连接到 Aria2 RPC")
        }
    }

    func reconnectToConfiguredRPC() {
        let settings = SettingsStore()
        configureRPC(settings: settings)
        isConnected = false
        lastError = nil
        shouldPresentEngineError = false
        fetchTasks()
    }

    private func configureRPC(settings: SettingsStore) {
        let host = settings.rpcHost.isEmpty ? "127.0.0.1" : settings.rpcHost
        aria2 = Aria2(
            ssl: settings.rpcSSL,
            host: host,
            port: UInt16(settings.rpcPort),
            token: settings.rpcSecret.isEmpty ? nil : settings.rpcSecret
        )
    }

    private func waitForConfiguredRPC(settings: SettingsStore, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await isConfiguredRPCReady(settings: settings) {
                return true
            }

            if !EngineManager.shared.isRunning {
                return false
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        return false
    }

    private func isConfiguredRPCReady(settings: SettingsStore) async -> Bool {
        let host = settings.rpcHost.isEmpty ? "127.0.0.1" : settings.rpcHost
        let scheme = settings.rpcSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(host):\(settings.rpcPort)/jsonrpc") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let params = settings.rpcSecret.isEmpty ? [] : ["token:\(settings.rpcSecret)"]
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "maltex-rpc-ready",
            "method": "aria2.getVersion",
            "params": params,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func reconnectToConfiguredRPCAfterEngineRestart() {
        let settings = SettingsStore()
        configureRPC(settings: settings)
        isConnected = false
        lastError = nil
        shouldPresentEngineError = false
        isEngineBootstrapping = true
        Task { @MainActor in
            let ready = await waitForConfiguredRPC(settings: settings, timeout: 6)
            isEngineBootstrapping = false
            if ready {
                fetchTasks()
            } else if EngineManager.shared.isRunning {
                lastError = String(localized: "无法连接到 Aria2 RPC")
            }
        }
    }

    /// 推迟通知权限申请到真正需要发送通知时再请求，避免应用启动即弹权限框。
    private func ensureNotificationPermission() {
        guard !hasRequestedNotificationPermission else { return }
        hasRequestedNotificationPermission = true
        Task { @MainActor in
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge])
                if granted {
                    print("[TaskStore] Notification permission granted")
                }
            } catch {
                print("[TaskStore] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        // 引擎的最终停止由 AppDelegate.applicationWillTerminate 负责，
        // 这里不再开 Task — 在 deinit 中调度 MainActor Task 可能在 App 退出时无法及时执行。
        actionQueueTask?.cancel()
    }

    // MARK: - Aggregated Fetch (防闪烁)
    // 每一轮抓取使用一个 generation 令牌：过期的回调会被丢弃，
    // 并配合超时保护防止 isFetching 永久挂起。
    private var pendingFetchResults: [[DownloadTask]] = [[], [], []]
    private var pendingFetchCount = 0
    private var isFetching = false
    private var pendingFetchFailed = false
    private var pendingFetchErrorMessage: String?
    private var currentFetchGeneration: UInt64 = 0
    private var fetchTimeoutTask: Task<Void, Never>? = nil
    private static let fetchTimeoutSeconds: UInt64 = 10

    func fetchTasks() {
        guard !isEngineBootstrapping else { return }
        guard EngineManager.shared.isRunning else {
            isConnected = false
            lastError = nil
            shouldPresentEngineError = false
            return
        }
        guard !isFetching else { return }

        isFetching = true
        currentFetchGeneration &+= 1
        let generation = currentFetchGeneration
        pendingFetchResults = [[], [], []]
        pendingFetchCount = 0
        pendingFetchFailed = false
        pendingFetchErrorMessage = nil

        // 启动超时保护：到点未完成则强制释放 isFetching
        fetchTimeoutTask?.cancel()
        fetchTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.fetchTimeoutSeconds * 1_000_000_000)
            guard let self else { return }
            guard self.currentFetchGeneration == generation, self.isFetching else { return }
            print("[TaskStore] Fetch generation \(generation) timed out")
            self.isFetching = false
            if EngineManager.shared.isRunning && !self.isEngineBootstrapping {
                self.lastError = String(localized: "RPC 任务获取超时")
            }
        }

        // 0: tellActive, 1: tellWaiting, 2: tellStopped
        fetchCategory(method: .tellActive, params: [], index: 0, generation: generation)
        fetchCategory(method: .tellWaiting, params: [AnyEncodable(0), AnyEncodable(100)], index: 1, generation: generation)
        fetchCategory(method: .tellStopped, params: [AnyEncodable(0), AnyEncodable(100)], index: 2, generation: generation)
    }

    private func fetchCategory(method: Aria2Method, params: [AnyEncodable], index: Int, generation: UInt64) {
        aria2.call(method: method, params: params)
            .response { [weak self] response in
                Task { @MainActor in
                    guard let self else { return }
                    // 丢弃过期回调
                    guard self.currentFetchGeneration == generation, self.isFetching else { return }
                    guard EngineManager.shared.isRunning, !self.isEngineBootstrapping else {
                        self.isFetching = false
                        self.fetchTimeoutTask?.cancel()
                        return
                    }
                    switch response.result {
                    case .success(let data):
                        if let data = data,
                            let rpcResponse = try? self.decoder.decode(
                                Aria2Response<[DownloadTask]>.self, from: data),
                            let fetchedTasks = rpcResponse.result
                        {
                            self.pendingFetchResults[index] = fetchedTasks
                        }
                    case .failure(let error):
                        print("[TaskStore] Fetch error (\(method.rawValue)): \(error.localizedDescription)")
                        self.pendingFetchFailed = true
                        self.pendingFetchErrorMessage = error.localizedDescription
                    }

                    self.pendingFetchCount += 1
                    if self.pendingFetchCount >= 3 {
                        self.fetchTimeoutTask?.cancel()
                        guard EngineManager.shared.isRunning, !self.isEngineBootstrapping else {
                            self.isFetching = false
                            return
                        }
                        if self.pendingFetchFailed {
                            self.handleTasksResult(.failure(NSError(
                                domain: "Maltex.Aria2RPC",
                                code: 1,
                                userInfo: [
                                    NSLocalizedDescriptionKey: self.pendingFetchErrorMessage
                                        ?? String(localized: "无法连接到 Aria2 RPC")
                                ]
                            )))
                            self.isFetching = false
                            return
                        }

                        // 三个请求全部完成，合并所有结果后统一更新
                        let allTasks = self.pendingFetchResults.flatMap { $0 }
                        if allTasks.isEmpty && self.pendingFetchResults.allSatisfy({ $0.isEmpty }) {
                            if !self.isConnected {
                                self.lastError = String(localized: "引擎连接失败: 无法获取任务列表")
                            }
                        }
                        self.handleTasksResult(.success(allTasks))
                        self.isFetching = false
                    }
                }
            }
    }

    /// 单独执行一个 RPC 调用并处理简单的 GID 返回（用于 addUri/addTorrent 等操作）
    private func performActionCall(
        method: Aria2Method,
        params: [AnyEncodable],
        failureFormat: String.LocalizationValue,
        onRPCError: (@MainActor @Sendable (Aria2RPCError) -> Bool)? = nil,
        onGid: (@MainActor @Sendable (String) -> Void)? = nil
    ) {
        aria2.call(method: method, params: params)
            .response { [weak self] response in
                Task { @MainActor in
                    guard let self else { return }
                    switch response.result {
                    case .success(let data):
                        guard let data else { return }
                        if let rpcResponse = try? self.decoder.decode(
                            Aria2Response<String>.self, from: data),
                            let gid = rpcResponse.result
                        {
                            print("[TaskStore] Action success for GID: \(gid)")
                            self.isConnected = true
                            self.lastError = nil
                            onGid?(gid)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.fetchTasks()
                            }
                        } else if let rpcResponse = try? self.decoder.decode(
                            Aria2Response<AnyCodable>.self, from: data),
                            let error = rpcResponse.error
                        {
                            print("[TaskStore] RPC Error: \(error.message)")
                            // 优先让调用方处理特定 RPC 错误（如重复下载检测）
                            if let onRPCError, onRPCError(error) {
                                return
                            }
                            self.isConnected = false
                            self.lastError = String(
                                format: String(localized: failureFormat), error.message)
                            self.shouldPresentEngineError = true
                        }
                    case .failure(let error):
                        self.isConnected = false
                        self.lastError = String(
                            format: String(localized: failureFormat), error.localizedDescription)
                        self.shouldPresentEngineError = true
                    }
                }
            }
    }

    private func handleTasksResult(_ result: Result<[DownloadTask], Error>) {
        switch result {
        case .success(let fetchedTasks):
            mergeTasks(fetchedTasks)
            if !isConnected {
                print("[TaskStore] RPC handshake success")
            }
            isConnected = true
            lastError = nil
            shouldPresentEngineError = false
        case .failure(let error):
            print("[TaskStore] Fetch error: \(error.localizedDescription)")
            isConnected = false
            if EngineManager.shared.isRunning && !isEngineBootstrapping {
                lastError = String(
                    format: String(localized: "引擎连接失败: %@"), error.localizedDescription)
            } else {
                lastError = nil
            }
        }
    }

    private func mergeTasks(_ newTasks: [DownloadTask]) {
        let settings = SettingsStore()
        let now = Date()
        var datesChanged = false

        // 1. Unique engine tasks by GID, prefer those with non-zero length
        var engineTasksMap: [String: DownloadTask] = [:]
        for task in newTasks {
            if let existing = engineTasksMap[task.gid] {
                if task.totalLength >= existing.totalLength {
                    engineTasksMap[task.gid] = task
                }
            } else {
                engineTasksMap[task.gid] = task
            }
        }

        var currentEngineTasks = Array(engineTasksMap.values)
        let oldTasksMap = self.tasks.reduce(into: [String: DownloadTask]()) { $0[$1.gid] = $1 }

        for index in currentEngineTasks.indices {
            let gid = currentEngineTasks[index].gid

            // 首次见到任务时记录添加时间
            if addedDates[gid] == nil {
                addedDates[gid] = now
                datesChanged = true
            }

            let wasDownloadComplete = oldTasksMap[gid]?.isDownloadComplete == true
            let isDownloadComplete = currentEngineTasks[index].isDownloadComplete

            // 完成时记录完成时间（含已经处于完成态但尚无记录的情况）
            if isDownloadComplete && completedDates[gid] == nil {
                completedDates[gid] = now
                datesChanged = true
            }

            currentEngineTasks[index].addedDate = addedDates[gid]
            currentEngineTasks[index].completedDate = completedDates[gid]

            // Download transition: not complete -> file payload complete.
            if oldTasksMap[gid] != nil, !wasDownloadComplete, isDownloadComplete {
                if settings.notificationEnabled {
                    sendCompletionNotification(for: currentEngineTasks[index])
                }
            }

            // Error transition: non-error -> error
            let wasError = oldTasksMap[gid]?.status == .error
            let isError = currentEngineTasks[index].status == .error
            if oldTasksMap[gid] != nil, !wasError, isError {
                if settings.notificationEnabled {
                    sendErrorNotification(for: currentEngineTasks[index])
                }
            }

            if isDownloadComplete && !historyStore.contains(gid: gid) {
                historyStore.add(currentEngineTasks[index])
            }
        }

        // 3. 检测磁力链接元数据下载完成后的派生任务
        if !pendingMagnetMetadataGids.isEmpty {
            var confirmedMetaGids: Set<String> = []

            for task in currentEngineTasks {
                // 通过 belongsTo 追踪：派生任务的 belongsTo 指向元数据任务 GID
                guard let parentGid = task.belongsTo,
                      pendingMagnetMetadataGids.contains(parentGid),
                      task.bittorrent != nil,
                      !task.files.isEmpty
                else { continue }

                // 暂停派生任务并通知 UI 弹出确认弹窗
                aria2.call(method: .forcePause, params: [AnyEncodable(task.gid)])
                    .response { _ in }
                pendingMagnetConfirmGid = task.gid
                confirmedMetaGids.insert(parentGid)
            }

            pendingMagnetMetadataGids.subtract(confirmedMetaGids)

            // 清理已出错或已消失的元数据任务
            pendingMagnetMetadataGids = pendingMagnetMetadataGids.filter { metaGid in
                guard let task = engineTasksMap[metaGid] else { return false }
                return task.status != .error
            }
        }

        // 2. Merge history tasks that are NOT in engine（从持久化映射回填时间）
        let engineGids = Set(engineTasksMap.keys)
        let historyTasksNotInEngine = historyStore.archivedTasks
            .filter { !engineGids.contains($0.gid) }
            .map { task -> DownloadTask in
                var task = task
                task.addedDate = addedDates[task.gid]
                task.completedDate = completedDates[task.gid]
                task.downloadSpeed = 0
                task.uploadSpeed = 0
                return task
            }

        var finalTasks = currentEngineTasks
        finalTasks.append(contentsOf: historyTasksNotInEngine)

        if datesChanged {
            saveTaskDates()
        }

        self.tasks = finalTasks.sorted {
            $0.gid > $1.gid
        }
    }

    private func sendCompletionNotification(for task: DownloadTask) {
        ensureNotificationPermission()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "下载完成")
        content.body =
            task.bittorrent?.info?.name ?? task.files.first?.path.components(separatedBy: "/").last
            ?? String(localized: "未知文件")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "complete-\(task.gid)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[TaskStore] Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }

    private func sendErrorNotification(for task: DownloadTask) {
        ensureNotificationPermission()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "下载失败")
        content.subtitle =
            task.bittorrent?.info?.name ?? task.files.first?.path.components(separatedBy: "/").last
            ?? String(localized: "未知文件")
        content.body = task.localizedErrorDescription ?? String(localized: "下载出错")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "error-\(task.gid)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[TaskStore] Failed to deliver error notification: \(error.localizedDescription)")
            }
        }
    }

    func startPolling() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchTasks()
            }
    }

    // MARK: - Actions

    /// 串行追加一个动作，避免并发 RPC 风暴。
    private func enqueueAction(_ block: @escaping @MainActor () async -> Void) {
        let previous = actionQueueTask
        actionQueueTask = Task { @MainActor in
            await previous?.value
            await block()
        }
    }

    func addUri(_ uris: [String], dir: String? = nil) {
        let settings = SettingsStore()
        var options: [String: String] = [:]
        let targetDir = (dir?.isEmpty == false) ? dir! : settings.downloadPath
        if !targetDir.isEmpty {
            options["dir"] = targetDir
        }

        let btAutoStart = settings.btAutoStart
        // 每个 URL 串行发送 addUri 请求：aria2 是单线程 RPC，
        // 串行化既能避免并发风暴，也能保证 lastAddedGid 的语义正确。
        for uri in uris {
            enqueueAction { [weak self] in
                guard let self else { return }
                let isMagnet = uri.lowercased().hasPrefix("magnet:")
                // 磁力链接不再传 pause=true（否则元数据无法下载），
                // 改由 mergeTasks 在检测到派生任务后暂停并弹出确认弹窗。
                let needsConfirm = isMagnet && !btAutoStart
                await self.addSingleUri(uri, options: options, isMagnetPendingConfirm: needsConfirm)
            }
        }
    }

    private func addSingleUri(_ uri: String, options: [String: String], isMagnetPendingConfirm: Bool = false) async {
        var params: [AnyEncodable] = [AnyEncodable([uri])]
        if !options.isEmpty {
            params.append(AnyEncodable(options))
        }

        performActionCall(
            method: .addUri,
            params: params,
            failureFormat: "添加下载失败: %@",
            onRPCError: { [weak self] error in
                guard let self else { return false }
                if error.message.lowercased().contains("same info hash") {
                    self.pendingDuplicateDownload = DuplicateDownloadInfo(
                        uri: uri, options: options, torrentBase64: nil)
                    return true
                }
                return false
            },
            onGid: { [weak self] gid in
                guard let self else { return }
                if isMagnetPendingConfirm {
                    self.pendingMagnetMetadataGids.insert(gid)
                }
                self.lastAddedGid = gid
            }
        )

        // 给一个最小节奏，避免对单线程 RPC 形成瞬时洪峰
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func addTorrent(at path: String, dir: String? = nil) {
        addTorrent(at: path, paused: true, dir: dir)
    }

    func addTorrent(at path: String, paused: Bool, dir: String? = nil) {
        // 异步读取种子文件，避免阻塞主线程
        Task { @MainActor [self] in
            let data: Data? = await Task.detached { () -> Data? in
                try? Data(contentsOf: URL(fileURLWithPath: path))
            }.value

            guard let data else {
                self.lastError = String(
                    format: String(localized: "添加下载失败: %@"),
                    String(localized: "无法读取种子文件"))
                self.shouldPresentEngineError = true
                return
            }

            var params: [AnyEncodable] = [AnyEncodable(data.base64EncodedString())]

            let settings = SettingsStore()
            var options: [String: String] = [:]
            if paused {
                options["pause"] = "true"
            }
            let targetDir = (dir?.isEmpty == false) ? dir! : settings.downloadPath
            if !targetDir.isEmpty {
                options["dir"] = targetDir
            }

            // Aria2 RPC addTorrent(torrent, uris, options)
            params.append(AnyEncodable([String]()))  // Empty URIs list
            if !options.isEmpty {
                params.append(AnyEncodable(options))
            }

            let base64Torrent = data.base64EncodedString()
            self.performActionCall(
                method: .addTorrent,
                params: params,
                failureFormat: "添加下载失败: %@",
                onRPCError: { [weak self] error in
                    guard let self else { return false }
                    if error.message.lowercased().contains("same info hash") {
                        self.pendingDuplicateDownload = DuplicateDownloadInfo(
                            uri: "", options: options, torrentBase64: base64Torrent)
                        return true
                    }
                    return false
                },
                onGid: { [weak self] gid in
                    self?.lastAddedGid = gid
                }
            )
        }
    }

    func pauseTasks(gids: Set<String>) {
        // 乐观 UI 更新：立即将任务状态置为 paused，带来毫秒级即时响应体感
        for i in 0..<tasks.count {
            if gids.contains(tasks[i].gid) {
                tasks[i].status = .paused
                tasks[i].downloadSpeed = 0
            }
        }
        for gid in gids {
            aria2.call(method: .forcePause, params: [AnyEncodable(gid)]).response { [weak self] _ in
                Task { @MainActor in self?.fetchTasks() }
            }
        }
    }

    func resumeTasks(gids: Set<String>) {
        for gid in gids {
            aria2.call(method: .unpause, params: [AnyEncodable(gid)]).response { [weak self] _ in
                Task { @MainActor in self?.fetchTasks() }
            }
        }
    }

    func resumeTask(gid: String, options: [String: String] = [:]) {
        if !options.isEmpty {
            changeOption(gid: gid, options: options) { [weak self] success in
                Task { @MainActor in
                    guard let self else { return }
                    if !success {
                        self.lastError = String(
                            format: String(localized: "更改下载选项失败: %@"), gid)
                        self.shouldPresentEngineError = true
                        return
                    }
                    self.aria2.call(method: .unpause, params: [AnyEncodable(gid)]).response { [weak self] _ in
                        Task { @MainActor in self?.fetchTasks() }
                    }
                }
            }
        } else {
            aria2.call(method: .unpause, params: [AnyEncodable(gid)]).response { [weak self] _ in
                Task { @MainActor in self?.fetchTasks() }
            }
        }
    }

    /// 修改下载选项；completion 接收成功标志，便于上游决定是否继续后续动作。
    func changeOption(
        gid: String,
        options: [String: String],
        completion: @escaping @Sendable (Bool) -> Void = { _ in }
    ) {
        aria2.call(method: .changeOption, params: [AnyEncodable(gid), AnyEncodable(options)])
            .response { [weak self] response in
                Task { @MainActor in
                    guard let self else {
                        completion(false)
                        return
                    }
                    switch response.result {
                    case .success(let data):
                        if let data,
                            let rpcResponse = try? self.decoder.decode(
                                Aria2Response<AnyCodable>.self, from: data),
                            rpcResponse.error == nil
                        {
                            completion(true)
                        } else {
                            completion(false)
                        }
                    case .failure:
                        completion(false)
                    }
                }
            }
    }

    func removeTasks(gids: Set<String>, deleteFiles: Bool = false) {
        // 保留快照以便服务端失败时回滚 UI 状态
        let removedTasksSnapshot: [DownloadTask] = self.tasks.filter { gids.contains($0.gid) }
        let removedHistorySnapshot: [DownloadTask] = self.historyStore.archivedTasks.filter {
            gids.contains($0.gid)
        }

        // 删除磁盘文件前先记录待删任务快照（含文件路径）
        let tasksForFileDeletion = deleteFiles ? removedTasksSnapshot : []

        // 先在本地移除提供即时反馈
        gids.forEach { historyStore.remove(gid: $0) }
        tasks.removeAll(where: { gids.contains($0.gid) })

        // 清理已删除任务的时间记录
        for gid in gids {
            addedDates[gid] = nil
            completedDates[gid] = nil
        }
        saveTaskDates()

        for gid in gids {
            aria2.call(method: .removeDownloadResult, params: [AnyEncodable(gid)]).response {
                [weak self] response in
                Task { @MainActor in
                    guard let self else { return }
                    switch response.result {
                    case .success(let data):
                        if let data = data,
                            let rpcResponse = try? self.decoder.decode(
                                Aria2Response<String>.self, from: data),
                            rpcResponse.result == "OK"
                        {
                            print("[TaskStore] Removed download result for \(gid)")
                            return
                        }

                        if let data = data,
                            let errorResponse = try? self.decoder.decode(
                                Aria2Response<AnyCodable>.self, from: data),
                            errorResponse.error != nil
                        {
                            // Error means probable active task -> Force Remove + Retry
                            self.forceRemoveAndClean(
                                gid: gid,
                                onFailure: {
                                    self.rollbackRemoval(
                                        gid: gid,
                                        taskSnapshot: removedTasksSnapshot,
                                        historySnapshot: removedHistorySnapshot)
                                })
                        } else {
                            print("[TaskStore] Removed download result for \(gid)")
                        }

                    case .failure:
                        self.forceRemoveAndClean(
                            gid: gid,
                            onFailure: {
                                self.rollbackRemoval(
                                    gid: gid,
                                    taskSnapshot: removedTasksSnapshot,
                                    historySnapshot: removedHistorySnapshot)
                            })
                    }
                }
            }
        }

        // 延迟删除磁盘文件：先让 removeDownloadResult/forceRemove 停止引擎对文件的写入
        if deleteFiles, !tasksForFileDeletion.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.removeFilesOnDisk(for: tasksForFileDeletion)
            }
        }
    }

    /// 删除任务对应的磁盘文件及其 aria2 控制文件，并清理由此变空的下载子目录。
    private func removeFilesOnDisk(for tasks: [DownloadTask]) {
        let fm = FileManager.default
        for task in tasks {
            var parentDirs = Set<String>()
            for file in task.files where !file.path.isEmpty {
                try? fm.removeItem(atPath: file.path)
                try? fm.removeItem(atPath: file.path + ".aria2")
                parentDirs.insert((file.path as NSString).deletingLastPathComponent)
            }
            let downloadRoot = (task.dir as NSString).standardizingPath
            for dir in parentDirs {
                removeEmptyDirectories(from: dir, stoppingAt: downloadRoot, fm: fm)
            }
        }
    }

    /// 从 startDir 向上删除已变空的目录，直到（不含）下载根目录 root 为止；只删除空目录，确保安全。
    private func removeEmptyDirectories(from startDir: String, stoppingAt root: String, fm: FileManager) {
        var current = (startDir as NSString).standardizingPath
        while current.count > root.count, current.hasPrefix(root + "/") {
            let contents = (try? fm.contentsOfDirectory(atPath: current)) ?? []
            guard contents.allSatisfy({ $0 == ".DS_Store" }) else { break }
            try? fm.removeItem(atPath: current)
            current = (current as NSString).deletingLastPathComponent
        }
    }

    /// 服务端确认无法删除时，将该 gid 的快照重新放回本地 UI。
    private func rollbackRemoval(
        gid: String,
        taskSnapshot: [DownloadTask],
        historySnapshot: [DownloadTask]
    ) {
        if let task = taskSnapshot.first(where: { $0.gid == gid }) {
            if !self.tasks.contains(where: { $0.gid == gid }) {
                self.tasks.append(task)
            }
        }
        if let task = historySnapshot.first(where: { $0.gid == gid }) {
            self.historyStore.add(task)
        }
        self.lastError = String(
            format: String(localized: "删除任务失败: %@"), gid)
        self.shouldPresentEngineError = true
    }

    private func forceRemoveAndClean(gid: String, onFailure: (@MainActor @Sendable () -> Void)? = nil) {
        aria2.call(method: .forceRemove, params: [AnyEncodable(gid)]).response { [weak self] response in
            Task { @MainActor in
                guard let self else { return }

                let forceRemoveSucceeded: Bool
                switch response.result {
                case .success(let data):
                    if let data,
                        let rpcResponse = try? self.decoder.decode(
                            Aria2Response<String>.self, from: data),
                        rpcResponse.result != nil
                    {
                        forceRemoveSucceeded = true
                    } else if let data,
                        let errorResponse = try? self.decoder.decode(
                            Aria2Response<AnyCodable>.self, from: data),
                        errorResponse.error != nil
                    {
                        forceRemoveSucceeded = false
                    } else {
                        forceRemoveSucceeded = true
                    }
                case .failure:
                    forceRemoveSucceeded = false
                }

                guard forceRemoveSucceeded else {
                    onFailure?()
                    return
                }

                print("[TaskStore] Force removed \(gid), scheduling cleanup")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.aria2.call(method: .removeDownloadResult, params: [AnyEncodable(gid)])
                        .response { _ in
                            print("[TaskStore] Cleanup attempt for \(gid) completed")
                        }
                }
            }
        }
    }

    func stopTasks(gids: Set<String>) {
        for gid in gids {
            aria2.call(method: .forcePause, params: [AnyEncodable(gid)]).response { [weak self] _ in
                Task { @MainActor in self?.fetchTasks() }
            }
        }
    }

    // MARK: - Bug 1: Magnet Link Helpers

    /// 检查指定 GID 是否为正在等待元数据下载的磁力链接任务。
    func isPendingMagnetMetadata(gid: String) -> Bool {
        pendingMagnetMetadataGids.contains(gid)
    }

    // MARK: - Bug 2: Duplicate Download Helpers

    /// 从磁力链接 URI 中提取 info hash。
    private func extractInfoHash(from magnetURI: String) -> String? {
        guard magnetURI.lowercased().hasPrefix("magnet:") else { return nil }
        // 手动解析 xt 参数，URLComponents 对 magnet: 协议解析不可靠
        let components = magnetURI.components(separatedBy: "&")
        for component in components {
            let part = component.contains("?") ? component.components(separatedBy: "?").last ?? component : component
            if part.lowercased().hasPrefix("xt=urn:btih:") {
                return String(part.dropFirst("xt=urn:btih:".count)).lowercased()
            }
        }
        return nil
    }

    /// 删除与待重下载信息冲突的已有任务后重新添加下载。
    func forceRedownload() {
        guard let info = pendingDuplicateDownload else { return }
        pendingDuplicateDownload = nil

        let hash = extractInfoHash(from: info.uri)

        // 查找已有的同 info hash 任务
        let existingGid: String? = {
            guard let hash else { return nil }
            return tasks.first(where: {
                $0.infoHash?.lowercased() == hash
            })?.gid
        }()

        guard let gid = existingGid else {
            // 无法定位旧任务（种子文件的 hash 无法从客户端提取），提示用户手动处理
            lastError = String(localized: "与现有下载任务冲突（相同内容），请先删除已有任务再重新添加。")
            shouldPresentEngineError = true
            return
        }

        // 移除旧任务后重新添加
        removeTasks(gids: [gid])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if let torrentData = info.torrentBase64 {
                self.readdTorrent(base64: torrentData, options: info.options)
            } else {
                self.addUri([info.uri])
            }
        }
    }

    /// 使用 base64 编码的种子数据重新添加下载任务。
    private func readdTorrent(base64 torrentBase64: String, options: [String: String]) {
        var params: [AnyEncodable] = [AnyEncodable(torrentBase64)]
        params.append(AnyEncodable([String]()))
        if !options.isEmpty {
            params.append(AnyEncodable(options))
        }
        performActionCall(
            method: .addTorrent,
            params: params,
            failureFormat: "添加下载失败: %@",
            onGid: { [weak self] gid in
                self?.lastAddedGid = gid
            }
        )
    }
}
