import Foundation

// MARK: - 规划服务
class PlanService {
    static let shared = PlanService()
    private init() {}

    // MARK: - Plan 相关

    // 获取规划列表（带进度）
    func getPlans(includeArchived: Bool = false) async throws -> [PlanWithProgress] {
        var endpoint = "/plans"
        if includeArchived {
            endpoint += "?include_archived=true"
        }
        return try await APIService.shared.request(endpoint: endpoint)
    }

    // 获取规划详情（含任务）
    func getPlan(id: Int) async throws -> Plan {
        return try await APIService.shared.request(endpoint: "/plans/\(id)")
    }

    // 创建规划
    func createPlan(_ request: CreatePlanRequest) async throws -> Plan {
        return try await APIService.shared.request(
            endpoint: "/plans",
            method: "POST",
            body: request
        )
    }

    // 更新规划
    func updatePlan(id: Int, _ request: UpdatePlanRequest) async throws -> Plan {
        return try await APIService.shared.request(
            endpoint: "/plans/\(id)",
            method: "PUT",
            body: request
        )
    }

    // 删除规划
    func deletePlan(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/plans/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Task 相关

    // 获取任务列表
    func getTasks(planId: Int, status: Int? = nil, priority: Int? = nil) async throws -> [PlanTask] {
        var endpoint = "/tasks?plan_id=\(planId)"
        if let status = status {
            endpoint += "&status=\(status)"
        }
        if let priority = priority {
            endpoint += "&priority=\(priority)"
        }
        return try await APIService.shared.request(endpoint: endpoint)
    }

    // 获取任务详情
    func getTask(id: Int) async throws -> PlanTask {
        return try await APIService.shared.request(endpoint: "/tasks/\(id)")
    }

    // 创建任务
    func createTask(_ request: CreateTaskRequest) async throws -> PlanTask {
        return try await APIService.shared.request(
            endpoint: "/tasks",
            method: "POST",
            body: request
        )
    }

    // 更新任务
    func updateTask(id: Int, _ request: UpdateTaskRequest) async throws -> PlanTask {
        return try await APIService.shared.request(
            endpoint: "/tasks/\(id)",
            method: "PUT",
            body: request
        )
    }

    // 更新任务状态
    func updateTaskStatus(id: Int, status: Int) async throws {
        let request = UpdateTaskStatusRequest(status: status)
        try await APIService.shared.requestNoData(
            endpoint: "/tasks/\(id)/status",
            method: "PATCH",
            body: request
        )
    }

    // 删除任务
    func deleteTask(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/tasks/\(id)",
            method: "DELETE"
        )
    }
}
