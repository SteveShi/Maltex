import ServiceManagement
import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    private let minWindowWidth: CGFloat = 620
    private let idealWindowWidth: CGFloat = 700
    private let maxWindowWidth: CGFloat = 860
    private let minWindowHeight: CGFloat = 440
    private let idealWindowHeight: CGFloat = 500
    private let maxWindowHeight: CGFloat = 560

    var body: some View {
        TabView {
            GeneralSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem {
                    Label("常规", systemImage: "gear")
                }

            EngineSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem {
                    Label("进阶", systemImage: "cpu")
                }

            ProxySettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem {
                    Label("代理", systemImage: "network")
                }

            BTSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem {
                    Label("BT 设置", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .padding(20)
        .frame(
            minWidth: minWindowWidth,
            idealWidth: idealWindowWidth,
            maxWidth: maxWindowWidth,
            minHeight: minWindowHeight,
            idealHeight: idealWindowHeight,
            maxHeight: maxWindowHeight
        )
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
}

struct AlignedFormRow<Content: View>: View {
    let label: LocalizedStringKey
    let content: Content
    let description: LocalizedStringKey?

    init(
        _ label: LocalizedStringKey, description: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.description = description
        self.content = content()
    }

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                if let description = description {
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .gridColumnAlignment(.trailing)

            content
                .gridColumnAlignment(.leading)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                content
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .padding(.bottom, 24)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection("下载目录") {
                    AlignedFormRow("默认下载路径") {
                        HStack {
                            TextField("", text: $settings.downloadPath)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.regular)
                            Button("选择...") {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = true
                                panel.canChooseFiles = false
                                if panel.runModal() == .OK {
                                    settings.downloadPath = panel.url?.path ?? settings.downloadPath
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                SettingsSection("预设") {
                    AlignedFormRow("最大并发任务数", description: "同时下载的任务数量") {
                        HStack {
                            TextField("", value: $settings.maxConcurrentDownloads, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Stepper("", value: $settings.maxConcurrentDownloads, in: 1...10)
                                .labelsHidden()
                            Spacer()
                        }
                    }

                    AlignedFormRow("单服务器连接数", description: "每个服务器开启的最大线程数") {
                        HStack {
                            TextField("", value: $settings.maxConnectionPerServer, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Stepper("", value: $settings.maxConnectionPerServer, in: 1...64)
                                .labelsHidden()
                            Spacer()
                        }
                    }
                }

                SettingsSection("速度限制") {
                    AlignedFormRow("上限下载网速", description: "输入 0 为无限制") {
                        HStack {
                            TextField("", value: $settings.maxOverallDownloadLimit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("KB/s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    AlignedFormRow("上限上传网速", description: "输入 0 为无限制") {
                        HStack {
                            TextField("", value: $settings.maxOverallUploadLimit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("KB/s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                SettingsSection("基础设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(
                            "随系统启动",
                            isOn: Binding(
                                get: { settings.launchAtLogin },
                                set: { newValue in
                                    settings.launchAtLogin = newValue
                                    if #available(macOS 13.0, *) {
                                        let service = SMAppService.mainApp
                                        do {
                                            if newValue {
                                                try service.register()
                                            } else {
                                                try service.unregister()
                                            }
                                        } catch {
                                            print(
                                                "[Settings] Failed to update login item: \(error)")
                                        }
                                    }
                                }
                            ))
                        Toggle("启动时自动开始未完成任务", isOn: $settings.autoResumeTasks)
                        Toggle("下载完成后通知", isOn: $settings.notificationEnabled)
                    }
                }

                SettingsSection("状态") {
                    AlignedFormRow(LocalizedStringKey("Aria2连接状态")) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(taskStore.isConnected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(
                                taskStore.isConnected
                                    ? String(localized: "连接正常") : String(localized: "连接失败")
                            )
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct EngineSettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection("RPC 服务") {
                    AlignedFormRow("RPC 监听端口") {
                        TextField("", value: $settings.rpcPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    AlignedFormRow("RPC 授权密钥", description: "建议设置以增强安全性") {
                        SecureField("未设置", text: $settings.rpcSecret)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                    }
                }

                SettingsSection("进阶网络") {
                    AlignedFormRow("监听端口") {
                        TextField("", value: $settings.listenPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
            }
            .padding()
        }
    }
}

struct ProxySettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection("代理服务") {
                    AlignedFormRow("启用代理") {
                        Toggle("", isOn: $settings.proxyEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                }

                if settings.proxyEnabled {
                    SettingsSection("配置详情") {
                        AlignedFormRow("代理服务器地址") {
                            TextField("127.0.0.1", text: $settings.proxyHost)
                                .textFieldStyle(.roundedBorder)
                        }
                        AlignedFormRow("端口") {
                            TextField("1080", text: $settings.proxyPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    SettingsSection("身份验证") {
                        AlignedFormRow("用户名") {
                            TextField("可选", text: $settings.proxyUser)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }
                        AlignedFormRow("密码") {
                            SecureField("可选", text: $settings.proxyPass)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
struct BTSettingsView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection("节点与端口") {
                    AlignedFormRow("BT 监听端口") {
                        TextField("", value: $settings.btPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    AlignedFormRow("DHT 监听端口") {
                        TextField("", value: $settings.dhtPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    AlignedFormRow("UPnP / NAT-PMP") {
                        Toggle("", isOn: $settings.upnpEnabled)
                            .toggleStyle(.switch)
                    }
                }

                SettingsSection("Tracker 服务器") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $settings.trackerServers)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 100)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6).stroke(
                                    Color.secondary.opacity(0.3))
                            )
                        Text("每行输入一个 Tracker 地址")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                SettingsSection("进阶设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("保存磁力链接元数据为种子文件 (.torrent)", isOn: $settings.btSaveMetadata)
                        Toggle("自动开始下载磁力链接和种子内容", isOn: $settings.btAutoStart)
                        Toggle("强制 BT 加密 (BT Require Crypto)", isOn: $settings.btForceEncryption)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
    }
}
