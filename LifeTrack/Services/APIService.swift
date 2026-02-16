import Foundation

// MARK: - API 服务
class APIService {
    static let shared = APIService()
    private init() {}

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_token") }
    }

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - 通用请求方法
    func request<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Codable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: APIConfig.fullURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

        if apiResponse.code != 0 {
            throw APIError.serverError(apiResponse.message)
        }

        guard let responseData = apiResponse.data else {
            throw APIError.noData
        }

        return responseData
    }

    // MARK: - 请求无返回数据
    func requestNoData(
        endpoint: String,
        method: String = "GET",
        body: Codable? = nil,
        requiresAuth: Bool = true
    ) async throws {
        guard let url = URL(string: APIConfig.fullURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        struct EmptyData: Codable {}
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<EmptyData?>.self, from: data)

        if apiResponse.code != 0 {
            throw APIError.serverError(apiResponse.message)
        }
    }

    // MARK: - 上传图片
    func uploadImage(
        endpoint: String,
        imageData: Data,
        filename: String
    ) async throws -> DiaryImage {
        guard let url = URL(string: APIConfig.fullURL + endpoint) else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<DiaryImage>.self, from: data)

        if apiResponse.code != 0 {
            throw APIError.serverError(apiResponse.message)
        }

        guard let responseData = apiResponse.data else {
            throw APIError.noData
        }

        return responseData
    }
}
