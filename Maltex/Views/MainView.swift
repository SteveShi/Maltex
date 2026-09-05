import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @State private var selection: String? = "downloading"
    @State private var isShowingAddTask = false
    @State private var isShowingWhatsNew = false
    @AppStorage("lastPresentedWhatsNewVersion") private var lastPresentedWhatsNewVersion = ""
    @State private var selectedTaskGids: Set<String> = []
    @State private var confirmTask: DownloadTask? = nil
    @State private var pendingRevealGid: String? = nil
    @State private var isInspectorPresented: Bool = false
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var engine = EngineManager.shared

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(ideal: 200, max: 260)
        } detail: {
            HStack(spacing: 0) {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isInspectorPresented {
                    Divider()

                    TaskDetailSidebarView(
                        task: selectedDetailTask,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isInspectorPresented = false
                            }
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskView()
                .environmentObject(taskStore)
                .environmentObject(settings)
        }
        .sheet(isPresented: $isShowingWhatsNew) {
            WhatsNewSheetView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .maltexShowWhatsNew)) { _ in
            isShowingWhatsNew = true
        }
        .task {
            // 1.2.2 is a patch fix only; WhatsNew content remains for 1.2.1
            let whatsNewVersion = "1.2.1"
            if lastPresentedWhatsNewVersion != whatsNewVersion {
                lastPresentedWhatsNewVersion = whatsNewVersion
                isShowingWhatsNew = true
            }
        }
        .sheet(item: $confirmTask) { snapshotTask in
            TorrentConfirmView(task: snapshotTask) { path, selectedIndices in
                var options = ["dir": path]
                if !selectedIndices.isEmpty {
                    let sortedIndices = selectedIndices.compactMap { Int($0) }.sorted()
                    let indexString = sortedIndices.map { String($0) }.joined(separator: ",")
                    options["select-file"] = indexString
                }
                taskStore.resumeTask(gid: snapshotTask.gid, options: options)
                confirmTask = nil
            } onCancel: {
                taskStore.removeTasks(gids: [snapshotTask.gid])
                confirmTask = nil
            }
            .environmentObject(taskStore)
            .environmentObject(settings)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, url.pathExtension.lowercased() == "torrent" else { return }
                    Task { @MainActor in
                        taskStore.addTorrent(at: url.path)
                    }
                }
            }
            return true
        }
        .onChange(of: taskStore.lastAddedGid) {
            if let gid = taskStore.lastAddedGid {
                withAnimation(.spring()) {
                    pendingRevealGid = gid
                    revealAddedTaskIfReady(gid: gid)
                    taskStore.lastAddedGid = nil
                }
            }
        }
        .onChange(of: taskStore.tasks) {
            if let gid = pendingRevealGid {
                revealAddedTaskIfReady(gid: gid)
            }
            checkPendingMagnetConfirm()
        }
        .onChange(of: taskStore.pendingMagnetConfirmGid) {
            checkPendingMagnetConfirm()
        }
        .onChange(of: selection) {
            withAnimation(.spring()) {
                selectedTaskGids.removeAll()
            }
        }
        .onChange(of: selectedTaskGids) {
            if selectedTaskGids.count == 1 {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isInspectorPresented = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .maltexToggleInspector)) { _ in
            withAnimation(.easeInOut(duration: 0.22)) {
                isInspectorPresented.toggle()
            }
        }
        .alert("引擎错误", isPresented: engineAlertBinding) {
            Button("重试") {
                taskStore.lastError = nil
                taskStore.shouldPresentEngineError = false
                EngineManager.shared.restart(settings: settings)
                taskStore.reconnectToConfiguredRPCAfterEngineRestart()
            }
            Button("取消", role: .cancel) {
                taskStore.lastError = nil
                taskStore.shouldPresentEngineError = false
            }
        } message: {
            if let error = taskStore.lastError {
                Text(error)
            }
        }
        .alert("任务已存在", isPresented: duplicateAlertBinding) {
            if taskStore.pendingDuplicateDownload?.canAutoRedownload == true {
                Button("重新下载", role: .destructive) {
                    taskStore.forceRedownload()
                }
                Button("取消", role: .cancel) {
                    taskStore.pendingDuplicateDownload = nil
                }
            } else {
                Button("确定", role: .cancel) {
                    taskStore.pendingDuplicateDownload = nil
                }
            }
        } message: {
            if taskStore.pendingDuplicateDownload?.canAutoRedownload == true {
                Text("相同的下载任务已在列表中。是否删除已有任务并重新下载？")
            } else {
                Text("相同的种子任务已在列表中。请先在任务列表中删除已有任务，然后再尝试添加。")
            }
        }
    }


    private var duplicateAlertBinding: Binding<Bool> {
        Binding(
            get: { taskStore.pendingDuplicateDownload != nil },
            set: {
                if !$0 {
                    taskStore.pendingDuplicateDownload = nil
                }
            }
        )
    }

    private var engineAlertBinding: Binding<Bool> {
        Binding(
            get: { taskStore.shouldPresentEngineError && taskStore.lastError != nil },
            set: {
                if !$0 {
                    taskStore.lastError = nil
                    taskStore.shouldPresentEngineError = false
                }
            }
        )
    }

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: $selection) {
            Section("下载状态") {
                Label("所有任务", systemImage: "tray.2")
                    .tag("all")
                Label("正在下载", systemImage: "arrow.down.circle")
                    .tag("downloading")
                Label("正在上传", systemImage: "arrow.up.circle")
                    .tag("uploading")
                Label("等待下载", systemImage: "clock")
                    .tag("waiting")
                Label("已暂停", systemImage: "pause.circle")
                    .tag("paused")
                Label("已停止", systemImage: "stop.circle")
                    .tag("stopped")
                Label("已完成", systemImage: "checkmark.circle")
                    .tag("completed")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 0, maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 6) {
                    Circle()
                        .fill(sidebarStatusColor)
                        .frame(width: 7, height: 7)
                    Text(sidebarStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if sidebarStatus == .error {
                        Button {
                            taskStore.lastError = nil
                            taskStore.shouldPresentEngineError = false
                            EngineManager.shared.restart(settings: settings)
                            taskStore.reconnectToConfiguredRPCAfterEngineRestart()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(Text("重启内核"))
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private enum SidebarEngineStatus {
        case normal
        case connecting
        case error
    }

    private var sidebarStatus: SidebarEngineStatus {
        if engine.isRunning && taskStore.isConnected {
            return .normal
        }
        if engine.isRunning && taskStore.lastError == nil {
            return .connecting
        }
        return .error
    }

    private var sidebarStatusColor: Color {
        switch sidebarStatus {
        case .normal:
            return .green
        case .connecting:
            return .orange
        case .error:
            return .red
        }
    }

    private var sidebarStatusText: LocalizedStringKey {
        switch sidebarStatus {
        case .normal:
            return "内核正常"
        case .connecting:
            return "正在连接"
        case .error:
            return "内核错误"
        }
    }

    @ViewBuilder
    private var detailView: some View {
        Group {
            if let selection {
                TaskListView(
                    status: selection,
                    selectedTaskGids: $selectedTaskGids,
                    isShowingAddTask: $isShowingAddTask,
                    isInspectorPresented: $isInspectorPresented
                )
            } else {
                ContentUnavailableView("请选择一个分类", systemImage: "sidebar.left")
            }
        }
    }

    private var selectedDetailTask: DownloadTask? {
        guard selectedTaskGids.count == 1,
            let gid = selectedTaskGids.first
        else {
            return nil
        }
        return taskStore.tasks.first(where: { $0.gid == gid })
    }

    private func revealAddedTaskIfReady(gid: String) {
        // 若此任务为正在等待下载元数据的磁力链接元数据任务，等待派生真正下载任务后再处理
        if taskStore.isPendingMagnetMetadata(gid: gid) {
            pendingRevealGid = nil
            return
        }

        guard let task = taskStore.tasks.first(where: { $0.gid == gid }) else { return }

        if task.bittorrent != nil && task.status == .paused {
            // Wait for metadata/file list so the confirm sheet is usable.
            guard !task.files.isEmpty else { return }
            confirmTask = task
            pendingRevealGid = nil
            return
        }

        selectedTaskGids = [gid]
        pendingRevealGid = nil
    }

    private func checkPendingMagnetConfirm() {
        guard let gid = taskStore.pendingMagnetConfirmGid else { return }
        if let task = taskStore.tasks.first(where: { $0.gid == gid }) {
            confirmTask = task
            selectedTaskGids = [gid]
            taskStore.pendingMagnetConfirmGid = nil
        }
    }
}



struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        if visualEffectView.material != material {
            visualEffectView.material = material
        }
        if visualEffectView.blendingMode != blendingMode {
            visualEffectView.blendingMode = blendingMode
        }
    }
}
