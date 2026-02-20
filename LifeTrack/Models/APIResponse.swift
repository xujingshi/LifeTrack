import Foundation

// MARK: - API 统一响应格式
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
}

// MARK: - 分页响应
struct PagedData<T: Codable>: Codable {
    let list: [T]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case list
        case total
        case page
        case pageSize = "page_size"
    }
}

// MARK: - API 配置
struct APIConfig {
    static let baseURL = "http://ruvision.cn/lifetrack"
    static let apiVersion = "/api/v1"

    static var fullURL: String {
        return baseURL + apiVersion
    }
}

// MARK: - API 错误
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "没有数据"
        case .decodingError:
            return "数据解析错误"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "未授权，请重新登录"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
