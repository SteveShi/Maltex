import XCTest
@testable import Maltex

/// 测试 DownloadTask 模型的解码和协议遵从
final class DownloadTaskTests: XCTestCase {

    // MARK: - JSON 解码测试

    func testDecodeBasicTask() throws {
        let json = """
        {
            "gid": "abc123",
            "status": "active",
            "totalLength": "1048576",
            "completedLength": "524288",
            "uploadLength": "0",
            "downloadSpeed": "102400",
            "uploadSpeed": "0",
            "connections": "5",
            "dir": "/tmp/downloads",
            "files": []
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)

        XCTAssertEqual(task.gid, "abc123")
        XCTAssertEqual(task.status, .active)
        XCTAssertEqual(task.totalLength, 1_048_576)
        XCTAssertEqual(task.completedLength, 524_288)
        XCTAssertEqual(task.downloadSpeed, 102_400)
        XCTAssertEqual(task.connections, 5)
        XCTAssertEqual(task.dir, "/tmp/downloads")
        XCTAssertTrue(task.files.isEmpty)
        XCTAssertNil(task.bittorrent)
    }

    func testDecodeTaskWithStringNumbers() throws {
        // aria2 RPC 返回的数字都是字符串格式
        let json = """
        {
            "gid": "def456",
            "status": "complete",
            "totalLength": "2097152",
            "completedLength": "2097152",
            "uploadLength": "1024",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "dir": "/Users/test/Downloads",
            "files": [{
                "index": "1",
                "path": "/Users/test/Downloads/file.zip",
                "length": "2097152",
                "completedLength": "2097152",
                "selected": "true",
                "uris": [{"uri": "https://example.com/file.zip", "status": "used"}]
            }]
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)

        XCTAssertEqual(task.status, .complete)
        XCTAssertEqual(task.totalLength, 2_097_152)
        XCTAssertEqual(task.completedLength, 2_097_152)
        XCTAssertEqual(task.files.count, 1)
        XCTAssertEqual(task.files.first?.path, "/Users/test/Downloads/file.zip")
        XCTAssertEqual(task.files.first?.length, 2_097_152)
    }

    func testDecodeTaskWithBittorrentInfo() throws {
        let json = """
        {
            "gid": "bt789",
            "status": "paused",
            "totalLength": "5242880",
            "completedLength": "0",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "dir": "/tmp",
            "files": [{
                "index": "1",
                "path": "/tmp/movie.mkv",
                "length": "5242880",
                "completedLength": "0",
                "selected": "true",
                "uris": []
            }],
            "bittorrent": {
                "announceList": [["http://tracker.example.com:6969/announce"]],
                "comment": "Test torrent",
                "creationDate": 1700000000,
                "mode": "single",
                "info": {
                    "name": "Test Movie"
                }
            },
            "infoHash": "aabbccdd"
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)

        XCTAssertEqual(task.gid, "bt789")
        XCTAssertEqual(task.status, .paused)
        XCTAssertNotNil(task.bittorrent)
        XCTAssertEqual(task.bittorrent?.info?.name, "Test Movie")
        XCTAssertEqual(task.bittorrent?.comment, "Test torrent")
        XCTAssertEqual(task.infoHash, "aabbccdd")
    }

    func testDecodeSeedingTaskAsDownloadComplete() throws {
        let json = """
        {
            "gid": "seed001",
            "status": "active",
            "totalLength": "5242880",
            "completedLength": "5242880",
            "uploadLength": "1048576",
            "downloadSpeed": "0",
            "uploadSpeed": "65536",
            "connections": "3",
            "seeder": "true",
            "dir": "/tmp",
            "files": [{
                "index": "1",
                "path": "/tmp/movie.mkv",
                "length": "5242880",
                "completedLength": "5242880",
                "selected": "true",
                "uris": []
            }],
            "bittorrent": {
                "info": {
                    "name": "Test Movie"
                }
            }
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)

        XCTAssertTrue(task.seeder)
        XCTAssertTrue(task.isSeeding)
        XCTAssertTrue(task.isDownloadComplete)
        XCTAssertNil(task.remainingSeconds)
        XCTAssertEqual(task.localizedDisplayStatusName, String(localized: "正在上传"))
    }

    func testCompletedBittorrentActiveTaskIsSeedingEvenWithoutSeederField() throws {
        let json = """
        {
            "gid": "seed002",
            "status": "active",
            "totalLength": "1024",
            "completedLength": "1024",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "1",
            "dir": "/tmp",
            "files": [],
            "bittorrent": {
                "info": {
                    "name": "Finished Payload"
                }
            }
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)

        XCTAssertFalse(task.seeder)
        XCTAssertTrue(task.isSeeding)
        XCTAssertTrue(task.isDownloadComplete)
    }

    func testDecodeAllStatuses() throws {
        let statuses = ["active", "waiting", "paused", "error", "complete", "removed"]
        let expected: [DownloadTask.TaskStatus] = [.active, .waiting, .paused, .error, .complete, .removed]

        for (statusStr, expectedStatus) in zip(statuses, expected) {
            let json = """
            {
                "gid": "gid_\(statusStr)",
                "status": "\(statusStr)",
                "totalLength": "0",
                "completedLength": "0",
                "uploadLength": "0",
                "downloadSpeed": "0",
                "uploadSpeed": "0",
                "connections": "0",
                "dir": "/tmp",
                "files": []
            }
            """.data(using: .utf8)!

            let task = try JSONDecoder().decode(DownloadTask.self, from: json)
            XCTAssertEqual(task.status, expectedStatus, "Failed for status: \(statusStr)")
        }
    }

    func testDecodeTaskWithOptionalFields() throws {
        let json = """
        {
            "gid": "opt001",
            "status": "error",
            "totalLength": "0",
            "completedLength": "0",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "errorCode": "22",
            "followedBy": "gid_followed",
            "belongsTo": "gid_parent",
            "numSeeders": 5,
            "dir": "/tmp",
            "files": []
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)

        XCTAssertEqual(task.errorCode, "22")
        XCTAssertEqual(task.followedBy, ["gid_followed"])
        XCTAssertEqual(task.belongsTo, "gid_parent")
    }

    func testDecodeFollowedByArray() throws {
        let json = """
        {
            "gid": "meta001",
            "status": "complete",
            "totalLength": "0",
            "completedLength": "0",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "followedBy": ["gid_real_task_1", "gid_real_task_2"],
            "dir": "/tmp",
            "files": []
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DownloadTask.self, from: json)
        XCTAssertEqual(task.followedBy, ["gid_real_task_1", "gid_real_task_2"])
    }

    func testDuplicateDownloadInfoCanAutoRedownload() {
        let magnetInfo = DuplicateDownloadInfo(
            uri: "magnet:?xt=urn:btih:c12fe1c06bba254a9dc9f519b335380dc1f7fed4&dn=Test",
            options: [:],
            torrentBase64: nil
        )
        XCTAssertTrue(magnetInfo.canAutoRedownload)

        let torrentInfo = DuplicateDownloadInfo(
            uri: "",
            options: [:],
            torrentBase64: "dGVzdA=="
        )
        XCTAssertFalse(torrentInfo.canAutoRedownload)

        let httpInfo = DuplicateDownloadInfo(
            uri: "https://example.com/file.zip",
            options: [:],
            torrentBase64: nil
        )
        XCTAssertFalse(httpInfo.canAutoRedownload)
    }

    func testTaskErrorMessageAndLocalizedDescription() throws {
        let jsonWithMsg = """
        {
            "gid": "err001",
            "status": "error",
            "totalLength": "0",
            "completedLength": "0",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "errorCode": "3",
            "errorMessage": "Resource not found",
            "dir": "/tmp",
            "files": []
        }
        """.data(using: .utf8)!

        let taskWithMsg = try JSONDecoder().decode(DownloadTask.self, from: jsonWithMsg)
        XCTAssertEqual(taskWithMsg.errorMessage, "Resource not found")
        XCTAssertEqual(taskWithMsg.localizedErrorDescription, "Resource not found")

        let jsonWithCodeOnly = """
        {
            "gid": "err002",
            "status": "error",
            "totalLength": "0",
            "completedLength": "0",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "errorCode": "9",
            "dir": "/tmp",
            "files": []
        }
        """.data(using: .utf8)!

        let taskWithCodeOnly = try JSONDecoder().decode(DownloadTask.self, from: jsonWithCodeOnly)
        XCTAssertNil(taskWithCodeOnly.errorMessage)
        XCTAssertEqual(taskWithCodeOnly.localizedErrorDescription, "错误代码: 9")
    }

    // MARK: - Identifiable / Hashable 测试

    func testIdentifiable() throws {
        let json = makeMinimalTaskJSON(gid: "test_id_123")
        let task = try JSONDecoder().decode(DownloadTask.self, from: json)
        XCTAssertEqual(task.id, "test_id_123")
    }

    func testHashableEquality() throws {
        let task1 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "same_gid", status: "active"))
        let task2 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "same_gid", status: "complete"))

        // Different data fields (status) mean they are not equal under ==
        XCTAssertNotEqual(task1, task2)
        // But since hash is based solely on gid, their hashValues are still equal
        XCTAssertEqual(task1.hashValue, task2.hashValue)
    }

    func testHashableInequality() throws {
        let task1 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "gid_a"))
        let task2 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "gid_b"))

        XCTAssertNotEqual(task1, task2)
    }

    func testSetMembership() throws {
        let task1 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "gid_1"))
        let task2 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "gid_2"))
        let task3 = try JSONDecoder().decode(DownloadTask.self, from: makeMinimalTaskJSON(gid: "gid_1"))

        var set = Set<DownloadTask>()
        set.insert(task1)
        set.insert(task2)
        set.insert(task3) // duplicate of task1

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - TaskStatus 本地化测试

    func testStatusLocalizedNames() {
        XCTAssertFalse(DownloadTask.TaskStatus.active.localizedName.isEmpty)
        XCTAssertFalse(DownloadTask.TaskStatus.waiting.localizedName.isEmpty)
        XCTAssertFalse(DownloadTask.TaskStatus.paused.localizedName.isEmpty)
        XCTAssertFalse(DownloadTask.TaskStatus.error.localizedName.isEmpty)
        XCTAssertFalse(DownloadTask.TaskStatus.complete.localizedName.isEmpty)
        XCTAssertFalse(DownloadTask.TaskStatus.removed.localizedName.isEmpty)
    }

    // MARK: - Helpers

    private func makeMinimalTaskJSON(gid: String, status: String = "active") -> Data {
        """
        {
            "gid": "\(gid)",
            "status": "\(status)",
            "totalLength": "0",
            "completedLength": "0",
            "uploadLength": "0",
            "downloadSpeed": "0",
            "uploadSpeed": "0",
            "connections": "0",
            "dir": "/tmp",
            "files": []
        }
        """.data(using: .utf8)!
    }
}
