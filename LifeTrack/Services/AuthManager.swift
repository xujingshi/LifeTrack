import Foundation
import SwiftUI

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

    // MARK: - 登录
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let request = LoginRequest(email: email, password: password)
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

    // MARK: - 注册
    func register(username: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let request = RegisterRequest(username: username, email: email, password: password)
            let response: TokenResponse = try await APIService.shared.request(
                endpoint: "/auth/register",
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
}
