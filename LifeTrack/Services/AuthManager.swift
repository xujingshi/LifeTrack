import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.xujingshi.LifeTrack", category: "AuthManager")

// MARK: - 认证管理器
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private init() {
        checkLoginStatus()
    }

    private func checkLoginStatus() {
        if let token = UserDefaults.standard.string(forKey: "auth_token"),
           !token.isEmpty,
           let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.isLoggedIn = true
            self.currentUser = user
        }
    }

    // MARK: - 手机号登录（验证码登录，无账号自动创建）
    func loginWithPhone(phone: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let request = PhoneLoginRequest(phone: phone, code: code)
            let response: TokenResponse = try await APIService.shared.request(
                endpoint: "/auth/login",
                method: "POST",
                body: request,
                requiresAuth: false
            )

            saveAuth(token: response.token, user: response.user)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 登出
    func logout() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
        APIService.shared.setToken(nil)
        isLoggedIn = false
        currentUser = nil
    }

    // MARK: - 保存认证信息
    private func saveAuth(token: String, user: User) {
        UserDefaults.standard.set(token, forKey: "auth_token")
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
        APIService.shared.setToken(token)
        currentUser = user
        isLoggedIn = true
    }

    // MARK: - 更新用户资料
    func updateProfile(username: String) async throws {
        logger.debug("updateProfile: 开始更新用户名为 \(username)")
        let request = UpdateProfileRequest(username: username)
        do {
            let updatedUser: User = try await APIService.shared.request(
                endpoint: "/user/profile",
                method: "PUT",
                body: request
            )
            logger.debug("updateProfile: 更新成功, user id=\(updatedUser.id)")

            // 更新本地存储
            if let userData = try? JSONEncoder().encode(updatedUser) {
                UserDefaults.standard.set(userData, forKey: "current_user")
            }
            currentUser = updatedUser
        } catch {
            logger.error("updateProfile: 更新失败 - \(error)")
            throw error
        }
    }

    // MARK: - 上传头像
    func uploadAvatar(imageData: Data) async throws {
        logger.debug("uploadAvatar: 开始上传头像")
        let updatedUser = try await APIService.shared.uploadAvatar(imageData: imageData)
        logger.debug("uploadAvatar: 上传成功")

        // 更新本地存储
        if let userData = try? JSONEncoder().encode(updatedUser) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
        currentUser = updatedUser
    }
}
