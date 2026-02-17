import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var phone = ""
    @State private var code = ""

    // 验证手机号格式
    var isPhoneValid: Bool {
        phone.count == 11 && phone.allSatisfy { $0.isNumber }
    }

    // 验证码格式
    var isCodeValid: Bool {
        code.count == 6
    }

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
                    HStack {
                        Text("+86")
                            .foregroundColor(.gray)
                            .padding(.leading, 12)

                        TextField("手机号", text: $phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    HStack {
                        TextField("验证码", text: $code)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding(.leading, 12)

                        // 提示文本
                        Text("输入 000000")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.trailing, 12)
                    }
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
                        await authManager.loginWithPhone(phone: phone, code: code)
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
                .background(isPhoneValid && isCodeValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(authManager.isLoading || !isPhoneValid || !isCodeValid)

                // 提示文字
                Text("首次登录将自动创建账号")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
