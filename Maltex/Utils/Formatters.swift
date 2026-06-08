import Foundation

struct ByteCountFormatterUtil {
    static func string(fromByteCount count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: count)
    }
}

/// 将秒数格式化为本地化的剩余时长（如 "1分20秒"），单位随系统语言变化。
struct DurationFormatterUtil {
    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    static func string(fromSeconds seconds: Int64) -> String {
        formatter.string(from: TimeInterval(seconds)) ?? ""
    }
}

/// 本地化的日期时间字符串（用于任务添加时间等展示）。
struct DateTimeFormatterUtil {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
