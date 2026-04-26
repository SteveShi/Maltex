import SwiftUI

struct TorrentConfirmView: View {
    let task: DownloadTask
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @State private var downloadPath: String
    var onConfirm: (String, Set<String>) -> Void
    var onCancel: () -> Void

    init(
        task: DownloadTask, onConfirm: @escaping (String, Set<String>) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.task = task
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _downloadPath = State(initialValue: task.dir)
    }

    @State private var selectedFileIndices: Set<String> = []

    // Sort files by path for better display order
    private var sortedFiles: [DownloadFile] {
        task.files.sorted { $0.path < $1.path }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("确认下载种子")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Torrent Info
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.bittorrent?.info?.name ?? String(localized: "未知种子"))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(2)

                            Text(
                                String(localized: "总大小: ") + ByteCountFormatterUtil.string(fromByteCount: task.totalLength)
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Download Path Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("下载路径")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("", text: $downloadPath)
                                .textFieldStyle(.roundedBorder)
                            Button("选择...") {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = true
                                panel.canChooseFiles = false
                                if panel.runModal() == .OK {
                                    downloadPath = panel.url?.path ?? downloadPath
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)

                    // Files List Header
                    let filesTitle = String(
                        format: String(localized: "文件列表 (%@)"), "\(task.files.count)")
                    HStack {
                        Text(filesTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            if selectedFileIndices.count == task.files.count {
                                selectedFileIndices.removeAll()
                            } else {
                                selectedFileIndices = Set(task.files.map { $0.index })
                            }
                        }) {
                            let title =
                                selectedFileIndices.count == task.files.count
                                ? String(localized: "取消全选") : String(localized: "全选")
                            Text(title)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)

                    // Files List
                    FileListView(files: sortedFiles, selectedFileIndices: $selectedFileIndices)
                }
                .padding(.vertical)
            }

            Divider()

            // Footer
            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if selectedFileIndices.isEmpty {
                    Text("请至少选择一个文件")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.trailing)
                }

                Button("立即下载") {
                    if !onConfirmCalled {
                        onConfirmCalled = true
                        onConfirm(downloadPath, selectedFileIndices)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFileIndices.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 550, height: 650)
        .onAppear {
            // Init selection
            selectedFileIndices = Set(task.files.map { $0.index })
        }
    }

    @State private var onConfirmCalled = false
}

struct FileListView: View {
    let files: [DownloadFile]
    @Binding var selectedFileIndices: Set<String>

    var body: some View {
        VStack(spacing: 0) {
            ForEach(files, id: \.index) { file in
                FileRowView(file: file, selectedFileIndices: $selectedFileIndices)
                if file.index != files.last?.index {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct FileRowView: View {
    let file: DownloadFile
    @Binding var selectedFileIndices: Set<String>

    var body: some View {
        HStack {
            Toggle(
                "",
                isOn: Binding(
                    get: { selectedFileIndices.contains(file.index) },
                    set: { isSelected in
                        if isSelected {
                            selectedFileIndices.insert(file.index)
                        } else {
                            selectedFileIndices.remove(file.index)
                        }
                    }
                )
            )
            .labelsHidden()

            Image(systemName: "doc")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.path.components(separatedBy: "/").last ?? file.path)
                    .font(.system(size: 13))
                    .lineLimit(1)
                // Show directory hint if in subdirectory
                if file.path.contains("/") {
                    Text(file.path)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()
            Text(ByteCountFormatterUtil.string(fromByteCount: file.length))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedFileIndices.contains(file.index) {
                selectedFileIndices.remove(file.index)
            } else {
                selectedFileIndices.insert(file.index)
            }
        }
    }
}
