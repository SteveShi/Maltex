import SwiftUI

struct TaskListView: View {
    let status: String
    @Binding var selectedTaskGids: Set<String>
    @Binding var isShowingAddTask: Bool
    @EnvironmentObject var taskStore: TaskStore

    var filteredTasks: [DownloadTask] {
        switch status {
        case "all":
            return taskStore.tasks
        case "downloading":
            return taskStore.tasks.filter { $0.status == .active }
        case "waiting":
            return taskStore.tasks.filter { $0.status == .waiting }
        case "paused":
            return taskStore.tasks.filter { $0.status == .paused }
        case "stopped":
            // "Stopped" usually means error or manually stopped (paused), but given we have a "Paused" category,
            // and Aria2 "stopped" (complete/error) vs "paused".
            // Let's make "Stopped" cover Error and Removed, or perhaps just Error if complete is separate.
            // Following original logic: Stopped was Paused.
            // User Request: Paused vs Stopped.
            // Let's define: Paused = Paused. Stopped = Error.
            return taskStore.tasks.filter { $0.status == .error }
        case "completed":
            return taskStore.tasks.filter { $0.status == .complete }
        default:
            return taskStore.tasks
        }
    }

    var body: some View {
        Group {
            if filteredTasks.isEmpty {
                ContentUnavailableView(
                    String(localized: "暂无任务"),
                    systemImage: "tray",
                    description: Text("点击上方 '+' 按钮或拖入链接开始下载")
                )
            } else {
                List(selection: $selectedTaskGids) {
                    ForEach(filteredTasks) { task in
                        TaskRow(task: task)
                            .tag(task.gid)
                            .contextMenu {
                                Button {
                                    if task.status == .active {
                                        taskStore.pauseTasks(gids: [task.gid])
                                    } else {
                                        taskStore.resumeTasks(gids: [task.gid])
                                    }
                                } label: {
                                    Label(
                                        task.status == .active
                                            ? String(localized: "暂停") : String(localized: "开始"),
                                        systemImage: task.status == .active
                                            ? "pause.fill" : "play.fill")
                                }

                                Button {
                                    taskStore.stopTasks(gids: [task.gid])
                                } label: {
                                    Label(String(localized: "停止"), systemImage: "stop.fill")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    taskStore.removeTasks(gids: [task.gid])
                                } label: {
                                    Label(String(localized: "删除"), systemImage: "trash.fill")
                                }
                            }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    let filteredGids = Set(filteredTasks.map { $0.gid })
                    if selectedTaskGids.isSuperset(of: filteredGids) && !filteredGids.isEmpty {
                        selectedTaskGids.subtract(filteredGids)
                    } else {
                        selectedTaskGids.formUnion(filteredGids)
                    }
                }) {
                    let filteredGids = Set(filteredTasks.map { $0.gid })
                    let isAllSelected =
                        selectedTaskGids.isSuperset(of: filteredGids) && !filteredGids.isEmpty

                    Label(
                        isAllSelected ? String(localized: "取消全选") : String(localized: "全选"),
                        systemImage: isAllSelected ? "checkmark.square.fill" : "checkmark.square"
                    )
                }
                .help(String(localized: "全选 / 取消全选"))

                Button(action: { taskStore.resumeTasks(gids: selectedTaskGids) }) {
                    Label(String(localized: "开始"), systemImage: "play.fill")
                }
                .disabled(selectedTaskGids.isEmpty)
                .help(String(localized: "开始任务"))

                Button(action: { taskStore.pauseTasks(gids: selectedTaskGids) }) {
                    Label(String(localized: "暂停"), systemImage: "pause.fill")
                }
                .disabled(selectedTaskGids.isEmpty)
                .help(String(localized: "暂停任务"))

                Button(action: { taskStore.stopTasks(gids: selectedTaskGids) }) {
                    Label(String(localized: "停止"), systemImage: "stop.fill")
                }
                .disabled(selectedTaskGids.isEmpty)
                .help(String(localized: "停止任务"))

                Button(action: {
                    taskStore.removeTasks(gids: selectedTaskGids)
                    selectedTaskGids.removeAll()
                }) {
                    Label(String(localized: "删除"), systemImage: "trash.fill")
                }
                .disabled(selectedTaskGids.isEmpty)
                .help(String(localized: "删除任务"))

                Button(action: { isShowingAddTask = true }) {
                    Label(String(localized: "新建任务"), systemImage: "plus")
                }
                .help(String(localized: "创建新下载任务"))

                Button(action: { taskStore.fetchTasks() }) {
                    Label(String(localized: "刷新"), systemImage: "arrow.clockwise")
                }
                .help(String(localized: "刷新列表"))
            }
        }
    }
}

struct TaskRow: View {
    let task: DownloadTask

    var body: some View {
        HStack {
            Image(systemName: task.bittorrent != nil ? "arrow.down.doc.fill" : "link.circle.fill")
                .font(.title2)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)

                ProgressView(value: Double(task.completedLength), total: Double(task.totalLength))
                    .progressViewStyle(.linear)
                    .tint(statusColor)
                
                HStack {
                    Text(formatBytes(task.completedLength) + " / " + formatBytes(task.totalLength))
                    Spacer()
                    Text(formatBytes(task.downloadSpeed) + "/s")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        // 1. BitTorrent name
        if let btName = task.bittorrent?.info?.name, !btName.isEmpty {
            return btName
        }
        
        // 2. File path (fallback from Aria2)
        if let path = task.files.first?.path, !path.isEmpty {
            let lastComponent = path.components(separatedBy: "/").last ?? ""
            // Match common hex IDs: 16 (GID), 40 (SHA-1), 64 (SHA-256)
            let isHexId = lastComponent.range(of: "^[0-9a-fA-F]{16}$|^[0-9a-fA-F]{40}$|^[0-9a-fA-F]{64}$", options: .regularExpression) != nil
            
            if !isHexId {
                return lastComponent
            }
        }
        
        // 3. Extract from first URI
        if let uri = task.files.first?.uris.first?.uri,
           let decodedUri = uri.removingPercentEncoding,
           let basePart = decodedUri.components(separatedBy: "?").first?.components(separatedBy: "#").first,
           let lastComponent = basePart.components(separatedBy: "/").last,
           !lastComponent.isEmpty {
            return lastComponent
        }
        
        return String(localized: "未知文件")
    }

    private var statusColor: Color {
        switch task.status {
        case .active: return .accentColor
        case .waiting: return .orange
        case .paused: return .gray
        case .complete: return .green
        case .error: return .red
        case .removed: return .secondary
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatterUtil.string(fromByteCount: bytes)
    }
}
