import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PlanListView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("规划")
                }
                .tag(0)

            CheckInView()
                .tabItem {
                    Image(systemName: "checkmark.circle")
                    Text("打卡")
                }
                .tag(1)

            DiaryListView()
                .tabItem {
                    Image(systemName: "book")
                    Text("日记")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("我的")
                }
                .tag(3)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.username ?? "用户")
                                .font(.headline)
                            Text(authManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("退出登录")
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
