import Foundation

// MARK: - 快速笔记模型（咻）
struct QuickNote: Codable, Identifiable {
    let id: Int
    let userId: Int
    let content: String
    let isVoice: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case content
        case isVoice = "is_voice"
        case createdAt = "created_at"
    }

    // 格式化时间显示
    var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "zh_CN")

            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                displayFormatter.dateFormat = "HH:mm"
                return "今天 " + displayFormatter.string(from: date)
            } else if calendar.isDateInYesterday(date) {
                displayFormatter.dateFormat = "HH:mm"
                return "昨天 " + displayFormatter.string(from: date)
            } else {
                displayFormatter.dateFormat = "MM月dd日 HH:mm"
                return displayFormatter.string(from: date)
            }
        }
        return createdAt
    }
}

// MARK: - 请求模型
struct CreateQuickNoteRequest: Codable {
    let content: String
    let isVoice: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case isVoice = "is_voice"
    }
}

struct UpdateQuickNoteRequest: Codable {
    let content: String
}

// MARK: - 响应模型
struct QuickNoteListResponse: Codable {
    let list: [QuickNote]
    let total: Int
    let page: Int
}
