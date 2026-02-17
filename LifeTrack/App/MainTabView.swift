import SwiftUI
import PhotosUI

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

            QuickNoteView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("咻")
                }
                .tag(2)

            DiaryListView()
                .tabItem {
                    Image(systemName: "book")
                    Text("日记")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("我的")
                }
                .tag(4)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var statistics: OverallStatistics?
    @State private var checkInItemCount: Int = 0
    @State private var diaryCount: Int = 0
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            List {
                // 用户信息卡片
                Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack(spacing: 16) {
                            // 头像
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 70, height: 70)

                                Text(String((authManager.currentUser?.username ?? "用").prefix(1)))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.currentUser?.username ?? "用户")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Text("点击编辑个人资料")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }

                // 数据统计
                Section {
                    HStack(spacing: 0) {
                        StatisticItem(
                            value: "\(statistics?.totalCheckIns ?? 0)",
                            label: "打卡次数",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )

                        Divider()
                            .frame(height: 40)

                        StatisticItem(
                            value: "\(statistics?.activeDays ?? 0)",
                            label: "活跃天数",
                            icon: "flame.fill",
                            color: .orange
                        )

                        Divider()
                            .frame(height: 40)

                        StatisticItem(
                            value: "\(statistics?.currentStreak ?? 0)",
                            label: "连续天数",
                            icon: "bolt.fill",
                            color: .blue
                        )
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("数据统计")
                }

                // 功能入口
                Section {
                    NavigationLink {
                        CheckInOverallStatisticsView()
                    } label: {
                        ProfileMenuItem(
                            icon: "chart.bar.fill",
                            title: "打卡统计",
                            color: .blue
                        )
                    }

                    NavigationLink {
                        CheckInItemsManageView()
                    } label: {
                        ProfileMenuItem(
                            icon: "list.bullet.rectangle",
                            title: "打卡项管理",
                            subtitle: "\(checkInItemCount) 个打卡项",
                            color: .green
                        )
                    }

                    NavigationLink {
                        DiaryStatisticsView(diaryCount: diaryCount)
                    } label: {
                        ProfileMenuItem(
                            icon: "book.fill",
                            title: "日记统计",
                            subtitle: "\(diaryCount) 篇日记",
                            color: .purple
                        )
                    }
                } header: {
                    Text("功能")
                }

                // 设置
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        ProfileMenuItem(
                            icon: "bell.fill",
                            title: "通知设置",
                            color: .red
                        )
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        ProfileMenuItem(
                            icon: "info.circle.fill",
                            title: "关于",
                            color: .gray
                        )
                    }
                } header: {
                    Text("设置")
                }

                // 退出登录
                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true

        // 加载打卡统计
        do {
            statistics = try await CheckInService.shared.getOverallStatistics(period: "month")
        } catch {
            print("加载统计失败: \(error)")
        }

        // 加载打卡项数量
        do {
            let items = try await CheckInService.shared.getItems()
            checkInItemCount = items.count
        } catch {
            print("加载打卡项失败: \(error)")
        }

        // 加载日记数量
        do {
            let result = try await DiaryService.shared.getDiaries()
            diaryCount = result.total
        } catch {
            print("加载日记失败: \(error)")
        }

        isLoading = false
    }
}

// MARK: - 统计项
struct StatisticItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 菜单项
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - 打卡项管理
struct CheckInItemsManageView: View {
    @State private var items: [CheckInItem] = []
    @State private var isLoading = false

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    CheckInItemDetailView(item: item, onDelete: {
                        items.removeAll { $0.id == item.id }
                    })
                } label: {
                    HStack {
                        Image(systemName: item.checkTypeEnum == .record ? "square.and.pencil" : "checkmark.circle")
                            .foregroundColor(item.isActive ? .green : .gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundColor(item.isActive ? .primary : .gray)

                            Text(item.repeatTypeEnum.title)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if !item.isActive {
                            Text("已停用")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("打卡项管理")
        .task {
            await loadItems()
        }
        .refreshable {
            await loadItems()
        }
        .overlay {
            if isLoading && items.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadItems() async {
        isLoading = true
        do {
            items = try await CheckInService.shared.getItems()
        } catch {
            print("加载打卡项失败: \(error)")
        }
        isLoading = false
    }
}

// MARK: - 日记统计
struct DiaryStatisticsView: View {
    let diaryCount: Int

    var body: some View {
        List {
            Section {
                HStack {
                    Text("日记总数")
                    Spacer()
                    Text("\(diaryCount) 篇")
                        .foregroundColor(.gray)
                }
            }

            Section {
                Text("更多统计功能开发中...")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .navigationTitle("日记统计")
    }
}

// MARK: - 通知设置
struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("reminderTime") private var reminderTime = "09:00"

    var body: some View {
        List {
            Section {
                Toggle("启用打卡提醒", isOn: $notificationsEnabled)
            } footer: {
                Text("开启后，系统会在设定时间提醒您完成打卡")
            }

            if notificationsEnabled {
                Section("提醒时间") {
                    HStack {
                        Text("每日提醒")
                        Spacer()
                        Text(reminderTime)
                            .foregroundColor(.gray)
                    }
                }
            }

            Section {
                Text("更多通知设置开发中...")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .navigationTitle("通知设置")
    }
}

// MARK: - 关于页面
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("LifeTrack")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("版本 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            }

            Section("功能介绍") {
                FeatureRow(icon: "checkmark.circle.fill", title: "习惯打卡", description: "养成好习惯，记录每一天", color: .green)
                FeatureRow(icon: "book.fill", title: "日记记录", description: "记录生活点滴", color: .purple)
                FeatureRow(icon: "list.bullet.clipboard", title: "计划管理", description: "规划目标与任务", color: .blue)
                FeatureRow(icon: "bolt.fill", title: "快速笔记", description: "随时记录灵感", color: .orange)
            }

            Section {
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("xujingshi")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("关于")
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 个人资料编辑
struct ProfileEditView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var username: String = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isUploadingAvatar = false

    var body: some View {
        Form {
            // 头像
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            if let avatarImage = avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let avatarUrl = authManager.currentUser?.avatarUrl,
                                      !avatarUrl.isEmpty {
                                AsyncImage(url: URL(string: APIConfig.baseURL + avatarUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    defaultAvatarView
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                defaultAvatarView
                            }

                            // 编辑图标
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                            }
                            .frame(width: 100, height: 100)

                            if isUploadingAvatar {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // 基本信息
            Section("基本信息") {
                HStack {
                    Text("用户名")
                        .foregroundColor(.gray)
                    TextField("请输入用户名", text: $username)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("手机号")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(maskPhoneNumber(authManager.currentUser?.phone ?? ""))
                        .foregroundColor(.gray)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task {
                        await saveProfile()
                    }
                }
                .disabled(username.isEmpty || isSaving)
            }
        }
        .onAppear {
            username = authManager.currentUser?.username ?? ""
        }
        .onChange(of: selectedPhoto) { newValue in
            Task {
                await loadAndUploadPhoto(newValue)
            }
        }
        .alert("保存成功", isPresented: $showSuccess) {
            Button("确定") {
                dismiss()
            }
        }
    }

    private var defaultAvatarView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 100, height: 100)

            Text(String((username.isEmpty ? "用" : username).prefix(1)))
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func maskPhoneNumber(_ phone: String) -> String {
        guard phone.count >= 7 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }

    private func loadAndUploadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        isUploadingAvatar = true
        errorMessage = nil

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                avatarImage = uiImage

                // 压缩图片
                if let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                    try await AuthManager.shared.uploadAvatar(imageData: compressedData)
                }
            }
        } catch {
            errorMessage = "头像上传失败: \(error.localizedDescription)"
        }

        isUploadingAvatar = false
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        do {
            try await AuthManager.shared.updateProfile(username: username)
            showSuccess = true
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
