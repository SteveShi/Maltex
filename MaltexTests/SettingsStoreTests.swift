import XCTest
@testable import Maltex

/// 测试 SettingsStore 默认值
final class SettingsStoreTests: XCTestCase {

    func testDefaultValues() {
        let settings = SettingsStore()

        XCTAssertEqual(settings.maxConcurrentDownloads, 5)
        XCTAssertEqual(settings.maxConnectionPerServer, 16)
        XCTAssertFalse(settings.downloadPath.isEmpty, "默认下载路径不应为空")
        XCTAssertEqual(settings.rpcPort, 16800)
        XCTAssertEqual(settings.rpcSecret, "")
        XCTAssertEqual(settings.rpcHost, "127.0.0.1")
        XCTAssertEqual(settings.aria2BinarySource, .bundled)
        XCTAssertTrue(settings.aria2StartOnLaunch)
        XCTAssertEqual(settings.maxOverallDownloadLimit, 0)
        XCTAssertEqual(settings.maxOverallUploadLimit, 0)
        XCTAssertFalse(settings.proxyEnabled)
        XCTAssertTrue(settings.notificationEnabled)
    }

    func testDefaultTrackers() {
        XCTAssertFalse(SettingsStore.defaultTrackers.isEmpty)
        // 确保默认 tracker 列表包含多个条目
        let trackers = SettingsStore.defaultTrackers.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        XCTAssertGreaterThan(trackers.count, 5, "应包含多个默认 tracker")
    }

    func testBTDefaults() {
        let settings = SettingsStore()

        XCTAssertEqual(settings.btPort, 6881)
        XCTAssertEqual(settings.dhtPort, 6882)
        XCTAssertTrue(settings.upnpEnabled)
        XCTAssertFalse(settings.btSaveMetadata)
        XCTAssertTrue(settings.btAutoStart)
        XCTAssertFalse(settings.btForceEncryption)
    }

    func testAria2AdvancedDefaults() {
        let settings = SettingsStore()

        XCTAssertEqual(settings.minSplitSize, 20)
        XCTAssertEqual(settings.maxTries, 5)
        XCTAssertEqual(settings.retryWait, 5)
        XCTAssertEqual(settings.timeout, 60)
        XCTAssertEqual(settings.connectTimeout, 30)
        XCTAssertEqual(settings.diskCache, 16)
        XCTAssertEqual(settings.fileAllocation, "prealloc")
        XCTAssertTrue(settings.continueDownloads)
        XCTAssertTrue(settings.autoFileRenaming)
        XCTAssertTrue(settings.checkCertificate)
        XCTAssertFalse(settings.allowOverwrite)
    }
}
