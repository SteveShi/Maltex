import SwiftUI
import AppKit

struct TaskDetailSidebarView: View {
    let task: DownloadTask?
    var onClose: () -> Void
    @EnvironmentObject var taskStore: TaskStore

    var body: some View {
        VStack(spacing: 0) {
            if let task = task {
                TaskDetailView(task: task, onDismiss: onClose)
            } else {
                emptyView
            }
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
    }

    private var emptyView: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Text("任务详情")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("未选择任务")
                    .font(.headline)
                Text("在列表中选择一个下载任务以查看详情。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
