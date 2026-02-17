import Foundation

// MARK: - 日期工具类
enum DateUtils {

    // MARK: - 日期格式化器（缓存以提高性能）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    private static let posixFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - 支持的日期格式
    private static let dateFormats = [
        "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ",  // 带微秒和时区
        "yyyy-MM-dd HH:mm:ss.SSSSSS",        // 带微秒
        "yyyy-MM-dd HH:mm:ssZZZZZ",          // 带时区
        "yyyy-MM-dd HH:mm:ss",               // 标准格式
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ", // ISO格式带微秒和时区
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",      // ISO格式带微秒
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",        // ISO格式带时区
        "yyyy-MM-dd'T'HH:mm:ss",             // ISO格式
        "yyyy-MM-dd"                          // 仅日期
    ]

    // MARK: - 解析日期字符串
    /// 尝试多种格式解析日期字符串
    static func parse(_ dateString: String) -> Date? {
        for format in dateFormats {
            posixFormatter.dateFormat = format
            if let date = posixFormatter.date(from: dateString) {
                return date
            }
        }

        // 尝试只取前10个字符（日期部分）
        let dateOnly = String(dateString.prefix(10))
        posixFormatter.dateFormat = "yyyy-MM-dd"
        return posixFormatter.date(from: dateOnly)
    }

    // MARK: - 相对日期格式化
    /// 格式化为相对日期（今天、昨天、M月d日、yyyy年M月d日）
    static func relativeFormat(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            dateFormatter.dateFormat = "M月d日"
            return dateFormatter.string(from: date)
        } else {
            dateFormatter.dateFormat = "yyyy年M月d日"
            return dateFormatter.string(from: date)
        }
    }

    /// 格式化日期字符串为相对日期
    static func relativeFormat(_ dateString: String) -> String {
        guard let date = parse(dateString) else {
            return dateString
        }
        return relativeFormat(date)
    }

    // MARK: - 相对时间格式化
    /// 格式化为相对时间（今天 HH:mm、昨天 HH:mm、M/d HH:mm）
    static func relativeTimeFormat(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            dateFormatter.dateFormat = "HH:mm"
            return dateFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            dateFormatter.dateFormat = "HH:mm"
            return "昨天 " + dateFormatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            dateFormatter.dateFormat = "M/d HH:mm"
            return dateFormatter.string(from: date)
        } else {
            dateFormatter.dateFormat = "yy/M/d HH:mm"
            return dateFormatter.string(from: date)
        }
    }

    /// 格式化时间字符串为相对时间
    static func relativeTimeFormat(_ dateString: String) -> String {
        guard let date = parse(dateString) else {
            return dateString
        }
        return relativeTimeFormat(date)
    }

    // MARK: - 格式化为日期字符串
    /// 格式化 Date 为 yyyy-MM-dd 字符串
    static func formatDate(_ date: Date) -> String {
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }

    /// 格式化 Date 为完整日期字符串（M月d日 EEEE）
    static func formatFullDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            dateFormatter.dateFormat = "M月d日 EEEE"
            return dateFormatter.string(from: date)
        } else {
            dateFormatter.dateFormat = "yyyy年M月d日"
            return dateFormatter.string(from: date)
        }
    }

    // MARK: - 今天的日期字符串
    static var todayString: String {
        formatDate(Date())
    }
}

// MARK: - String 扩展
extension String {
    /// 解析为日期
    var toDate: Date? {
        DateUtils.parse(self)
    }

    /// 格式化为相对日期
    var relativeDate: String {
        DateUtils.relativeFormat(self)
    }

    /// 格式化为相对时间
    var relativeTime: String {
        DateUtils.relativeTimeFormat(self)
    }
}

// MARK: - Date 扩展
extension Date {
    /// 格式化为 yyyy-MM-dd
    var dateString: String {
        DateUtils.formatDate(self)
    }

    /// 格式化为相对日期
    var relativeDate: String {
        DateUtils.relativeFormat(self)
    }

    /// 格式化为相对时间
    var relativeTime: String {
        DateUtils.relativeTimeFormat(self)
    }

    /// 格式化为完整日期
    var fullDate: String {
        DateUtils.formatFullDate(self)
    }
}
