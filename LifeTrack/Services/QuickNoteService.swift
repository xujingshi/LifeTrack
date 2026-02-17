import Foundation

// MARK: - 快速笔记服务
class QuickNoteService {
    static let shared = QuickNoteService()
    private init() {}

    // 获取快速笔记列表
    func getList(page: Int = 1, pageSize: Int = 50, keyword: String = "") async throws -> QuickNoteListResponse {
        var endpoint = "/quicknotes?page=\(page)&page_size=\(pageSize)"
        if !keyword.isEmpty {
            let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
            endpoint += "&keyword=\(encodedKeyword)"
        }
        return try await APIService.shared.request(
            endpoint: endpoint,
            method: "GET"
        )
    }

    // 创建快速笔记
    func create(content: String, isVoice: Bool = false) async throws -> QuickNote {
        let request = CreateQuickNoteRequest(content: content, isVoice: isVoice)
        return try await APIService.shared.request(
            endpoint: "/quicknotes",
            method: "POST",
            body: request
        )
    }

    // 删除快速笔记
    func delete(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/quicknotes/\(id)",
            method: "DELETE"
        )
    }

    // 更新快速笔记
    func update(id: Int, content: String) async throws -> QuickNote {
        let request = UpdateQuickNoteRequest(content: content)
        return try await APIService.shared.request(
            endpoint: "/quicknotes/\(id)",
            method: "PUT",
            body: request
        )
    }
}
