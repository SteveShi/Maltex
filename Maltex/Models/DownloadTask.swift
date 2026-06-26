import Foundation

struct DownloadTask: Identifiable, Codable, Hashable {
    var gid: String
    var status: TaskStatus
    var totalLength: Int64
    var completedLength: Int64
    var uploadLength: Int64
    var downloadSpeed: Int64
    var uploadSpeed: Int64
    var infoHash: String?
    var numSeeders: Int?
    var connections: Int
    var seeder: Bool
    var errorCode: String?
    var followedBy: String?
    var belongsTo: String?
    var dir: String
    var files: [DownloadFile]
    var bittorrent: BittorrentInfo?
    var ed2k: Ed2kInfo?

    // 由 TaskStore 在合并时注入，不参与 RPC 解码与历史持久化。
    var addedDate: Date?
    var completedDate: Date?

    var id: String { gid }

    /// 预计剩余下载时间（秒）；仅在下载中且速度有效时可用。
    var remainingSeconds: Int64? {
        guard status == .active, !hasFinishedDownloading, downloadSpeed > 0, totalLength > 0 else { return nil }
        let remaining = totalLength - completedLength
        guard remaining > 0 else { return nil }
        return remaining / downloadSpeed
    }

    /// 文件内容是否已经下载完成。BT 任务在做种阶段仍可能保持 active。
    var hasFinishedDownloading: Bool {
        totalLength > 0 && completedLength >= totalLength
    }

    /// BT 下载完成后仍处于 active 的做种/上传阶段。
    var isSeeding: Bool {
        bittorrent != nil && status == .active && (seeder || hasFinishedDownloading)
    }

    /// 用户视角的下载完成：做种中的 BT 任务也已经完成下载。
    var isDownloadComplete: Bool {
        status == .complete || isSeeding
    }

    var localizedDisplayStatusName: String {
        isSeeding ? String(localized: "正在上传") : status.localizedName
    }

    /// 可分享链接：优先用 aria2-next 2.4.4+ 提供的字段，BT 任务可由 infoHash 兜底构造磁力链接。
    var shareLink: String? {
        if let magnet = bittorrent?.magnetLink, !magnet.isEmpty { return magnet }
        if let link = ed2k?.ed2kLink, !link.isEmpty { return link }
        if bittorrent != nil, let hash = infoHash, !hash.isEmpty {
            return "magnet:?xt=urn:btih:\(hash)"
        }
        return nil
    }

    /// 直链下载源地址（HTTP/FTP 等），去重，用于"复制下载链接"。
    var downloadURLs: [String] {
        let directSchemes: Set<String> = ["http", "https", "ftp", "ftps", "sftp"]
        var seen = Set<String>()
        var result: [String] = []
        for file in files {
            for entry in file.uris {
                let uri = entry.uri
                guard !uri.isEmpty, !seen.contains(uri),
                    let scheme = URL(string: uri)?.scheme?.lowercased(),
                    directSchemes.contains(scheme)
                else { continue }
                seen.insert(uri)
                result.append(uri)
            }
        }
        return result
    }

    // Hashable/Equatable based on gid and key progress fields to ensure UI refresh
    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.gid == rhs.gid &&
        lhs.status == rhs.status &&
        lhs.totalLength == rhs.totalLength &&
        lhs.completedLength == rhs.completedLength &&
        lhs.downloadSpeed == rhs.downloadSpeed &&
        lhs.uploadSpeed == rhs.uploadSpeed &&
        lhs.numSeeders == rhs.numSeeders &&
        lhs.seeder == rhs.seeder &&
        lhs.files.count == rhs.files.count &&
        lhs.bittorrent?.info?.name == rhs.bittorrent?.info?.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(gid)
    }

    enum CodingKeys: String, CodingKey {
        case gid, status, totalLength, completedLength, uploadLength
        case downloadSpeed, uploadSpeed, infoHash, numSeeders, connections
        case seeder, errorCode, followedBy, belongsTo, dir, files, bittorrent, ed2k
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gid = try container.decode(String.self, forKey: .gid)
        status = try container.decode(TaskStatus.self, forKey: .status)

        // Helper to decode string as Int64
        func decodeInt64(_ key: CodingKeys) -> Int64 {
            if let str = try? container.decode(String.self, forKey: key) {
                return Int64(str) ?? 0
            }
            return (try? container.decode(Int64.self, forKey: key)) ?? 0
        }

        func decodeInt(_ key: CodingKeys) -> Int {
            if let str = try? container.decode(String.self, forKey: key) {
                return Int(str) ?? 0
            }
            return (try? container.decode(Int.self, forKey: key)) ?? 0
        }

        totalLength = decodeInt64(.totalLength)
        completedLength = decodeInt64(.completedLength)
        uploadLength = decodeInt64(.uploadLength)
        downloadSpeed = decodeInt64(.downloadSpeed)
        uploadSpeed = decodeInt64(.uploadSpeed)
        connections = decodeInt(.connections)
        seeder = Self.decodeBool(from: container, forKey: .seeder)

        infoHash = try container.decodeIfPresent(String.self, forKey: .infoHash)
        if let seedersStr = try? container.decode(String.self, forKey: .numSeeders) {
            numSeeders = Int(seedersStr)
        } else {
            numSeeders = try? container.decode(Int.self, forKey: .numSeeders)
        }
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        followedBy = try container.decodeIfPresent(String.self, forKey: .followedBy)
        belongsTo = try container.decodeIfPresent(String.self, forKey: .belongsTo)
        dir = try container.decode(String.self, forKey: .dir)
        files = try container.decode([DownloadFile].self, forKey: .files)
        bittorrent = try container.decodeIfPresent(BittorrentInfo.self, forKey: .bittorrent)
        ed2k = try container.decodeIfPresent(Ed2kInfo.self, forKey: .ed2k)
    }

    private static func decodeBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }
        if let string = try? container.decode(String.self, forKey: key) {
            return string.lowercased() == "true"
        }
        return false
    }

    enum TaskStatus: String, Codable {
        case active
        case waiting
        case paused
        case error
        case complete
        case removed

        var localizedName: String {
            switch self {
            case .active: return String(localized: "正在下载")
            case .waiting: return String(localized: "等待下载")
            case .paused: return String(localized: "已暂停")
            case .error: return String(localized: "错误")
            case .complete: return String(localized: "已完成")
            case .removed: return String(localized: "已移除")
            }
        }
    }
}

struct DownloadFile: Codable, Hashable {
    let index: String
    let path: String
    let length: Int64
    let completedLength: Int64
    let selected: String
    let uris: [DownloadURI]

    enum CodingKeys: String, CodingKey {
        case index, path, length, completedLength, selected, uris
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(String.self, forKey: .index)
        path = try container.decode(String.self, forKey: .path)
        selected = try container.decode(String.self, forKey: .selected)
        uris = try container.decode([DownloadURI].self, forKey: .uris)

        if let lengthStr = try? container.decode(String.self, forKey: .length) {
            length = Int64(lengthStr) ?? 0
        } else {
            length = try container.decode(Int64.self, forKey: .length)
        }

        if let compStr = try? container.decode(String.self, forKey: .completedLength) {
            completedLength = Int64(compStr) ?? 0
        } else {
            completedLength = try container.decode(Int64.self, forKey: .completedLength)
        }
    }
}

struct DownloadURI: Codable, Hashable {
    let uri: String
    let status: String
}

struct BittorrentInfo: Codable, Hashable {
    let announceList: [[String]]?
    let comment: String?
    let creationDate: Int64?
    let mode: String?
    let info: BittorrentDetail?
    // aria2-next 2.4.4+ 在任务状态中提供
    let magnetLink: String?
}

struct Ed2kInfo: Codable, Hashable {
    // aria2-next 2.4.4+ 在 ED2K 任务状态中提供
    let ed2kLink: String?
}

struct BittorrentDetail: Codable, Hashable {
    let name: String?
}
