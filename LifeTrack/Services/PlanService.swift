import Foundation

// MARK: - 规划服务
class PlanService {
    static let shared = PlanService()
    private init() {}

    // MARK: - 获取规划列表
    func getPlans(status: Int? = nil, page: Int = 1, pageSize: Int = 20) async throws -> PagedData<Plan> {
        var endpoint = "/plans?page=\(page)&page_size=\(pageSize)"
        if let status = status {
            endpoint += "&status=\(status)"
        }

        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 创建规划
    func createPlan(_ request: CreatePlanRequest) async throws -> Plan {
        return try await APIService.shared.request(
            endpoint: "/plans",
            method: "POST",
            body: request
        )
    }

    // MARK: - 更新规划
    func updatePlan(id: Int, _ request: UpdatePlanRequest) async throws -> Plan {
        return try await APIService.shared.request(
            endpoint: "/plans/\(id)",
            method: "PUT",
            body: request
        )
    }

    // MARK: - 删除规划
    func deletePlan(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/plans/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - 更新状态
    func updateStatus(id: Int, status: Int) async throws {
        struct StatusRequest: Codable {
            let status: Int
        }
        try await APIService.shared.requestNoData(
            endpoint: "/plans/\(id)/status",
            method: "PATCH",
            body: StatusRequest(status: status)
        )
    }
}
