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
        }
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(taskStore)
        }

        MaltexMenuBar(taskStore: taskStore)
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
