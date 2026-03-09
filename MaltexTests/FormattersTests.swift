import XCTest
@testable import Maltex

/// 测试 ByteCountFormatterUtil 格式化工具
final class FormattersTests: XCTestCase {

    func testFormatZeroBytes() {
        let result = ByteCountFormatterUtil.string(fromByteCount: 0)
        // 结果依赖系统 locale（例如 "Zero KB" 或 "0字节"），确保有合理输出即可
        XCTAssertFalse(result.isEmpty, "零字节格式化结果不应为空")
    }

    func testFormatKilobytes() {
        let result = ByteCountFormatterUtil.string(fromByteCount: 1024)
        XCTAssertTrue(result.contains("1"), "Expected '1' in result: \(result)")
        XCTAssertTrue(result.contains("KB"), "Expected 'KB' in result: \(result)")
    }

    func testFormatMegabytes() {
        let result = ByteCountFormatterUtil.string(fromByteCount: 1_048_576)
        XCTAssertTrue(result.contains("1"), "Expected '1' in result: \(result)")
        XCTAssertTrue(result.contains("MB"), "Expected 'MB' in result: \(result)")
    }

    func testFormatGigabytes() {
        let result = ByteCountFormatterUtil.string(fromByteCount: 1_073_741_824)
        XCTAssertTrue(result.contains("1"), "Expected '1' in result: \(result)")
        XCTAssertTrue(result.contains("GB"), "Expected 'GB' in result: \(result)")
    }

    func testFormatLargeFile() {
        // 4.7 GB
        let result = ByteCountFormatterUtil.string(fromByteCount: 5_046_586_573)
        XCTAssertTrue(result.contains("GB"), "Expected 'GB' in result: \(result)")
    }
}
