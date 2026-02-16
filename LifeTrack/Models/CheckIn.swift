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
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    var repeatTypeEnum: RepeatType {
        RepeatType(rawValue: repeatType) ?? .daily
    }
}

enum RepeatType: Int, CaseIterable {
    case daily = 0
    case weekday = 1
    case weekend = 2
    case custom = 3
    case interval = 4

    var title: String {
        switch self {
        case .daily: return "每天"
        case .weekday: return "工作日"
        case .weekend: return "周末"
        case .custom: return "自定义"
        case .interval: return "间隔天数"
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
    let item: CheckInItem?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case userId = "user_id"
        case checkDate = "check_date"
        case checkedAt = "checked_at"
        case note
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

    enum CodingKeys: String, CodingKey {
        case name
        case scheduledTime = "scheduled_time"
        case icon
        case color
        case remind
        case repeatType = "repeat_type"
        case repeatDays = "repeat_days"
        case intervalDays = "interval_days"
    }
}

struct CreateCheckInRecordRequest: Codable {
    let itemId: Int
    let checkDate: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case checkDate = "check_date"
        case note
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
