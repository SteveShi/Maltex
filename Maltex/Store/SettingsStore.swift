import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    enum Aria2BinarySource: String, CaseIterable, Identifiable {
        case bundled
        case commandLine
        case custom

        var id: String { rawValue }

        var localizedName: LocalizedStringKey {
            switch self {
            case .bundled: "内置 Aria2"
            case .commandLine: "命令行 Aria2"
            case .custom: "自定义 Aria2"
            }
        }
    }

    // General
    @AppStorage("maxConcurrentDownloads") var maxConcurrentDownloads: Int = 5
    @AppStorage("maxConnectionPerServer") var maxConnectionPerServer: Int = 16
    @AppStorage("downloadPath") var downloadPath: String =
        (FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "")

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("autoResumeTasks") var autoResumeTasks: Bool = true
    @AppStorage("notificationEnabled") var notificationEnabled: Bool = true

    // RPC
    @AppStorage("rpcHost") var rpcHost: String = "127.0.0.1"
    @AppStorage("rpcPort") var rpcPort: Int = 16800
    @AppStorage("rpcSecret") var rpcSecret: String = ""
    @AppStorage("rpcSSL") var rpcSSL: Bool = false
    @AppStorage("rpcListenAll") var rpcListenAll: Bool = false
    @AppStorage("rpcAllowOriginAll") var rpcAllowOriginAll: Bool = true

    // Engine / Advanced
    @AppStorage("aria2BinarySource") private var aria2BinarySourceRaw: String =
        Aria2BinarySource.bundled.rawValue
    @AppStorage("aria2StartOnLaunch") var aria2StartOnLaunch: Bool = true
    @AppStorage("customAria2Path") var customAria2Path: String = ""
    @AppStorage("maxOverallDownloadLimit") var maxOverallDownloadLimit: Int = 0  // 0 = unlimited
    @AppStorage("maxOverallUploadLimit") var maxOverallUploadLimit: Int = 0
    @AppStorage("minSplitSize") var minSplitSize: Int = 20
    @AppStorage("maxTries") var maxTries: Int = 5
    @AppStorage("retryWait") var retryWait: Int = 5
    @AppStorage("timeout") var timeout: Int = 60
    @AppStorage("connectTimeout") var connectTimeout: Int = 30
    @AppStorage("diskCache") var diskCache: Int = 16
    @AppStorage("saveSessionInterval") var saveSessionInterval: Int = 60
    @AppStorage("maxDownloadResult") var maxDownloadResult: Int = 1000
    @AppStorage("fileAllocation") var fileAllocation: String = "prealloc"
    @AppStorage("continueDownloads") var continueDownloads: Bool = true
    @AppStorage("autoFileRenaming") var autoFileRenaming: Bool = true
    @AppStorage("allowOverwrite") var allowOverwrite: Bool = false
    @AppStorage("checkCertificate") var checkCertificate: Bool = true
    @AppStorage("contentDispositionDefaultUTF8") var contentDispositionDefaultUTF8: Bool = true
    @AppStorage("userAgent") var userAgent: String = ""
    @AppStorage("referer") var referer: String = ""
    @AppStorage("extraAria2Arguments") var extraAria2Arguments: String = ""

    // Proxy
    @AppStorage("proxyEnabled") var proxyEnabled: Bool = false
    @AppStorage("proxyHost") var proxyHost: String = ""
    @AppStorage("proxyPort") var proxyPort: String = ""
    @AppStorage("proxyUser") var proxyUser: String = ""
    @AppStorage("proxyPass") var proxyPass: String = ""

    // BT Settings
    @AppStorage("trackerServers") var trackerServers: String = SettingsStore.defaultTrackers
    @AppStorage("btPort") var btPort: Int = 6881
    @AppStorage("dhtPort") var dhtPort: Int = 6882
    @AppStorage("upnpEnabled") var upnpEnabled: Bool = true
    @AppStorage("btSaveMetadata") var btSaveMetadata: Bool = false
    @AppStorage("btAutoStart") var btAutoStart: Bool = true
    @AppStorage("btForceEncryption") var btForceEncryption: Bool = false
    @AppStorage("btMaxPeers") var btMaxPeers: Int = 55
    @AppStorage("btRequestPeerSpeedLimit") var btRequestPeerSpeedLimit: Int = 50
    @AppStorage("seedRatio") var seedRatio: Double = 1.0
    @AppStorage("seedTime") var seedTime: Int = 0

    var aria2BinarySource: Aria2BinarySource {
        get { Aria2BinarySource(rawValue: aria2BinarySourceRaw) ?? .bundled }
        set { aria2BinarySourceRaw = newValue.rawValue }
    }

    // Tracker Source Management
    @AppStorage("selectedTrackerSourceURLs") private var selectedTrackerSourceURLsJSON: String = "[]"
    @AppStorage("customTrackerSourceURLs") private var customTrackerSourceURLsJSON: String = "[]"
    @AppStorage("autoSyncTracker") var autoSyncTracker: Bool = true
    @AppStorage("lastTrackerSyncTime") var lastTrackerSyncTime: Double = 0

    var selectedTrackerSourceURLs: [String] {
        get {
            let decoded = (try? JSONDecoder().decode([String].self, from: Data(selectedTrackerSourceURLsJSON.utf8))) ?? []
            return decoded.isEmpty ? TrackerPresets.defaultSelectedURLs : decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let json = String(data: data, encoding: .utf8) {
                selectedTrackerSourceURLsJSON = json
            }
        }
    }

    var customTrackerSourceURLs: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(customTrackerSourceURLsJSON.utf8))) ?? [] }
        set {
            if let data = try? JSONEncoder().encode(newValue), let json = String(data: data, encoding: .utf8) {
                customTrackerSourceURLsJSON = json
            }
        }
    }

    var lastTrackerSyncDate: Date? {
        lastTrackerSyncTime > 0 ? Date(timeIntervalSince1970: lastTrackerSyncTime) : nil
    }

    static let defaultTrackers = """
        http://tracker.files.fm:6969/announce
        http://tracker.gbitt.info:80/announce
        http://tracker.noobsubs.net:80/announce
        https://tracker.nanoha.org:443/announce
        http://tracker.bt4g.com:2095/announce
        udp://tracker.opentrackr.org:1337/announce
        udp://tracker.openbittorrent.com:6969/announce
        udp://exodus.desync.com:6969/announce
        udp://www.torrent.eu.org:451/announce
        udp://tracker.torrent.eu.org:451/announce
        udp://retracker.lanta-net.ru:2710/announce
        udp://open.stealth.si:80/announce
        udp://ipv4.tracker.harry.lu:80/announce
        udp://explodie.org:6969/announce
        """
}
