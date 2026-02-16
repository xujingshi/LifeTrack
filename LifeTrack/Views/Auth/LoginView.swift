import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo 区域
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("LifeTrack")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("自律打卡 · 日记")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)

                // 登录表单
                VStack(spacing: 16) {
                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // 错误提示
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // 登录按钮
                Button {
                    Task {
                        await authManager.login(email: email, password: password)
                    }
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("登录")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)

                // 注册链接
                Button {
                    showRegister = true
                } label: {
                    Text("还没有账号？立即注册")
                        .font(.subheadline)
                }

                Spacer()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authManager)
            }
        }
    }
}

// MARK: - 注册视图
struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var passwordMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 表单
                VStack(spacing: 16) {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)

                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)

                    SecureField("确认密码", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)

                    if !confirmPassword.isEmpty && !passwordMatch {
                        Text("两次密码不一致")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                // 错误提示
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // 注册按钮
                Button {
                    Task {
                        await authManager.register(username: username, email: email, password: password)
                        if authManager.isLoggedIn {
                            dismiss()
                        }
                    }
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("注册")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(authManager.isLoading || !passwordMatch || username.isEmpty || email.isEmpty)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
