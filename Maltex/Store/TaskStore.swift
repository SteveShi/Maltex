import Alamofire
import AnyCodable
@preconcurrency import Aria2Kit
import Combine
import Foundation
import SwiftUI
import UserNotifications

// Standard response wrapper for Aria2 RPC
struct Aria2Response<T: Codable>: Codable {
    let id: String
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
    @Published var lastAddedGid: String?

    // History
    let historyStore = HistoryStore()

    private var aria2: Aria2
    private var timer: AnyCancellable?

    init(rpcHost: String = "localhost", rpcPort: Int = 16800, rpcSecret: String = "") {
        let settings = SettingsStore()
        EngineManager.shared.start(settings: settings)

        let actualPort = settings.rpcPort
        let actualSecret = settings.rpcSecret

        print("[TaskStore] Initializing Aria2Kit (HTTP) on \(rpcHost):\(actualPort)")

        self.aria2 = Aria2(
            ssl: false, host: rpcHost, port: UInt16(actualPort),
            token: actualSecret.isEmpty ? nil : actualSecret)

        requestNotificationPermission()
        startPolling()
    }

    private func requestNotificationPermission() {
        Task {
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
        Task { @MainActor in
            EngineManager.shared.stop()
        }
    }

    // MARK: - Aggregated Fetch (防闪烁)
    // 缓存三个 RPC 查询的结果，全部完成后一次性更新 tasks
    private nonisolated(unsafe) var pendingFetchResults: [[DownloadTask]] = [[], [], []]
    private nonisolated(unsafe) var pendingFetchCount = 0
    private nonisolated(unsafe) var isFetching = false

    func fetchTasks() {
        guard !isFetching else { return }
        isFetching = true
        pendingFetchResults = [[], [], []]
        pendingFetchCount = 0

        // 0: tellActive, 1: tellWaiting, 2: tellStopped
        fetchCategory(method: .tellActive, params: [], index: 0)
        fetchCategory(method: .tellWaiting, params: [AnyEncodable(0), AnyEncodable(100)], index: 1)
        fetchCategory(method: .tellStopped, params: [AnyEncodable(0), AnyEncodable(100)], index: 2)
    }

    private func fetchCategory(method: Aria2Method, params: [AnyEncodable], index: Int) {
        aria2.call(method: method, params: params)
            .response { [weak self] response in
                Task { @MainActor in
                    guard let self else { return }
                    switch response.result {
                    case .success(let data):
                        if let data = data,
                            let rpcResponse = try? JSONDecoder().decode(
                                Aria2Response<[DownloadTask]>.self, from: data),
                            let fetchedTasks = rpcResponse.result
                        {
                            self.pendingFetchResults[index] = fetchedTasks
                        }
                    case .failure(let error):
                        print("[TaskStore] Fetch error (\(method.rawValue)): \(error.localizedDescription)")
                    }

                    self.pendingFetchCount += 1
                    if self.pendingFetchCount >= 3 {
                        // 三个请求全部完成，合并所有结果后统一更新
                        let allTasks = self.pendingFetchResults.flatMap { $0 }
                        if allTasks.isEmpty && self.pendingFetchResults.allSatisfy({ $0.isEmpty }) {
                            // 如果全部为空且从未连接成功，可能是连接失败
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
                        if let rpcResponse = try? JSONDecoder().decode(
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
                        } else if let rpcResponse = try? JSONDecoder().decode(
                            Aria2Response<AnyCodable>.self, from: data),
                            let error = rpcResponse.error
                        {
                            print("[TaskStore] RPC Error: \(error.message)")
                            self.isConnected = false
                            self.lastError = String(
                                format: String(localized: failureFormat), error.message)
                        }
                    case .failure(let error):
                        self.isConnected = false
                        self.lastError = String(
                            format: String(localized: failureFormat), error.localizedDescription)
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
                isConnected = true
                lastError = nil
            }
        case .failure(let error):
            print("[TaskStore] Fetch error: \(error.localizedDescription)")
            isConnected = false
            lastError = String(
                format: String(localized: "引擎连接失败: %@"), error.localizedDescription)
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
        UNUserNotificationCenter.current().add(request)
    }

    func startPolling() {
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchTasks()
            }
    }

    // MARK: - Actions
    func addUri(_ uris: [String]) {
        let settings = SettingsStore()
        var options: [String: String] = [:]
        if !settings.downloadPath.isEmpty {
            options["dir"] = settings.downloadPath
        }

        // 每个 URL 独立发送 addUri 请求（aria2 的 addUri 参数数组是单个下载的镜像列表，不是多个独立下载）
        for uri in uris {
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
        }
    }

    func addTorrent(at path: String) {
        // Default to paused=true to allow Preview Dialog to handle confirmation
        addTorrent(at: path, paused: true)
    }

    func addTorrent(at path: String, paused: Bool) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        var params: [AnyEncodable] = [AnyEncodable(data.base64EncodedString())]

        let settings = SettingsStore()
        var options: [String: String] = [:]
        if paused {
            options["pause"] = "true"
        }
        // Always set the default download path if specified
        if !settings.downloadPath.isEmpty {
            options["dir"] = settings.downloadPath
        }

        // Aria2 RPC addTorrent(torrent, uris, options)
        params.append(AnyEncodable([String]()))  // Empty URIs list
        if !options.isEmpty {
            params.append(AnyEncodable(options))
        }

        performActionCall(
            method: .addTorrent,
            params: params,
            failureFormat: "添加下载失败: %@"
        ) { [weak self] gid in
            self?.lastAddedGid = gid
        }
    }

    func pauseTasks(gids: Set<String>) {
        for gid in gids {
            aria2.call(method: .pause, params: [AnyEncodable(gid)]).response { _ in }
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
            changeOption(gid: gid, options: options) { [weak self] in
                Task { @MainActor in
                    self?.aria2.call(method: .unpause, params: [AnyEncodable(gid)]).response { _ in
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

    func changeOption(
        gid: String, options: [String: String], completion: @escaping @Sendable () -> Void = {}
    ) {
        aria2.call(method: .changeOption, params: [AnyEncodable(gid), AnyEncodable(options)])
            .response { _ in
                completion()
            }
    }

    func removeTasks(gids: Set<String>) {
        for gid in gids {
            // First attempt to remove the result (for stopped/complete/error tasks)
            aria2.call(method: .removeDownloadResult, params: [AnyEncodable(gid)]).response {
                [weak self] response in
                Task { @MainActor in
                    switch response.result {
                    case .success(let data):
                        // If removeDownloadResult succeeds, check if it returned "OK" or similar success
                        // If it failed RPC-wise (e.g. task is active), aria2 returns error in JSON
                        if let data = data,
                            let rpcResponse = try? JSONDecoder().decode(
                                Aria2Response<String>.self, from: data),
                            rpcResponse.result == "OK"
                        {
                            print("[TaskStore] Removed download result for \(gid)")
                            // Archive completed task before removal if needed, but usually mergeTasks handles it.
                            // If we want to support "Delete to Trash" vs "Remove from List", we need to clarify logic.
                            // Current logic: Delete = Remove everywhere.
                            // So we should REMOVE from history too.
                            self?.historyStore.remove(gid: gid)
                            return
                        }

                        // If we are here, either decode failed or it wasn't a simple OK string (though usually it is).
                        // Or more likely, it's an error response.
                        if let data = data,
                            let errorResponse = try? JSONDecoder().decode(
                                Aria2Response<AnyCodable>.self, from: data),
                            errorResponse.error != nil
                        {
                            // Error means probable active task -> Force Remove + Retry
                            self?.forceRemoveAndClean(gid: gid)
                        } else {
                            // Success case that wasn't caught above
                            print("[TaskStore] Removed download result for \(gid)")
                            self?.historyStore.remove(gid: gid)
                        }

                    case .failure:
                        // Network error or otherwise
                        self?.forceRemoveAndClean(gid: gid)
                    }
                }
            }
        }
        // Force local removal immediately
        gids.forEach { historyStore.remove(gid: $0) }
        tasks.removeAll(where: { gids.contains($0.gid) })
    }

    private func forceRemoveAndClean(gid: String) {
        // Force remove first
        aria2.call(method: .forceRemove, params: [AnyEncodable(gid)]).response { [weak self] _ in
            print("[TaskStore] Force removed \(gid), scheduling cleanup")
            // Schedule a cleanup of the result after a short delay to allow state transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.aria2.call(method: .removeDownloadResult, params: [AnyEncodable(gid)])
                    .response { _ in
                        print("[TaskStore] Cleanup attempt for \(gid) completed")
                    }
            }
        }
    }

    func stopTasks(gids: Set<String>) {
        for gid in gids {
            aria2.call(method: .forcePause, params: [AnyEncodable(gid)]).response { _ in }
        }
    }
}
