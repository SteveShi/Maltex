import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @State private var selection: String? = "downloading"
    @State private var isShowingAddTask = false
    @State private var selectedTaskGids: Set<String> = []
    @State private var confirmTask: DownloadTask? = nil
    @State private var pendingRevealGid: String? = nil
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationSplitView { sidebarView } detail: { detailView }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskView()
                .environmentObject(taskStore)
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
        .onChange(of: taskStore.tasks.map(\.gid)) {
            if let gid = pendingRevealGid {
                revealAddedTaskIfReady(gid: gid)
            }
        }
        .onChange(of: selection) {
            withAnimation(.spring()) {
                selectedTaskGids.removeAll()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert("引擎错误", isPresented: engineAlertBinding) {
            Button("重试") {
                taskStore.lastError = nil
                EngineManager.shared.restart()
            }
            Button("取消", role: .cancel) {
                taskStore.lastError = nil
            }
        } message: {
            if let error = taskStore.lastError {
                Text(error)
            }
        }
    }


    private var engineAlertBinding: Binding<Bool> {
        Binding(
            get: { taskStore.lastError != nil },
            set: { if !$0 { taskStore.lastError = nil } }
        )
    }

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: $selection) {
            Section("下载状态") {
                NavigationLink(value: "all") {
                    Label("所有任务", systemImage: "tray.2")
                }
                NavigationLink(value: "downloading") {
                    Label("正在下载", systemImage: "arrow.down.circle")
                }
                NavigationLink(value: "waiting") {
                    Label("等待下载", systemImage: "clock")
                }
                NavigationLink(value: "paused") {
                    Label("已暂停", systemImage: "pause.circle")
                }
                NavigationLink(value: "stopped") {
                    Label("已停止", systemImage: "stop.circle")
                }
                NavigationLink(value: "completed") {
                    Label("已完成", systemImage: "checkmark.circle")
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var detailView: some View {
        ZStack(alignment: .bottom) {
            if let selection {
                TaskListView(
                    status: selection,
                    selectedTaskGids: $selectedTaskGids,
                    isShowingAddTask: $isShowingAddTask
                )
            } else {
                ContentUnavailableView("请选择一个分类", systemImage: "sidebar.left")
            }

            if let detailTask = selectedDetailTask {
                TaskDetailView(task: detailTask) {
                    withAnimation(.spring()) {
                        selectedTaskGids.removeAll()
                    }
                }
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .zIndex(10)
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
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
