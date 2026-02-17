import Foundation

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let phone: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, phone
        case avatarUrl = "avatar_url"
    }
}

// MARK: - 认证相关请求
struct PhoneLoginRequest: Codable {
    let phone: String
    let code: String
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

// MARK: - 更新用户资料请求
struct UpdateProfileRequest: Codable {
    let username: String
}
