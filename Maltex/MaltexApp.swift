import SwiftUI
import AppKit

extension Notification.Name {
    static let maltexOpenFileURL = Notification.Name("maltex.openFileURL")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        print("[App] Application will terminate, stopping engine...")
        EngineManager.shared.stop()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        NotificationCenter.default.post(name: .maltexOpenFileURL, object: url)
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            NotificationCenter.default.post(name: .maltexOpenFileURL, object: url)
        }
        application.reply(toOpenOrPrint: .success)
    }
}

@main
struct MaltexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var taskStore = TaskStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var updater = Updater()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(taskStore)
                .environmentObject(settingsStore)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .maltexOpenFileURL)) { notification in
                    if let url = notification.object as? URL {
                        handleIncomingURL(url)
                    }
                }
                .onWindow { window in
                    guard let window = window else { return }
                    window.titlebarAppearsTransparent = true
                    window.styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    // Ensure the toolbar/titlebar buttons are still usable but blend in
                }
                .task {
                    await autoSyncTrackersOnLaunch()
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("Check for Updates...")) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(taskStore)
        }

        MaltexMenuBar(taskStore: taskStore)
    }

    private func autoSyncTrackersOnLaunch() async {
        guard settingsStore.autoSyncTracker else { return }
        let sourceURLs = settingsStore.selectedTrackerSourceURLs
        guard !sourceURLs.isEmpty else { return }

        // Wait a bit for the engine to fully start
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        let service = TrackerService()
        let proxyHost = settingsStore.proxyEnabled ? settingsStore.proxyHost : nil
        let proxyPort = settingsStore.proxyEnabled ? settingsStore.proxyPort : nil

        let result = await service.fetchTrackers(
            from: sourceURLs,
            proxyHost: proxyHost,
            proxyPort: proxyPort
        )

        if result.hasData {
            settingsStore.trackerServers = result.trackers.joined(separator: "\n")
            settingsStore.lastTrackerSyncTime = Date().timeIntervalSince1970
            // Silently restart engine to apply new trackers
            EngineManager.shared.restart()
            print("[App] Auto-synced \(result.trackers.count) trackers from \(sourceURLs.count) source(s)")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        let urlString = url.absoluteString
        var downloadURL: String = ""

        if url.isFileURL && url.pathExtension.lowercased() == "torrent" {
            taskStore.addTorrent(at: url.path)
            return
        }

        if urlString.hasPrefix("maltex://") {
            downloadURL = urlString.replacingOccurrences(of: "maltex://", with: "")
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItem = components.queryItems?.first(where: { $0.name == "url" })
            {
                downloadURL = queryItem.value ?? downloadURL
            }
        } else if urlString.hasPrefix("magnet:")
            || urlString.hasPrefix("thunder:")
            || urlString.hasPrefix("http://")
            || urlString.hasPrefix("https://")
        {
            downloadURL = urlString
        }

        if !downloadURL.isEmpty {
            taskStore.addUri([downloadURL])
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func onWindow(callback: @escaping (NSWindow?) -> Void) -> some View {
        background(WindowAccessor(callback: callback))
    }
}
