import SwiftUI
import PhotosUI

struct DiaryListView: View {
    @State private var diaries: [Diary] = []
    @State private var isLoading = false
    @State private var showAddDiary = false
    @State private var showCalendar = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && diaries.isEmpty {
                    ProgressView("加载中...")
                } else if diaries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(isSearching ? "未找到相关日记" : "暂无日记")
                            .foregroundColor(.gray)
                        if !isSearching {
                            Button("写日记") {
                                showAddDiary = true
                            }
                        }
                    }
                } else {
                    List {
                        ForEach(diaries) { diary in
                            NavigationLink {
                                DiaryDetailView(diary: diary, onUpdate: { updatedDiary in
                                    if let index = diaries.firstIndex(where: { $0.id == updatedDiary.id }) {
                                        diaries[index] = updatedDiary
                                    }
                                }, onDelete: {
                                    diaries.removeAll { $0.id == diary.id }
                                })
                            } label: {
                                DiaryRowView(diary: diary)
                            }
                        }
                    }
                    .refreshable {
                        await loadDiaries()
                    }
                }
            }
            .navigationTitle("日记")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索日记")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddDiary = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showAddDiary) {
                AddDiaryView { diary in
                    diaries.insert(diary, at: 0)
                }
            }
            .sheet(isPresented: $showCalendar) {
                DiaryCalendarView()
            }
            .task {
                await loadDiaries()
            }
            .onChange(of: searchText) { newValue in
                Task {
                    if newValue.isEmpty {
                        isSearching = false
                        await loadDiaries()
                    } else {
                        isSearching = true
                        await searchDiaries(keyword: newValue)
                    }
                }
            }
        }
    }

    private func loadDiaries() async {
        isLoading = true
        do {
            let result = try await DiaryService.shared.getDiaries()
            diaries = result.list
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func searchDiaries(keyword: String) async {
        isLoading = true
        do {
            let result = try await DiaryService.shared.searchDiaries(keyword: keyword)
            diaries = result.list
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 日记行视图
struct DiaryRowView: View {
    let diary: Diary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(diary.diaryDate))
                    .font(.caption)
                    .foregroundColor(.gray)

                // 显示最后修改时间（如果和创建时间不同）
                if diary.updatedAt != diary.createdAt {
                    Text("· 编辑于 \(formatTime(diary.updatedAt))")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                }

                Spacer()

                if !diary.moodEmoji.isEmpty {
                    Text(diary.moodEmoji)
                }

                if !diary.weatherIcon.isEmpty {
                    Text(diary.weatherIcon)
                }
            }

            if let title = diary.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(diary.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 图片缩略图
            if let images = diary.images, !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(images.prefix(4)) { image in
                            if let url = image.imageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                    case .success(let img):
                                        img
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(6)
                                            .clipped()
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        // 如果超过4张，显示更多提示
                        if images.count > 4 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                Text("+\(images.count - 4)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ dateString: String) -> String {
        // 处理可能带时间的日期格式
        let cleanDateString = String(dateString.prefix(10))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: cleanDateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M月d日 EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ dateTimeString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // 尝试多种格式解析
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ",  // 2026-02-17 00:04:14.956218+08:00
            "yyyy-MM-dd HH:mm:ss.SSSSSS",        // 2026-02-17 00:04:14.956218
            "yyyy-MM-dd HH:mm:ssZZZZZ",          // 2026-02-17 00:04:14+08:00
            "yyyy-MM-dd HH:mm:ss",               // 2026-02-17 00:04:14
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ", // ISO格式带微秒和时区
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",      // ISO格式带微秒
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",        // ISO格式带时区
            "yyyy-MM-dd'T'HH:mm:ss"              // ISO格式
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateTimeString) {
                return formatTimeOnly(date)
            }
        }

        // 所有格式都失败，返回原始字符串
        return dateTimeString
    }

    private func formatTimeOnly(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M/d HH:mm"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yy/M/d HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 日记详情视图
struct DiaryDetailView: View {
    let diary: Diary
    var onUpdate: (Diary) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部信息
                HStack {
                    Text(formatDate(diary.diaryDate))
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Spacer()

                    if !diary.moodEmoji.isEmpty {
                        Text(diary.moodEmoji)
                            .font(.title2)
                    }

                    if !diary.weatherIcon.isEmpty {
                        Text(diary.weatherIcon)
                            .font(.title2)
                    }
                }

                // 标题
                if let title = diary.title, !title.isEmpty {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                // 内容
                Text(diary.content)
                    .font(.body)

                // 图片
                if let images = diary.images, !images.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(images) { image in
                            if let url = image.imageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(height: 200)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(8)
                                    case .failure:
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                            .frame(height: 100)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditDiaryView(diary: diary) { updatedDiary in
                onUpdate(updatedDiary)
            }
        }
        .alert("确定删除这篇日记吗？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await deleteDiary()
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // 处理可能带时间的日期格式
        let cleanDateString = String(dateString.prefix(10))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: cleanDateString) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M月d日 EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
    }

    private func deleteDiary() async {
        do {
            try await DiaryService.shared.deleteDiary(id: diary.id)
            onDelete()
            dismiss()
        } catch {
            // 处理错误
        }
    }
}

// MARK: - 添加日记视图
struct AddDiaryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var mood: Int? = nil
    @State private var weather: String? = nil
    @State private var diaryDate: Date
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 图片相关
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    var onAdd: (Diary) -> Void

    init(initialDate: Date = Date(), onAdd: @escaping (Diary) -> Void) {
        self._diaryDate = State(initialValue: initialDate)
        self.onAdd = onAdd
    }

    let moods = ["😢", "😕", "😐", "😊", "😄"]
    let weathers = [
        ("sunny", "☀️"),
        ("cloudy", "☁️"),
        ("rainy", "🌧️"),
        ("snowy", "❄️"),
        ("windy", "💨")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("日期", selection: $diaryDate, displayedComponents: .date)
                }

                Section("心情") {
                    HStack {
                        ForEach(0..<5) { index in
                            Button {
                                if mood == index + 1 {
                                    mood = nil
                                } else {
                                    mood = index + 1
                                }
                            } label: {
                                Text(moods[index])
                                    .font(.title)
                                    .opacity(mood == index + 1 ? 1 : 0.3)
                            }
                            .buttonStyle(.plain)

                            if index < 4 {
                                Spacer()
                            }
                        }
                    }
                }

                Section("天气") {
                    HStack {
                        ForEach(weathers, id: \.0) { (key, emoji) in
                            Button {
                                if weather == key {
                                    weather = nil
                                } else {
                                    weather = key
                                }
                            } label: {
                                Text(emoji)
                                    .font(.title)
                                    .opacity(weather == key ? 1 : 0.3)
                            }
                            .buttonStyle(.plain)

                            if key != weathers.last?.0 {
                                Spacer()
                            }
                        }
                    }
                }

                Section("内容") {
                    TextField("标题（可选）", text: $title)

                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }

                // 图片选择
                Section("图片") {
                    // 已选择的图片预览
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .cornerRadius(8)
                                            .clipped()

                                        Button {
                                            selectedImages.remove(at: index)
                                            if index < selectedPhotos.count {
                                                selectedPhotos.remove(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 9,
                        matching: .images
                    ) {
                        Label("选择图片", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotos) { newItems in
                        Task {
                            selectedImages = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImages.append(image)
                                }
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("写日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveDiary()
                        }
                    }
                    .disabled(isLoading || (title.isEmpty && content.isEmpty && selectedImages.isEmpty))
                }
            }
        }
    }

    private func saveDiary() async {
        isLoading = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CreateDiaryRequest(
            title: title.isEmpty ? nil : title,
            content: content,
            mood: mood,
            weather: weather,
            diaryDate: formatter.string(from: diaryDate)
        )

        do {
            let diary = try await DiaryService.shared.createDiary(request)

            // 上传图片
            for image in selectedImages {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    _ = try? await DiaryService.shared.uploadImage(diaryId: diary.id, imageData: imageData)
                }
            }

            // 重新获取日记（包含图片）
            let updatedDiary = try await DiaryService.shared.getDiary(id: diary.id)
            onAdd(updatedDiary)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 编辑日记视图
struct EditDiaryView: View {
    let diary: Diary
    var onUpdate: (Diary) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var content: String
    @State private var mood: Int?
    @State private var weather: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 图片相关
    @State private var existingImages: [DiaryImage]
    @State private var imagesToDelete: [Int] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []

    let moods = ["😢", "😕", "😐", "😊", "😄"]
    let weathers = [
        ("sunny", "☀️"),
        ("cloudy", "☁️"),
        ("rainy", "🌧️"),
        ("snowy", "❄️"),
        ("windy", "💨")
    ]

    init(diary: Diary, onUpdate: @escaping (Diary) -> Void) {
        self.diary = diary
        self.onUpdate = onUpdate
        _title = State(initialValue: diary.title ?? "")
        _content = State(initialValue: diary.content)
        _mood = State(initialValue: diary.mood)
        _weather = State(initialValue: diary.weather)
        _existingImages = State(initialValue: diary.images ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                Section("心情") {
                    HStack {
                        ForEach(0..<5) { index in
                            Button {
                                if mood == index + 1 {
                                    mood = nil
                                } else {
                                    mood = index + 1
                                }
                            } label: {
                                Text(moods[index])
                                    .font(.title)
                                    .opacity(mood == index + 1 ? 1 : 0.3)
                            }
                            .buttonStyle(.plain)

                            if index < 4 {
                                Spacer()
                            }
                        }
                    }
                }

                Section("天气") {
                    HStack {
                        ForEach(weathers, id: \.0) { (key, emoji) in
                            Button {
                                if weather == key {
                                    weather = nil
                                } else {
                                    weather = key
                                }
                            } label: {
                                Text(emoji)
                                    .font(.title)
                                    .opacity(weather == key ? 1 : 0.3)
                            }
                            .buttonStyle(.plain)

                            if key != weathers.last?.0 {
                                Spacer()
                            }
                        }
                    }
                }

                Section("内容") {
                    TextField("标题（可选）", text: $title)

                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }

                // 图片管理
                Section("图片") {
                    // 已有图片
                    if !existingImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(existingImages) { image in
                                    ZStack(alignment: .topTrailing) {
                                        if let url = image.imageURL {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let img):
                                                    img
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 80, height: 80)
                                                        .cornerRadius(8)
                                                        .clipped()
                                                default:
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(width: 80, height: 80)
                                                }
                                            }
                                        }

                                        Button {
                                            existingImages.removeAll { $0.id == image.id }
                                            imagesToDelete.append(image.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // 新选择的图片
                    if !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(newImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: newImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .cornerRadius(8)
                                            .clipped()

                                        Button {
                                            newImages.remove(at: index)
                                            if index < selectedPhotos.count {
                                                selectedPhotos.remove(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 9 - existingImages.count,
                        matching: .images
                    ) {
                        Label("添加图片", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotos) { newItems in
                        Task {
                            newImages = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    newImages.append(image)
                                }
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("编辑日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await updateDiary()
                        }
                    }
                    .disabled(isLoading || (title.isEmpty && content.isEmpty && existingImages.isEmpty && newImages.isEmpty))
                }
            }
        }
    }

    private func updateDiary() async {
        isLoading = true

        let request = UpdateDiaryRequest(
            title: title.isEmpty ? nil : title,
            content: content,
            mood: mood,
            weather: weather,
            diaryDate: nil
        )

        do {
            // 更新日记内容
            _ = try await DiaryService.shared.updateDiary(id: diary.id, request)

            // 删除标记的图片
            for imageId in imagesToDelete {
                try? await DiaryService.shared.deleteImage(diaryId: diary.id, imageId: imageId)
            }

            // 上传新图片
            for image in newImages {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    _ = try? await DiaryService.shared.uploadImage(diaryId: diary.id, imageData: imageData)
                }
            }

            // 重新获取日记（包含最新图片）
            let updatedDiary = try await DiaryService.shared.getDiary(id: diary.id)
            onUpdate(updatedDiary)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 选中日期数据
struct SelectedDayData: Identifiable {
    let id = UUID()
    let dateString: String
    var diaries: [Diary]
}

// MARK: - 日记日历视图
struct DiaryCalendarView: View {
    @State private var currentMonth = Date()
    @State private var monthDiaries: [String: [Diary]] = [:]
    @State private var isLoading = false
    @State private var selectedDayData: SelectedDayData?  // 多篇日记时使用
    @State private var selectedSingleDiary: Diary?  // 单篇日记时直接打开详情

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var totalDiaryCount: Int {
        monthDiaries.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    DiaryMonthNavigator(
                        currentMonth: $currentMonth,
                        onMonthChange: { await loadMonthData() }
                    )

                    DiaryMonthSummary(diaryCount: totalDiaryCount)

                    DiaryWeekdayHeader()

                    DiaryCalendarGridMulti(
                        currentMonth: currentMonth,
                        diaries: monthDiaries,
                        onDateTap: { date in
                            let dateStr = dateFormatter.string(from: date)
                            if let diaries = monthDiaries[dateStr], !diaries.isEmpty {
                                if diaries.count == 1 {
                                    // 只有一篇日记，直接打开详情
                                    selectedSingleDiary = diaries.first
                                } else {
                                    // 多篇日记，打开列表
                                    selectedDayData = SelectedDayData(dateString: dateStr, diaries: diaries)
                                }
                            }
                        }
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("日记日历")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadMonthData()
            }
            .sheet(item: $selectedDayData) { dayData in
                DiaryDayDetailSheet(
                    dateString: dayData.dateString,
                    diaries: dayData.diaries,
                    onUpdate: { updatedDiary in
                        // 更新本地数据
                        if var diaries = monthDiaries[dayData.dateString] {
                            if let index = diaries.firstIndex(where: { $0.id == updatedDiary.id }) {
                                diaries[index] = updatedDiary
                                monthDiaries[dayData.dateString] = diaries
                            }
                        }
                    },
                    onDelete: { deletedId in
                        if var diaries = monthDiaries[dayData.dateString] {
                            diaries.removeAll { $0.id == deletedId }
                            monthDiaries[dayData.dateString] = diaries
                            if diaries.isEmpty {
                                selectedDayData = nil
                            }
                        }
                    }
                )
            }
            .sheet(item: $selectedSingleDiary) { diary in
                // 单篇日记直接打开详情
                NavigationView {
                    DiaryDetailView(
                        diary: diary,
                        onUpdate: { updatedDiary in
                            // 更新本地数据
                            let dateStr = String(updatedDiary.diaryDate.prefix(10))
                            if var diaries = monthDiaries[dateStr] {
                                if let index = diaries.firstIndex(where: { $0.id == updatedDiary.id }) {
                                    diaries[index] = updatedDiary
                                    monthDiaries[dateStr] = diaries
                                }
                            }
                        },
                        onDelete: {
                            let dateStr = String(diary.diaryDate.prefix(10))
                            if var diaries = monthDiaries[dateStr] {
                                diaries.removeAll { $0.id == diary.id }
                                monthDiaries[dateStr] = diaries
                            }
                            selectedSingleDiary = nil
                        }
                    )
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func loadMonthData() async {
        isLoading = true

        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            isLoading = false
            return
        }

        let startStr = dateFormatter.string(from: startOfMonth)
        let endStr = dateFormatter.string(from: endOfMonth)

        do {
            let response = try await DiaryService.shared.getDiaries(
                startDate: startStr,
                endDate: endStr,
                page: 1,
                pageSize: 100
            )
            var grouped: [String: [Diary]] = [:]
            for diary in response.list {
                let dateKey = String(diary.diaryDate.prefix(10))
                if grouped[dateKey] == nil {
                    grouped[dateKey] = []
                }
                grouped[dateKey]?.append(diary)
            }
            monthDiaries = grouped
        } catch {
            print("加载日记失败: \(error)")
        }

        isLoading = false
    }
}

// MARK: - 日记月份导航
struct DiaryMonthNavigator: View {
    @Binding var currentMonth: Date
    var onMonthChange: () async -> Void

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    var body: some View {
        HStack {
            Button {
                Task {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    await onMonthChange()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text(monthFormatter.string(from: currentMonth))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                Task {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    await onMonthChange()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 本月统计
struct DiaryMonthSummary: View {
    let diaryCount: Int

    var body: some View {
        HStack {
            Image(systemName: "book.closed.fill")
                .foregroundColor(.orange)
            Text("本月记录了 \(diaryCount) 篇日记")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - 日记星期标题
struct DiaryWeekdayHeader: View {
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        HStack {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 日记日历网格（支持多条）
struct DiaryCalendarGridMulti: View {
    let currentMonth: Date
    let diaries: [String: [Diary]]
    let onDateTap: (Date) -> Void

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        let days = generateDaysInMonth()

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    let dateStr = dateFormatter.string(from: date)
                    let dayDiaries = diaries[dateStr] ?? []

                    DiaryDayCellMulti(
                        date: date,
                        diaries: dayDiaries,
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > Date()
                    )
                    .onTapGesture {
                        if !dayDiaries.isEmpty {
                            onDateTap(date)
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 60)
                }
            }
        }
    }

    private func generateDaysInMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDayOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - 日记日期单元格（支持多条）
struct DiaryDayCellMulti: View {
    let date: Date
    let diaries: [Diary]
    let isToday: Bool
    let isFuture: Bool

    private let calendar = Calendar.current

    var firstImageURL: URL? {
        for diary in diaries {
            if let images = diary.images, let first = images.first {
                return first.imageURL
            }
        }
        return nil
    }

    var firstMood: Int? {
        diaries.first?.mood
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let imageURL = firstImageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        default:
                            moodBackground
                        }
                    }
                } else {
                    moodBackground
                }

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                        .foregroundColor(textColor)
                        .shadow(color: firstImageURL != nil ? .black.opacity(0.5) : .clear, radius: 1)

                    if !diaries.isEmpty {
                        HStack(spacing: 1) {
                            if let mood = diaries.first?.moodEmoji, !mood.isEmpty {
                                Text(mood)
                                    .font(.system(size: 10))
                            }
                            if diaries.count > 1 {
                                Text("+\(diaries.count - 1)")
                                    .font(.system(size: 8))
                                    .foregroundColor(firstImageURL != nil ? .white : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    var moodBackground: some View {
        Group {
            if let mood = firstMood {
                moodColor(mood).opacity(0.3)
            } else if !diaries.isEmpty {
                Color.blue.opacity(0.15)
            } else if isFuture {
                Color(.systemGray6)
            } else {
                Color(.systemBackground)
            }
        }
    }

    var textColor: Color {
        if isFuture {
            return .gray
        } else if firstImageURL != nil {
            return .white
        } else if isToday {
            return .blue
        } else {
            return .primary
        }
    }

    func moodColor(_ mood: Int) -> Color {
        switch mood {
        case 1: return .purple
        case 2: return .blue
        case 3: return .gray
        case 4: return .green
        case 5: return .orange
        default: return .clear
        }
    }
}

// MARK: - 某天日记详情 Sheet
struct DiaryDayDetailSheet: View {
    let dateString: String
    let diaries: [Diary]
    var onUpdate: (Diary) -> Void
    var onDelete: (Int) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedDiary: Diary?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(diaries) { diary in
                    Button {
                        selectedDiary = diary
                    } label: {
                        DiaryRowView(diary: diary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedDiary) { diary in
                NavigationStack {
                    EditDiaryView(diary: diary, onUpdate: { updatedDiary in
                        onUpdate(updatedDiary)
                        selectedDiary = nil
                    })
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - 扩展 Diary 使其可以作为 sheet item
extension Diary: Hashable {
    static func == (lhs: Diary, rhs: Diary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    DiaryListView()
}
