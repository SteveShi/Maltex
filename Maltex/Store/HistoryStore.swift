import Foundation

@MainActor
class HistoryStore: ObservableObject {
    @Published var archivedTasks: [DownloadTask] = []

    private let fileURL: URL

    init() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Maltex", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: appSupport, withIntermediateDirectories: true, attributes: nil)
        self.fileURL = appSupport.appendingPathComponent("history.json")
        load()
    }

    func add(_ task: DownloadTask) {
        var taskToArchive = task
        // Ensure status is recorded as something final if not already.
        // BT tasks can be active while seeding after the file payload is complete.
        if taskToArchive.status == .active || taskToArchive.status == .waiting
            || taskToArchive.status == .paused
        {
            taskToArchive.status = taskToArchive.isDownloadComplete ? .complete : .removed
        }

        // 历史已归档任务的实时速度必须清零，防止把归档时的瞬时速度残留在持久化数据中
        taskToArchive.downloadSpeed = 0
        taskToArchive.uploadSpeed = 0

        if let index = archivedTasks.firstIndex(where: { $0.gid == task.gid }) {
            archivedTasks[index] = taskToArchive
        } else {
            archivedTasks.insert(taskToArchive, at: 0)
        }
        save()
    }

    func contains(gid: String) -> Bool {
        archivedTasks.contains { $0.gid == gid }
    }

    func remove(gid: String) {
        archivedTasks.removeAll { $0.gid == gid }
        save()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(archivedTasks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[HistoryStore] Failed to save history: \(error)")
        }
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            archivedTasks = try JSONDecoder().decode([DownloadTask].self, from: data)
        } catch {
            print("[HistoryStore] Failed to load history (may be new): \(error)")
            archivedTasks = []
        }
    }
}
