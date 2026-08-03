import AppKit
import SwiftUI

struct TaskListView: View {
    let status: String
    @Binding var selectedTaskGids: Set<String>
    @Binding var isShowingAddTask: Bool
    @EnvironmentObject var taskStore: TaskStore
    @State private var pendingDeleteGids: Set<String> = []
    @State private var showDeleteConfirm = false

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func requestDelete(_ gids: Set<String>) {
        guard !gids.isEmpty else { return }
        pendingDeleteGids = gids
        showDeleteConfirm = true
    }

    var filteredTasks: [DownloadTask] {
        switch status {
        case "all":
            return taskStore.tasks
        case "downloading":
            return taskStore.tasks.filter { $0.status == .active && !$0.isSeeding }
        case "uploading":
            return taskStore.tasks.filter { $0.isSeeding }
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
            return taskStore.tasks.filter { $0.isDownloadComplete }
                .sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
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

                                let downloadURLs = task.downloadURLs
                                if !downloadURLs.isEmpty {
                                    Button {
                                        copyToClipboard(downloadURLs.joined(separator: "\n"))
                                    } label: {
                                        Label(String(localized: "复制下载链接"), systemImage: "link")
                                    }
                                }

                                if let link = task.shareLink {
                                    Button {
                                        copyToClipboard(link)
                                    } label: {
                                        Label(String(localized: "复制磁力/ED2K 链接"), systemImage: "link.badge.plus")
                                    }
                                }

                                Divider()

                                Button(role: .destructive) {
                                    requestDelete([task.gid])
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
                    requestDelete(selectedTaskGids)
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
        .alert("删除任务", isPresented: $showDeleteConfirm) {
            Button(role: .destructive) {
                let gids = pendingDeleteGids
                taskStore.removeTasks(gids: gids, deleteFiles: true)
                selectedTaskGids.subtract(gids)
                pendingDeleteGids = []
            } label: {
                Text("删除任务和文件")
            }
            Button(String(localized: "仅删除任务")) {
                let gids = pendingDeleteGids
                taskStore.removeTasks(gids: gids, deleteFiles: false)
                selectedTaskGids.subtract(gids)
                pendingDeleteGids = []
            }
            Button(role: .cancel) {
                pendingDeleteGids = []
            } label: {
                Text("取消")
            }
        } message: {
            Text("将删除 \(pendingDeleteGids.count) 个任务。“删除任务和文件”会一并删除已下载到磁盘的文件，且不可恢复。")
        }
        .onChange(of: Set(filteredTasks.map(\.gid))) { _, visibleGids in
            let orphaned = selectedTaskGids.subtracting(visibleGids)
            if !orphaned.isEmpty {
                withAnimation(.spring()) {
                    selectedTaskGids.subtract(orphaned)
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: DownloadTask

    var body: some View {
        HStack {
            Image(systemName: iconName)
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
                    if task.status == .error, let errorDesc = task.localizedErrorDescription {
                        Label(errorDesc, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    } else {
                        if let remaining = task.remainingSeconds {
                            Label(
                                DurationFormatterUtil.string(fromSeconds: remaining),
                                systemImage: "clock"
                            )
                            .foregroundColor(.secondary)
                        }
                        Label(
                            formatBytes(task.isSeeding ? task.uploadSpeed : task.downloadSpeed) + "/s",
                            systemImage: task.isSeeding ? "arrow.up" : "arrow.down"
                        )
                            .foregroundColor(.secondary)
                    }
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
        if task.isSeeding {
            return .green
        }

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

    private var iconName: String {
        if task.isSeeding {
            return "arrow.up.circle.fill"
        }
        return task.bittorrent != nil ? "arrow.down.doc.fill" : "link.circle.fill"
    }
}
