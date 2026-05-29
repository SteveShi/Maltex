import Alamofire
import AnyCodable
@preconcurrency import Aria2Kit
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

@MainActor
class TaskStore: ObservableObject {
    @Published var tasks: [DownloadTask] = []
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var shouldPresentEngineError = false
    @Published var lastAddedGid: String?

    // History
    let historyStore = HistoryStore()

    private var aria2: Aria2
    private var timer: AnyCancellable?
    private var isEngineBootstrapping = false
    private var hasRequestedNotificationPermission = false

    // 复用 JSONDecoder 避免每次新建
    private let decoder = JSONDecoder()

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

        startPolling()
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

        let currentEngineTasks = Array(engineTasksMap.values)
        let oldTasksMap = self.tasks.reduce(into: [String: DownloadTask]()) { $0[$1.gid] = $1 }

        for task in currentEngineTasks {
            if let oldTask = oldTasksMap[task.gid] {
                // Status transition: active -> complete
                if oldTask.status != .complete && task.status == .complete {
                    if settings.notificationEnabled {
                        sendCompletionNotification(for: task)
                    }
                    // Archive completed task
                    historyStore.add(task)
                }
            }
        }

        // 2. Merge history tasks that are NOT in engine
        let engineGids = Set(engineTasksMap.keys)
        let historyTasksNotInEngine = historyStore.archivedTasks.filter {
            !engineGids.contains($0.gid)
        }

        var finalTasks = currentEngineTasks
        finalTasks.append(contentsOf: historyTasksNotInEngine)

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

    func addUri(_ uris: [String]) {
        let settings = SettingsStore()
        var options: [String: String] = [:]
        if !settings.downloadPath.isEmpty {
            options["dir"] = settings.downloadPath
        }

        // 每个 URL 串行发送 addUri 请求：aria2 是单线程 RPC，
        // 串行化既能避免并发风暴，也能保证 lastAddedGid 的语义正确。
        for uri in uris {
            enqueueAction { [weak self] in
                guard let self else { return }
                var currentOptions = options
                if !settings.btAutoStart && uri.lowercased().hasPrefix("magnet:") {
                    currentOptions["pause"] = "true"
                }
                await self.addSingleUri(uri, options: currentOptions)
            }
        }
    }

    private func addSingleUri(_ uri: String, options: [String: String]) async {
        var params: [AnyEncodable] = [AnyEncodable([uri])]
        if !options.isEmpty {
            params.append(AnyEncodable(options))
        }

        performActionCall(
            method: .addUri,
            params: params,
            failureFormat: "添加下载失败: %@"
        ) { [weak self] gid in
            self?.lastAddedGid = gid
        }

        // 给一个最小节奏，避免对单线程 RPC 形成瞬时洪峰
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func addTorrent(at path: String) {
        let settings = SettingsStore()
        addTorrent(at: path, paused: !settings.btAutoStart)
    }

    func addTorrent(at path: String, paused: Bool) {
        // 异步读取种子文件，避免阻塞主线程
        Task { @MainActor in
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
            if !settings.downloadPath.isEmpty {
                options["dir"] = settings.downloadPath
            }

            // Aria2 RPC addTorrent(torrent, uris, options)
            params.append(AnyEncodable([String]()))  // Empty URIs list
            if !options.isEmpty {
                params.append(AnyEncodable(options))
            }

            self.performActionCall(
                method: .addTorrent,
                params: params,
                failureFormat: "添加下载失败: %@"
            ) { [weak self] gid in
                self?.lastAddedGid = gid
            }
        }
    }

    func pauseTasks(gids: Set<String>) {
        for gid in gids {
            aria2.call(method: .pause, params: [AnyEncodable(gid)]).response { [weak self] _ in
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

    func removeTasks(gids: Set<String>) {
        // 保留快照以便服务端失败时回滚 UI 状态
        let removedTasksSnapshot: [DownloadTask] = self.tasks.filter { gids.contains($0.gid) }
        let removedHistorySnapshot: [DownloadTask] = self.historyStore.archivedTasks.filter {
            gids.contains($0.gid)
        }

        // 先在本地移除提供即时反馈
        gids.forEach { historyStore.remove(gid: $0) }
        tasks.removeAll(where: { gids.contains($0.gid) })

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
}
