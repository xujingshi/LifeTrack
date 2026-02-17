import Foundation

// MARK: - 规划模型
struct Plan: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let description: String
    let icon: String
    let color: String
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String
    var tasks: [PlanTask]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case icon
        case color
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case tasks
    }
}

// MARK: - 带进度的规划
struct PlanWithProgress: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let description: String
    let icon: String
    let color: String
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String
    let totalTasks: Int
    let completedTasks: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case icon
        case color
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
    }

    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

// MARK: - 任务模型
struct PlanTask: Codable, Identifiable {
    let id: Int
    let planId: Int
    let parentId: Int?
    let userId: Int
    let title: String
    let description: String
    let priority: Int
    let status: Int
    let dueDate: String?
    let completedAt: String?
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    var subTasks: [PlanTask]?

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case parentId = "parent_id"
        case userId = "user_id"
        case title
        case description
        case priority
        case status
        case dueDate = "due_date"
        case completedAt = "completed_at"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case subTasks = "sub_tasks"
    }

    var priorityLevel: TaskPriority {
        TaskPriority(rawValue: priority) ?? .low
    }

    var statusLevel: TaskStatus {
        TaskStatus(rawValue: status) ?? .todo
    }

    var isCompleted: Bool {
        status == TaskStatus.done.rawValue
    }
}

// MARK: - 任务优先级
enum TaskPriority: Int, CaseIterable {
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

// MARK: - 任务状态
enum TaskStatus: Int, CaseIterable {
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

// 保留旧的枚举名以兼容其他代码
typealias PlanPriority = TaskPriority
typealias PlanStatus = TaskStatus

// MARK: - 请求模型

// 创建规划请求
struct CreatePlanRequest: Codable {
    let name: String
    let description: String?
    let icon: String?
    let color: String?
}

// 更新规划请求
struct UpdatePlanRequest: Codable {
    let name: String?
    let description: String?
    let icon: String?
    let color: String?
    let isArchived: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case icon
        case color
        case isArchived = "is_archived"
    }
}

// 创建任务请求
struct CreateTaskRequest: Codable {
    let planId: Int
    let parentId: Int?
    let title: String
    let description: String?
    let priority: Int
    let dueDate: String?

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case parentId = "parent_id"
        case title
        case description
        case priority
        case dueDate = "due_date"
    }
}

// 更新任务请求
struct UpdateTaskRequest: Codable {
    let title: String?
    let description: String?
    let priority: Int?
    let status: Int?
    let dueDate: String?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case priority
        case status
        case dueDate = "due_date"
        case sortOrder = "sort_order"
    }
}

// 更新任务状态请求
struct UpdateTaskStatusRequest: Codable {
    let status: Int
}
