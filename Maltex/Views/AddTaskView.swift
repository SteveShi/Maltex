import SwiftUI
import UniformTypeIdentifiers

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @State private var urls: String = ""
    @State private var selectedTorrentPath: String?
    @State private var downloadPath: String = ""
    @FocusState private var isFieldFocused: Bool
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建下载任务")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("输入下载链接 (HTTP/HTTPS/Magnet)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("", text: $urls, axis: .vertical)
                    .focused($isFieldFocused)
                    .lineLimit(5, reservesSpace: true)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }

            HStack {
                Button(action: selectTorrentFile) {
                    Label(
                        selectedTorrentPath == nil
                            ? String(localized: "选择种子文件...") : String(localized: "更改种子文件"),
                        systemImage: "doc.badge.plus")
                }
                .buttonStyle(.link)

                if let path = selectedTorrentPath {
                    Text((path as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Button(action: { selectedTorrentPath = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("下载位置")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("", text: $downloadPath)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("选择...") {
                        selectDownloadFolder()
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("立即下载") {
                    submitTasks()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    urls.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && selectedTorrentPath == nil
                )
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 480)
        .onAppear {
            if downloadPath.isEmpty {
                downloadPath = settings.downloadPath
            }

            // Check clipboard
            if let clipboardString = NSPasteboard.general.string(forType: .string) {
                let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("magnet:") || trimmed.hasPrefix("http://")
                    || trimmed.hasPrefix("https://") || trimmed.hasPrefix("thunder://")
                {
                    urls = trimmed
                }
            }

            // Using a slightly longer delay and ensuring focused value is set
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFieldFocused = true
            }
        }
    }

    private func selectTorrentFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent")!]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            selectedTorrentPath = panel.url?.path
        }
    }

    private func selectDownloadFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if !downloadPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: downloadPath)
        }
        if panel.runModal() == .OK {
            downloadPath = panel.url?.path ?? downloadPath
        }
    }

    private func submitTasks() {
        let trimmedDir = downloadPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetDir = trimmedDir.isEmpty ? nil : trimmedDir

        if let torrentPath = selectedTorrentPath {
            taskStore.addTorrent(at: torrentPath, dir: targetDir)
        }

        let urlList = urls.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !urlList.isEmpty {
            taskStore.addUri(urlList, dir: targetDir)
        }

        dismiss()
    }
}
