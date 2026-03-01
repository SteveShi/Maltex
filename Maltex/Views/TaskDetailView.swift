import SwiftUI
import AppKit

struct TaskDetailView: View {
    let task: DownloadTask
    @EnvironmentObject var taskStore: TaskStore
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Text("任务详情")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    HStack(spacing: 16) {
                        Image(
                            systemName: task.bittorrent != nil
                                ? "arrow.down.doc.fill" : "link.circle.fill"
                        )
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                task.bittorrent?.info?.name ?? task.files.first?.path.components(
                                    separatedBy: "/"
                                ).last ?? "未知任务"
                            )
                            .font(.title3)
                            .bold()
                            .lineLimit(2)

                            Text(task.gid)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Statistics Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("任务统计")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                            DetailGridRow(label: "状态", value: task.status.localizedName)
                            DetailGridRow(
                                label: "大小",
                                value: ByteCountFormatterUtil.string(
                                    fromByteCount: task.totalLength))
                            DetailGridRow(
                                label: "已完成",
                                value: ByteCountFormatterUtil.string(
                                    fromByteCount: task.completedLength))
                            DetailGridRow(
                                label: "下载网速",
                                value:
                                    "\(ByteCountFormatterUtil.string(fromByteCount: task.downloadSpeed))/s"
                            )
                            DetailGridRow(
                                label: "上传网速",
                                value:
                                    "\(ByteCountFormatterUtil.string(fromByteCount: task.uploadSpeed))/s"
                            )
                            DetailGridRow(label: "连接数", value: "\(task.connections)")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Files section
                    if !task.files.isEmpty {
                        let filesTitle = String(
                            format: String(localized: "文件列表 (%@)"), "\(task.files.count)")
                        VStack(alignment: .leading, spacing: 12) {
                            Text(filesTitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(task.files, id: \.index) { file in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text((file.path as NSString).lastPathComponent)
                                            .font(.system(size: 13))
                                            .lineLimit(1)

                                        ProgressView(
                                            value: Double(file.completedLength),
                                            total: Double(file.length)
                                        )
                                        .progressViewStyle(.linear)
                                        .tint(.accentColor)

                                        HStack {
                                            Text(
                                                ByteCountFormatterUtil.string(
                                                    fromByteCount: file.completedLength))
                                            Text("/")
                                            Text(
                                                ByteCountFormatterUtil.string(
                                                    fromByteCount: file.length))
                                            Spacer()
                                        }
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    if file.index != task.files.last?.index {
                                        Divider().padding(.horizontal)
                                    }
                                }
                            }
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
    }
}

struct DetailGridRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .bold()
        }
        .font(.system(size: 13))
    }
}
