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
    private let maxWindowHeight: CGFloat = 680

    var body: some View {
        TabView {
            GeneralSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem {
                    Label("常规", systemImage: "gear")
                }

            Aria2SettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem {
                    Label("Aria2", systemImage: "server.rack")
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

private enum Aria2SettingsCategory: String, CaseIterable, Identifiable {
    case overview
    case source
    case rpc
    case downloads
    case http
    case files
    case advanced

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "概览"
        case .source: "内核来源"
        case .rpc: "RPC 设置"
        case .downloads: "下载任务"
        case .http: "HTTP/FTP/SFTP"
        case .files: "文件与会话"
        case .advanced: "高级参数"
        }
    }

    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .source: "server.rack"
        case .rpc: "network"
        case .downloads: "arrow.down.circle"
        case .http: "globe"
        case .files: "folder"
        case .advanced: "slider.horizontal.3"
        }
    }
}

struct Aria2SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @StateObject private var engine = EngineManager.shared
    @State private var showRestartPrompt = false
    @State private var selectedCategory: Aria2SettingsCategory? = .overview

    private var binarySourceBinding: Binding<SettingsStore.Aria2BinarySource> {
        Binding(
            get: { settings.aria2BinarySource },
            set: { settings.aria2BinarySource = $0 }
        )
    }

    private var sourceSummary: LocalizedStringKey {
        switch settings.aria2BinarySource {
        case .bundled: "使用 Maltex 随附的 aria2c，所有启动参数均由本页控制。"
        case .commandLine: "使用 Homebrew 或系统路径中的 aria2c，仍由 Maltex 启动和停止。"
        case .custom: "使用指定路径的 aria2c，仍由 Maltex 启动和停止。"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedCategory) {
                ForEach(Aria2SettingsCategory.allCases) { category in
                    Label(category.title, systemImage: category.icon)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: 180)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    detailView(for: selectedCategory ?? .overview)

                    HStack {
                        Spacer()
                        Button {
                            showRestartPrompt = true
                        } label: {
                            Label("应用并重启内核", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom, 16)
                }
                .padding()
            }
        }
        .alert("应用 Aria2 设置", isPresented: $showRestartPrompt) {
            Button(String(localized: "立即重启")) {
                restartEngine()
            }
            Button(String(localized: "稍后"), role: .cancel) {}
        } message: {
            Text("这些设置需要重启 Aria2 内核后生效。")
        }
    }

    @ViewBuilder
    private func detailView(for category: Aria2SettingsCategory) -> some View {
        switch category {
        case .overview:
            overviewSection
        case .source:
            sourceSection
        case .rpc:
            rpcSection
        case .downloads:
            downloadSection
        case .http:
            httpSection
        case .files:
            fileSection
        case .advanced:
            advancedSection
        }
    }

    private var overviewSection: some View {
        Group {
            SettingsSection("内核控制") {
                AlignedFormRow("运行状态") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(engine.isRunning ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(engine.isRunning ? "运行中" : "已停止")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                AlignedFormRow("内核来源") {
                    Text(settings.aria2BinarySource.localizedName)
                        .font(.system(size: 13))
                }

                AlignedFormRow("随软件启动内核") {
                    Toggle("", isOn: $settings.aria2StartOnLaunch)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                AlignedFormRow("当前可执行文件") {
                    Text(engine.activeBinaryPath.isEmpty ? String(localized: "尚未启动") : engine.activeBinaryPath)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }

                AlignedFormRow("内核操作") {
                    HStack(spacing: 8) {
                        Button {
                            EngineManager.shared.start(settings: settings)
                            taskStore.reconnectToConfiguredRPCAfterEngineRestart()
                        } label: {
                            Label("启动", systemImage: "play.fill")
                        }
                        .disabled(engine.isRunning)

                        Button {
                            EngineManager.shared.stop()
                            taskStore.reconnectToConfiguredRPC()
                        } label: {
                            Label("停止", systemImage: "stop.fill")
                        }
                        .disabled(!engine.isRunning)

                        Button {
                            restartEngine()
                        } label: {
                            Label("重启", systemImage: "arrow.clockwise")
                        }
                    }
                }

                if !engine.lastMessage.isEmpty {
                    AlignedFormRow("最近状态") {
                        Text(engine.lastMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        SettingsSection("Aria2 来源") {
            AlignedFormRow("内核来源") {
                Picker("", selection: binarySourceBinding) {
                    ForEach(SettingsStore.Aria2BinarySource.allCases) { source in
                        Text(source.localizedName).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            AlignedFormRow("生效范围") {
                Text(sourceSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if settings.aria2BinarySource == .custom {
                AlignedFormRow("自定义路径") {
                    HStack {
                        TextField("/opt/homebrew/bin/aria2c", text: $settings.customAria2Path)
                            .textFieldStyle(.roundedBorder)
                        Button("选择...") {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            if panel.runModal() == .OK {
                                settings.customAria2Path = panel.url?.path ?? settings.customAria2Path
                            }
                        }
                    }
                }
            }
        }
    }

    private var rpcSection: some View {
        SettingsSection("RPC 设置") {
            AlignedFormRow("RPC 主机") {
                TextField("127.0.0.1", text: $settings.rpcHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
            AlignedFormRow("RPC 监听端口") {
                TextField("", value: $settings.rpcPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            AlignedFormRow("RPC 授权密钥", description: "建议设置以增强安全性") {
                SecureField("未设置", text: $settings.rpcSecret)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }
            AlignedFormRow("监听所有地址") {
                Toggle("", isOn: $settings.rpcListenAll)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            AlignedFormRow("允许所有来源") {
                Toggle("", isOn: $settings.rpcAllowOriginAll)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var downloadSection: some View {
        Group {
            SettingsSection("任务并发") {
                numericRow("最大并发任务数", value: $settings.maxConcurrentDownloads, unit: "个", width: 80)
                numericRow("单服务器连接数", value: $settings.maxConnectionPerServer, unit: "个", width: 80)
                numericRow("最小分片大小", value: $settings.minSplitSize, unit: "MB", width: 80)
            }

            SettingsSection("速度限制") {
                numericRow("上限下载网速", value: $settings.maxOverallDownloadLimit, unit: "KB/s", width: 90)
                numericRow("上限上传网速", value: $settings.maxOverallUploadLimit, unit: "KB/s", width: 90)
            }
        }
    }

    private var httpSection: some View {
        SettingsSection("HTTP/FTP/SFTP") {
            numericRow("最大重试次数", value: $settings.maxTries, unit: "次", width: 80)
            numericRow("重试等待", value: $settings.retryWait, unit: "秒", width: 80)
            numericRow("连接超时", value: $settings.connectTimeout, unit: "秒", width: 80)
            numericRow("传输超时", value: $settings.timeout, unit: "秒", width: 80)
            toggleRow("校验证书", isOn: $settings.checkCertificate)
            AlignedFormRow("用户代理") {
                TextField("默认", text: $settings.userAgent)
                    .textFieldStyle(.roundedBorder)
            }
            AlignedFormRow("引用页") {
                TextField("默认", text: $settings.referer)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var fileSection: some View {
        SettingsSection("文件与会话") {
            AlignedFormRow("文件分配") {
                Picker("", selection: $settings.fileAllocation) {
                    Text("none").tag("none")
                    Text("prealloc").tag("prealloc")
                    Text("trunc").tag("trunc")
                }
                .frame(width: 140)
            }
            numericRow("磁盘缓存", value: $settings.diskCache, unit: "MB", width: 80)
            numericRow("保存会话间隔", value: $settings.saveSessionInterval, unit: "秒", width: 80)
            numericRow("最大下载结果", value: $settings.maxDownloadResult, unit: "项", width: 80)
            toggleRow("断点续传", isOn: $settings.continueDownloads)
            toggleRow("自动重命名", isOn: $settings.autoFileRenaming)
            toggleRow("允许覆盖文件", isOn: $settings.allowOverwrite)
            toggleRow("Content-Disposition UTF-8", isOn: $settings.contentDispositionDefaultUTF8)
        }
    }

    private var advancedSection: some View {
        SettingsSection("附加命令行参数") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $settings.extraAria2Arguments)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 120)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3))
                    )
                Text("每行输入一个 aria2c 参数，例如 --summary-interval=0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func restartEngine() {
        EngineManager.shared.restart(settings: settings)
        taskStore.reconnectToConfiguredRPCAfterEngineRestart()
    }

    private func numericRow(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        unit: LocalizedStringKey,
        width: CGFloat
    ) -> some View {
        AlignedFormRow(title) {
            HStack {
                TextField("", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: width)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleRow(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        AlignedFormRow(title) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
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
    @EnvironmentObject var taskStore: TaskStore
    @State private var trackerService = TrackerService()
    @State private var customSourceInput = ""
    @State private var showSyncAlert = false
    @State private var syncAlertTitle = ""
    @State private var syncAlertMessage = ""
    @State private var showRestartPrompt = false
    @State private var trackerEntries: [TrackerEntry] = []
    @State private var showProbePanel = false

    private var trackerCount: Int {
        settings.trackerServers
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    private var lastSyncText: String {
        guard let date = settings.lastTrackerSyncDate else {
            return String(localized: "从未同步")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return String(localized: "上次同步: \(formatter.string(from: date))")
    }

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

                trackerSourceSection

                trackerListSection

                SettingsSection("进阶设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("保存磁力链接元数据为种子文件 (.torrent)", isOn: $settings.btSaveMetadata)
                        Toggle("自动开始下载磁力链接和种子内容", isOn: $settings.btAutoStart)
                        Toggle("强制 BT 加密 (BT Require Crypto)", isOn: $settings.btForceEncryption)
                        Toggle("启动时自动同步 Tracker", isOn: $settings.autoSyncTracker)
                    }
                    .padding(.top, 4)
                }

                SettingsSection("BitTorrent 高级") {
                    AlignedFormRow("最大连接 Peer") {
                        HStack {
                            TextField("", value: $settings.btMaxPeers, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    AlignedFormRow("Peer 速度下限") {
                        HStack {
                            TextField("", value: $settings.btRequestPeerSpeedLimit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("KB/s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    AlignedFormRow("分享率") {
                        TextField("", value: $settings.seedRatio, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    AlignedFormRow("做种时间") {
                        HStack {
                            TextField("", value: $settings.seedTime, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .alert(syncAlertTitle, isPresented: $showSyncAlert) {
            Button(String(localized: "确定")) {}
        } message: {
            Text(syncAlertMessage)
        }
        .alert("Tracker 已更新", isPresented: $showRestartPrompt) {
            Button(String(localized: "立即重启")) {
                Task { @MainActor in
                    EngineManager.shared.restart(settings: settings)
                    taskStore.reconnectToConfiguredRPCAfterEngineRestart()
                }
            }
            Button(String(localized: "稍后"), role: .cancel) {}
        } message: {
            Text("Tracker 列表已更新，需要重启引擎才能生效。是否立即重启？")
        }
    }

    // MARK: - Tracker Source Selection

    private var trackerSourceSection: some View {
        SettingsSection("Tracker 源") {
            VStack(alignment: .leading, spacing: 16) {
                // Preset sources
                ForEach(TrackerPresets.groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach(group.sources) { source in
                            trackerSourceRow(source: source)
                        }
                    }
                }

                Divider()

                // Custom sources
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义源")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        TextField("输入 Tracker 源 URL", text: $customSourceInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onSubmit { addCustomSource() }

                        Button {
                            addCustomSource()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(customSourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    ForEach(settings.customTrackerSourceURLs, id: \.self) { url in
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Text(url)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { settings.selectedTrackerSourceURLs.contains(url) },
                                set: { enabled in
                                    toggleSource(url: url, enabled: enabled)
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .controlSize(.small)

                            Button {
                                removeCustomSource(url)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Divider()

                // Sync controls
                HStack(spacing: 12) {
                    Button {
                        Task { await syncTrackers() }
                    } label: {
                        HStack(spacing: 6) {
                            if trackerService.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("同步 Tracker")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(trackerService.isSyncing || settings.selectedTrackerSourceURLs.isEmpty)

                    Text(lastSyncText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Tracker List

    private var trackerListSection: some View {
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

                HStack {
                    Text("每行输入一个 Tracker 地址")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("共 \(trackerCount) 个 Tracker")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Probe controls
                HStack(spacing: 12) {
                    Button {
                        if showProbePanel {
                            trackerService.cancelProbe()
                            showProbePanel = false
                            trackerEntries = []
                        } else {
                            showProbePanel = true
                            trackerEntries = TrackerEntry.fromTrackerString(settings.trackerServers)
                            Task { await probeAllTrackers() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if trackerService.isProbing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text(showProbePanel ? "关闭探测" : "探测 Tracker")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(trackerCount == 0)

                    if showProbePanel {
                        let onlineCount = trackerEntries.filter { $0.status == .online }.count
                        let offlineCount = trackerEntries.filter { $0.status == .offline }.count
                        let unknownCount = trackerEntries.filter { $0.status == .unknown || $0.status == .checking }.count

                        HStack(spacing: 8) {
                            probeStatBadge(count: onlineCount, color: .green, label: String(localized: "在线"))
                            probeStatBadge(count: offlineCount, color: .red, label: String(localized: "离线"))
                            probeStatBadge(count: unknownCount, color: .gray, label: String(localized: "未知"))
                        }

                        Spacer()

                        if offlineCount > 0 && !trackerService.isProbing {
                            Button {
                                removeOfflineTrackers()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("移除离线")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    } else {
                        Spacer()
                    }
                }

                // Probe result list
                if showProbePanel && !trackerEntries.isEmpty {
                    trackerProbeList
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Probe List

    private var trackerProbeList: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("协议")
                    .frame(width: 50, alignment: .leading)
                Text("Tracker 地址")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("状态")
                    .frame(width: 60, alignment: .center)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(trackerEntries) { entry in
                        trackerProbeRow(entry: entry)
                        Divider().opacity(0.5)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2))
        )
    }

    private func trackerProbeRow(entry: TrackerEntry) -> some View {
        HStack(spacing: 0) {
            // Protocol badge
            Text(entry.protocolScheme.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(protocolColor(entry.protocolScheme))
                .frame(width: 50, alignment: .leading)

            // URL
            Text(entry.url)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Status indicator
            probeStatusView(entry.status)
                .frame(width: 60, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(entry.status == .offline ? Color.red.opacity(0.05) : Color.clear)
    }

    @ViewBuilder
    private func probeStatusView(_ status: TrackerProbeStatus) -> some View {
        switch status {
        case .checking:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.6)
        case .online:
            HStack(spacing: 3) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("在线")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        case .offline:
            HStack(spacing: 3) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Text("离线")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        case .unknown:
            HStack(spacing: 3) {
                Circle().fill(Color.gray).frame(width: 7, height: 7)
                Text("未知")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }

    private func protocolColor(_ scheme: String) -> Color {
        switch scheme.lowercased() {
        case "https": return .green
        case "http": return .blue
        case "udp": return .orange
        case "wss", "ws": return .purple
        default: return .gray
        }
    }

    private func probeStatBadge(count: Int, color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Source Row

    private func trackerSourceRow(source: TrackerSource) -> some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { settings.selectedTrackerSourceURLs.contains(source.url) },
                set: { enabled in
                    toggleSource(url: source.url, enabled: enabled)
                }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Text(source.label)
                .font(.system(size: 12))

            if source.isCDN {
                Text("CDN")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(3)
            }

            Spacer()
        }
        .padding(.vertical, 1)
    }

    // MARK: - Actions

    private func toggleSource(url: String, enabled: Bool) {
        var selected = settings.selectedTrackerSourceURLs
        if enabled {
            if !selected.contains(url) {
                selected.append(url)
            }
        } else {
            selected.removeAll { $0 == url }
        }
        settings.selectedTrackerSourceURLs = selected
    }

    private func addCustomSource() {
        let url = customSourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        guard TrackerService.isValidTrackerSourceURL(url) else {
            syncAlertTitle = String(localized: "无效 URL")
            syncAlertMessage = String(localized: "请输入有效的 HTTP/HTTPS URL")
            showSyncAlert = true
            return
        }

        var customURLs = settings.customTrackerSourceURLs
        guard !customURLs.contains(url) else {
            customSourceInput = ""
            return
        }

        customURLs.append(url)
        settings.customTrackerSourceURLs = customURLs

        // Auto-select the newly added source
        var selected = settings.selectedTrackerSourceURLs
        if !selected.contains(url) {
            selected.append(url)
            settings.selectedTrackerSourceURLs = selected
        }

        customSourceInput = ""
    }

    private func removeCustomSource(_ url: String) {
        settings.customTrackerSourceURLs.removeAll { $0 == url }
        settings.selectedTrackerSourceURLs.removeAll { $0 == url }
    }

    private func syncTrackers() async {
        let sourceURLs = settings.selectedTrackerSourceURLs
        guard !sourceURLs.isEmpty else {
            syncAlertTitle = String(localized: "同步失败")
            syncAlertMessage = String(localized: "请先选择至少一个 Tracker 源")
            showSyncAlert = true
            return
        }

        let proxyHost = settings.proxyEnabled ? settings.proxyHost : nil
        let proxyPort = settings.proxyEnabled ? settings.proxyPort : nil

        let result = await trackerService.fetchTrackers(
            from: sourceURLs,
            proxyHost: proxyHost,
            proxyPort: proxyPort
        )

        if result.allSucceeded && result.hasData {
            settings.trackerServers = result.trackers.joined(separator: "\n")
            settings.lastTrackerSyncTime = Date().timeIntervalSince1970
            showRestartPrompt = true
        } else if result.hasData {
            // Partial success
            settings.trackerServers = result.trackers.joined(separator: "\n")
            settings.lastTrackerSyncTime = Date().timeIntervalSince1970
            let failedList = result.failures.map { "• \($0.url)\n  \($0.reason)" }.joined(separator: "\n")
            syncAlertTitle = String(localized: "部分同步成功")
            syncAlertMessage = String(
                localized: "成功同步 \(sourceURLs.count - result.failures.count)/\(sourceURLs.count) 个源。\n\n失败:\n\(failedList)")
            showSyncAlert = true
            // Defer restart prompt until sync alert is dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRestartPrompt = true
            }
        } else {
            let failedList = result.failures.map { "• \($0.url)\n  \($0.reason)" }.joined(separator: "\n")
            syncAlertTitle = String(localized: "同步失败")
            syncAlertMessage = String(localized: "所有源均同步失败:\n\(failedList)")
            showSyncAlert = true
        }
    }

    // MARK: - Probe Actions

    private func probeAllTrackers() async {
        // Mark all as checking first
        for i in trackerEntries.indices {
            trackerEntries[i].status = trackerEntries[i].isProbeable ? .checking : .unknown
        }

        await trackerService.probeTrackers(entries: trackerEntries) { url, status in
            Task { @MainActor in
                if let idx = trackerEntries.firstIndex(where: { $0.url == url }) {
                    trackerEntries[idx].status = status
                }
            }
        }
    }

    private func removeOfflineTrackers() {
        let offlineURLs = Set(trackerEntries.filter { $0.status == .offline }.map(\.url))
        guard !offlineURLs.isEmpty else { return }

        // Update tracker list
        let remaining = settings.trackerServers
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !offlineURLs.contains($0) }
        settings.trackerServers = remaining.joined(separator: "\n")

        // Update probe list
        trackerEntries.removeAll { $0.status == .offline }

        showRestartPrompt = true
    }
}
