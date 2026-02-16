import Foundation

// MARK: - 日记服务
class DiaryService {
    static let shared = DiaryService()
    private init() {}

    // MARK: - 获取日记列表
    func getDiaries(
        startDate: String? = nil,
        endDate: String? = nil,
        mood: Int? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> PagedData<Diary> {
        var endpoint = "/diaries?page=\(page)&page_size=\(pageSize)"
        if let startDate = startDate {
            endpoint += "&start_date=\(startDate)"
        }
        if let endDate = endDate {
            endpoint += "&end_date=\(endDate)"
        }
        if let mood = mood {
            endpoint += "&mood=\(mood)"
        }

        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 获取日记详情
    func getDiary(id: Int) async throws -> Diary {
        return try await APIService.shared.request(endpoint: "/diaries/\(id)")
    }

    // MARK: - 创建日记
    func createDiary(_ request: CreateDiaryRequest) async throws -> Diary {
        return try await APIService.shared.request(
            endpoint: "/diaries",
            method: "POST",
            body: request
        )
    }

    // MARK: - 更新日记
    func updateDiary(id: Int, _ request: UpdateDiaryRequest) async throws -> Diary {
        return try await APIService.shared.request(
            endpoint: "/diaries/\(id)",
            method: "PUT",
            body: request
        )
    }

    // MARK: - 删除日记
    func deleteDiary(id: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/diaries/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - 搜索日记
    func searchDiaries(keyword: String, page: Int = 1, pageSize: Int = 20) async throws -> PagedData<Diary> {
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let endpoint = "/diaries/search?keyword=\(encodedKeyword)&page=\(page)&page_size=\(pageSize)"
        return try await APIService.shared.request(endpoint: endpoint)
    }

    // MARK: - 上传图片
    func uploadImage(diaryId: Int, imageData: Data) async throws -> DiaryImage {
        return try await APIService.shared.uploadImage(
            endpoint: "/diaries/\(diaryId)/images",
            imageData: imageData,
            filename: "image.jpg"
        )
    }

    // MARK: - 删除图片
    func deleteImage(diaryId: Int, imageId: Int) async throws {
        try await APIService.shared.requestNoData(
            endpoint: "/diaries/\(diaryId)/images/\(imageId)",
            method: "DELETE"
        )
    }
}
