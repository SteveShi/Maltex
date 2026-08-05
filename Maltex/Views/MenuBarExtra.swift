import AppKit
import SwiftUI

struct MaltexMenuBar: Scene {
    @ObservedObject var taskStore: TaskStore

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(taskStore: taskStore)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                if taskStore.totalDownloadSpeed > 0 {
                    Text("\(ByteCountFormatterUtil.string(fromByteCount: taskStore.totalDownloadSpeed))/s")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarView: View {
    @ObservedObject var taskStore: TaskStore
    @Environment(\.openWindow) private var openWindow

    private var activeTasks: [DownloadTask] {
        taskStore.tasks.filter { !$0.isDownloadComplete }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.accentColor)
                    Text(LocalizedStringKey("Maltex"))
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                if taskStore.totalDownloadSpeed > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(ByteCountFormatterUtil.string(fromByteCount: taskStore.totalDownloadSpeed))/s")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(10)
                } else {
                    Text(String(format: String(localized: "%d 个活跃任务"), activeTasks.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            // 活跃下载任务列表 / 空状态
            if activeTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(LocalizedStringKey("无活跃下载任务"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(activeTasks.prefix(8)) { task in
                            MenuBarTaskRow(task: task)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // 底部操作栏
            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                } label: {
                    Label(LocalizedStringKey("显示主窗口"), systemImage: "macwindow")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label(LocalizedStringKey("退出"), systemImage: "power")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 340)
    }
}

private struct MenuBarTaskRow: View {
    let task: DownloadTask

    private var progressRatio: Double {
        guard task.totalLength > 0 else { return 0 }
        return min(1.0, Double(task.completedLength) / Double(task.totalLength))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题与下载速度 / 状态
            HStack(spacing: 8) {
                Image(systemName: task.bittorrent != nil ? "arrow.triangle.2.circlepath" : "doc.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text(task.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if task.status == .active && task.downloadSpeed > 0 {
                    Text("\(ByteCountFormatterUtil.string(fromByteCount: task.downloadSpeed))/s")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                } else {
                    Text(task.localizedDisplayStatusName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 进度条
            ProgressView(value: progressRatio)
                .progressViewStyle(.linear)
                .controlSize(.small)

            // 详细统计数据
            HStack {
                Text("\(Int(progressRatio * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                if task.totalLength > 0 {
                    Text("\(ByteCountFormatterUtil.string(fromByteCount: task.completedLength)) / \(ByteCountFormatterUtil.string(fromByteCount: task.totalLength))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if let remaining = task.remainingSeconds {
                    Text("• \(DurationFormatterUtil.string(fromSeconds: remaining))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
