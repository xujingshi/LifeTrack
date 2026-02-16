import SwiftUI
import PhotosUI

struct DiaryListView: View {
    @State private var diaries: [Diary] = []
    @State private var isLoading = false
    @State private var showAddDiary = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
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
            .searchable(text: $searchText, prompt: "搜索日记")
            .toolbar {
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
    @State private var mood: Int = 3
    @State private var weather = "sunny"
    @State private var diaryDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 图片相关
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    var onAdd: (Diary) -> Void

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
                                mood = index + 1
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
                                weather = key
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
                    .disabled(content.isEmpty || isLoading)
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
    @State private var mood: Int
    @State private var weather: String
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
        _mood = State(initialValue: diary.mood ?? 3)
        _weather = State(initialValue: diary.weather ?? "sunny")
        _existingImages = State(initialValue: diary.images ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                Section("心情") {
                    HStack {
                        ForEach(0..<5) { index in
                            Button {
                                mood = index + 1
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
                                weather = key
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
                    .disabled(content.isEmpty || isLoading)
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

#Preview {
    DiaryListView()
}
