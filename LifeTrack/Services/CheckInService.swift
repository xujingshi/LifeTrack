import Foundation

// MARK: - 打卡服务
class CheckInService {
    static let shared = CheckInService()
    private init() {}

    // MARK: - 获取打卡项列表
    func getItems(activeOnly: Bool = true) async throws -> [CheckInItem] {
        let endpoint = "/checkin/items?active_only=\(activeOnly)"
        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 创建打卡项
    func createItem(_ request: CreateCheckInItemRequest) async throws -> CheckInItem {
        return try await APIService.shared.request(
            endpoint: "/checkin/items",
            method: "POST",
            body: request
        )
    }

    // MARK: - 更新打卡项
    func updateItem(id: Int, _ request: CreateCheckInItemRequest) async throws -> CheckInItem {
        return try await APIService.shared.request(
            endpoint: "/checkin/items/\(id)",
            method: "PUT",
            body: request
        )
    }

    // MARK: - 删除打卡项
    func deleteItem(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/checkin/items/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - 打卡
    func checkIn(_ request: CreateCheckInRecordRequest) async throws -> CheckInRecord {
        return try await APIService.shared.request(
            endpoint: "/checkin/records",
            method: "POST",
            body: request
        )
    }

    // MARK: - 取消打卡
    func cancelCheckIn(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/checkin/records/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - 获取打卡记录
    func getRecords(
        itemId: Int? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        page: Int = 1,
        pageSize: Int = 50
    ) async throws -> PagedData<CheckInRecord> {
        var endpoint = "/checkin/records?page=\(page)&page_size=\(pageSize)"
        if let itemId = itemId {
            endpoint += "&item_id=\(itemId)"
        }
        if let startDate = startDate {
            endpoint += "&start_date=\(startDate)"
        }
        if let endDate = endDate {
            endpoint += "&end_date=\(endDate)"
        }

        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 获取日历数据
    func getCalendar(itemId: Int, year: Int, month: Int) async throws -> [CalendarDayStatus] {
        let endpoint = "/checkin/items/\(itemId)/calendar?year=\(year)&month=\(month)"
        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 获取单个打卡项的日历完成情况
    func getItemCalendar(itemId: Int, year: Int, month: Int) async throws -> ItemCalendarData {
        let endpoint = "/checkin/items/\(itemId)/calendar?year=\(year)&month=\(month)"
        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 获取统计数据
    func getStatistics() async throws -> CheckInStatistics {
        return try await APIService.shared.request(endpoint: "/checkin/statistics")
    }
}
