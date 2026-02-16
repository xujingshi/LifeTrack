import Foundation

// MARK: - 规划模型
struct Plan: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    let dueDate: String?
    let priority: Int
    let status: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case dueDate = "due_date"
        case priority
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // 优先级枚举
    var priorityLevel: PlanPriority {
        PlanPriority(rawValue: priority) ?? .low
    }

    // 状态枚举
    var statusLevel: PlanStatus {
        PlanStatus(rawValue: status) ?? .todo
    }
}

enum PlanPriority: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

enum PlanStatus: Int, CaseIterable {
    case todo = 0
    case inProgress = 1
    case done = 2

    var title: String {
        switch self {
        case .todo: return "待办"
        case .inProgress: return "进行中"
        case .done: return "已完成"
        }
    }

    var icon: String {
        switch self {
        case .todo: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }
}

// MARK: - 请求模型
struct CreatePlanRequest: Codable {
    let title: String
    let description: String?
    let dueDate: String?
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case dueDate = "due_date"
        case priority
    }
}

struct UpdatePlanRequest: Codable {
    let title: String?
    let description: String?
    let dueDate: String?
    let priority: Int?
    let status: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case dueDate = "due_date"
        case priority
        case status
    }
}
