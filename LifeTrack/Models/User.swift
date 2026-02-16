import Foundation

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
}

// MARK: - 认证相关请求
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
}

// MARK: - Token 响应
struct TokenResponse: Codable {
    let token: String
    let expiresAt: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case user
    }
}
