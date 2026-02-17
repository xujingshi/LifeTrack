import Foundation

// MARK: - 打卡项模型
struct CheckInItem: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let scheduledTime: String?
    let icon: String?
    let color: String?
    let remind: Bool
    let repeatType: Int
    let repeatDays: String?
    let intervalDays: Int
    let checkType: Int?       // 打卡类型: 0=默认打卡, 1=记录模式
    let contentType: Int?     // 记录模式下: 0=字符串, 1=数字
    let allowImage: Bool?     // 记录模式下是否允许图片
    let valueUnit: String?    // 数值单位（当 contentType=1 时使用）
    let isActive: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case scheduledTime = "scheduled_time"
        case icon
        case color
        case remind
        case repeatType = "repeat_type"
        case repeatDays = "repeat_days"
        case intervalDays = "interval_days"
        case checkType = "check_type"
        case contentType = "content_type"
        case allowImage = "allow_image"
        case valueUnit = "value_unit"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    var repeatTypeEnum: RepeatType {
        RepeatType(rawValue: repeatType) ?? .daily
    }

    var checkTypeEnum: CheckType {
        CheckType(rawValue: checkType ?? 0) ?? .normal
    }

    var contentTypeEnum: ContentType {
        ContentType(rawValue: contentType ?? 0) ?? .text
    }

    // 是否为自由打卡类型（不需要每天打卡）
    var isFreeType: Bool {
        repeatTypeEnum == .free
    }

    // 是否为记录模式
    var isRecordMode: Bool {
        checkTypeEnum == .record
    }

    // 是否需要数值输入
    var needsNumberInput: Bool {
        isRecordMode && contentTypeEnum == .number
    }

    // 是否需要文本输入
    var needsTextInput: Bool {
        isRecordMode && contentTypeEnum == .text
    }

    // 是否允许添加图片
    var canAddImage: Bool {
        isRecordMode && (allowImage ?? false)
    }
}

enum RepeatType: Int, CaseIterable {
    case daily = 0
    case weekday = 1
    case weekend = 2
    case custom = 3
    case interval = 4
    case free = 5  // 自由打卡（不定时记录，如体重）

    var title: String {
        switch self {
        case .daily: return "每天"
        case .weekday: return "工作日"
        case .weekend: return "周末"
        case .custom: return "自定义"
        case .interval: return "间隔天数"
        case .free: return "自由记录"
        }
    }

    var description: String {
        switch self {
        case .daily: return "每天都需要打卡"
        case .weekday: return "周一至周五需要打卡"
        case .weekend: return "周六周日需要打卡"
        case .custom: return "自定义每周的打卡日"
        case .interval: return "每隔N天打卡一次"
        case .free: return "不定时记录，无需每天打卡"
        }
    }
}

// MARK: - 打卡类型
enum CheckType: Int, CaseIterable {
    case normal = 0      // 默认打卡（点击即完成）
    case record = 1      // 记录模式

    var title: String {
        switch self {
        case .normal: return "默认打卡"
        case .record: return "记录模式"
        }
    }

    var description: String {
        switch self {
        case .normal: return "点击即可完成打卡"
        case .record: return "可记录文案/数值和图片"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "checkmark.circle"
        case .record: return "square.and.pencil"
        }
    }
}

// MARK: - 内容类型（记录模式下）
enum ContentType: Int, CaseIterable {
    case text = 0    // 字符串文案
    case number = 1  // 数字

    var title: String {
        switch self {
        case .text: return "文字"
        case .number: return "数字"
        }
    }

    var description: String {
        switch self {
        case .text: return "输入文字内容"
        case .number: return "输入数值"
        }
    }
}

// MARK: - 打卡记录模型
struct CheckInRecord: Codable, Identifiable {
    let id: Int
    let itemId: Int
    let userId: Int
    let checkDate: String
    let checkedAt: String?
    let note: String?
    let imageUrl: String?    // 图片URL（当 checkType=1 时使用）
    let value: Double?       // 数值（当 checkType=2 时使用，如体重69.5）
    let item: CheckInItem?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case userId = "user_id"
        case checkDate = "check_date"
        case checkedAt = "checked_at"
        case note
        case imageUrl = "image_url"
        case value
        case item
    }
}

// MARK: - 日历状态
struct CalendarDayStatus: Codable {
    let date: String
    let completed: Bool
    let note: String?
}

// MARK: - 打卡统计
struct CheckInStatistics: Codable {
    let totalItems: Int
    let todayCompleted: Int
    let todayTotal: Int
    let weekStreak: Int?
    let monthlyStats: [MonthlyStatItem]?

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case todayCompleted = "today_completed"
        case todayTotal = "today_total"
        case weekStreak = "week_streak"
        case monthlyStats = "monthly_stats"
    }
}

struct MonthlyStatItem: Codable {
    let itemId: Int
    let itemName: String
    let total: Int
    let done: Int
    let rate: Double

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case itemName = "item_name"
        case total
        case done
        case rate
    }
}

// MARK: - 请求模型
struct CreateCheckInItemRequest: Codable {
    let name: String
    let scheduledTime: String?
    let icon: String?
    let color: String?
    let remind: Bool
    let repeatType: Int
    let repeatDays: String?
    let intervalDays: Int?
    let checkType: Int?
    let contentType: Int?
    let allowImage: Bool?
    let valueUnit: String?

    enum CodingKeys: String, CodingKey {
        case name
        case scheduledTime = "scheduled_time"
        case icon
        case color
        case remind
        case repeatType = "repeat_type"
        case repeatDays = "repeat_days"
        case intervalDays = "interval_days"
        case checkType = "check_type"
        case contentType = "content_type"
        case allowImage = "allow_image"
        case valueUnit = "value_unit"
    }
}

struct CreateCheckInRecordRequest: Codable {
    let itemId: Int
    let checkDate: String
    let note: String?
    let imageUrl: String?
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case checkDate = "check_date"
        case note
        case imageUrl = "image_url"
        case value
    }
}

// MARK: - 单个打卡项日历数据
struct ItemCalendarData: Codable {
    let completedDates: [String]
    let currentStreak: Int
    let longestStreak: Int

    enum CodingKeys: String, CodingKey {
        case completedDates = "completed_dates"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
    }
}

// MARK: - 图片上传响应
struct CheckInImageResponse: Codable {
    let imageUrl: String

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
    }
}

// MARK: - 详细统计数据
struct DetailedStatistics: Codable {
    let period: String
    let trendData: [TrendDataPoint]
    let totalDays: Int
    let completedDays: Int
    let completionRate: Double
    let currentStreak: Int
    let longestStreak: Int
    let bestDay: String
    let avgValue: Double?
    let maxValue: Double?
    let minValue: Double?

    enum CodingKeys: String, CodingKey {
        case period
        case trendData = "trend_data"
        case totalDays = "total_days"
        case completedDays = "completed_days"
        case completionRate = "completion_rate"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case bestDay = "best_day"
        case avgValue = "avg_value"
        case maxValue = "max_value"
        case minValue = "min_value"
    }
}

// MARK: - 趋势数据点
struct TrendDataPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let completed: Int
    let total: Int
    let value: Double?
}

// MARK: - 综合统计数据
struct OverallStatistics: Codable {
    let totalCheckIns: Int        // 总打卡次数
    let activeDays: Int           // 活跃天数
    let completionRate: Double    // 平均完成率
    let currentStreak: Int        // 当前连续天数
    let longestStreak: Int        // 最长连续天数
    let bestWeekday: Int          // 最佳打卡日 (0=周日, 1=周一, ...)
    let weekdayDistribution: [Int] // 每周各天打卡次数 [周日, 周一, ..., 周六]
    let trendData: [DailyTrend]   // 趋势数据
    let itemRankings: [ItemRanking] // 打卡项排行

    enum CodingKeys: String, CodingKey {
        case totalCheckIns = "total_check_ins"
        case activeDays = "active_days"
        case completionRate = "completion_rate"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case bestWeekday = "best_weekday"
        case weekdayDistribution = "weekday_distribution"
        case trendData = "trend_data"
        case itemRankings = "item_rankings"
    }
}

// MARK: - 每日趋势数据
struct DailyTrend: Codable, Identifiable {
    var id: String { date }
    let date: String
    let completed: Int
    let total: Int

    // 显示用的日期格式
    var displayDate: String {
        let dateOnly = String(date.prefix(10))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: dateOnly) else { return dateOnly }
        formatter.dateFormat = "M/d"
        return formatter.string(from: d)
    }
}

// MARK: - 打卡项排行
struct ItemRanking: Codable {
    let itemId: Int
    let itemName: String
    let completedCount: Int
    let totalCount: Int
    let completionRate: Double

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case itemName = "item_name"
        case completedCount = "completed_count"
        case totalCount = "total_count"
        case completionRate = "completion_rate"
    }
}
