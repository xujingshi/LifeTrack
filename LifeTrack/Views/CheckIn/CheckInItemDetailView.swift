import SwiftUI

// MARK: - 全屏图片预览
struct FullScreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: APIConfig.baseURL + imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        scale = max(1.0, min(scale, 3.0))
                                    }
                                }
                        )
                case .failure:
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("加载失败")
                            .foregroundColor(.gray)
                    }
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .onTapGesture(count: 2) {
            withAnimation {
                scale = scale > 1.0 ? 1.0 : 2.0
            }
        }
    }
}

// MARK: - 单个打卡项详情视图（含日历）
struct CheckInItemDetailView: View {
    let item: CheckInItem
    @Environment(\.dismiss) var dismiss

    @State private var currentMonth = Date()
    @State private var selectedDate = Date()  // 日历选中的日期
    @State private var monthRecords: [String: CheckInRecord] = [:] // 日期 -> 记录的映射
    @State private var statistics: ItemStatistics?
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    @State private var showStatistics = false
    @State private var fullScreenImageUrl: String? = nil  // 全屏查看的图片
    var onDelete: (() -> Void)? = nil

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 打卡项信息卡片
                ItemInfoCard(item: item, statistics: statistics)

                // 月份导航
                MonthNavigator(
                    currentMonth: $currentMonth,
                    onMonthChange: { await loadMonthData() }
                )

                // 星期标题
                WeekdayHeader()

                // 单项日历网格（支持点击选择日期）
                ItemCalendarGrid(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate,
                    records: monthRecords,
                    item: item,
                    onImageTap: { imageUrl in
                        fullScreenImageUrl = imageUrl
                    }
                )

                // 选中日期的打卡记录
                SelectedDateRecordsSection(
                    item: item,
                    selectedDate: selectedDate,
                    record: monthRecords[dateFormatter.string(from: selectedDate)],
                    onImageTap: { imageUrl in
                        fullScreenImageUrl = imageUrl
                    }
                )
            }
            .padding()
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullScreenImageUrl != nil },
            set: { if !$0 { fullScreenImageUrl = nil } }
        )) {
            if let imageUrl = fullScreenImageUrl {
                FullScreenImageView(imageUrl: imageUrl)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showStatistics = true
                    } label: {
                        Label("查看统计", systemImage: "chart.bar.xaxis")
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
        .navigationDestination(isPresented: $showStatistics) {
            CheckInStatisticsView(item: item)
        }
        .alert("删除打卡项", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    await deleteItem()
                }
            }
        } message: {
            Text("确定要删除「\(item.name)」吗？所有打卡记录也将被删除。")
        }
        .task {
            await loadMonthData()
            await loadStatistics()
        }
    }

    private func deleteItem() async {
        do {
            try await CheckInService.shared.deleteItem(id: item.id)
            onDelete?()
            dismiss()
        } catch {
            print("删除失败: \(error)")
        }
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
            let response = try await CheckInService.shared.getRecords(
                itemId: item.id,
                startDate: startStr,
                endDate: endStr
            )
            // 日期 -> 记录的映射
            var recordsMap: [String: CheckInRecord] = [:]
            for record in response.list {
                let dateKey = String(record.checkDate.prefix(10))
                recordsMap[dateKey] = record
            }
            monthRecords = recordsMap
        } catch {
            print("加载记录失败: \(error)")
        }

        isLoading = false
    }

    private func loadStatistics() async {
        // 计算连续打卡天数等统计
        do {
            let calendar = try await CheckInService.shared.getItemCalendar(itemId: item.id, year: Calendar.current.component(.year, from: Date()), month: Calendar.current.component(.month, from: Date()))
            statistics = ItemStatistics(
                totalDays: calendar.completedDates.count,
                currentStreak: calendar.currentStreak,
                longestStreak: calendar.longestStreak
            )
        } catch {
            print("加载统计失败: \(error)")
        }
    }
}

// MARK: - 打卡项统计
struct ItemStatistics {
    var totalDays: Int
    var currentStreak: Int
    var longestStreak: Int
}

// MARK: - 打卡项信息卡片
struct ItemInfoCard: View {
    let item: CheckInItem
    let statistics: ItemStatistics?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        if let time = item.scheduledTime, !time.isEmpty {
                            Label(time, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Label(item.repeatTypeEnum.title, systemImage: "repeat")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // 起始日期
                    Label("始于 \(formatStartDate(item.createdAt))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // 打卡项图标
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }

            if let stats = statistics {
                Divider()

                HStack {
                    StatItem(title: "累计打卡", value: "\(stats.totalDays)天")
                    Spacer()
                    StatItem(title: "当前连续", value: "\(stats.currentStreak)天")
                    Spacer()
                    StatItem(title: "最长连续", value: "\(stats.longestStreak)天")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func formatStartDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // 尝试多种格式解析
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ssZZZZZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                formatter.dateFormat = "yyyy年M月d日"
                formatter.locale = Locale(identifier: "zh_CN")
                return formatter.string(from: date)
            }
        }

        // 解析失败，尝试只取前10个字符作为日期
        let dateOnly = String(dateString.prefix(10))
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateOnly) {
            formatter.dateFormat = "yyyy年M月d日"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }

        return dateString
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - 单项日历网格
struct ItemCalendarGrid: View {
    let currentMonth: Date
    @Binding var selectedDate: Date  // 选中的日期
    let records: [String: CheckInRecord]  // 日期 -> 记录的映射
    let item: CheckInItem  // 打卡项（包含创建日期和重复规则）
    var onImageTap: ((String) -> Void)? = nil  // 图片点击回调

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var itemCreatedDate: Date? {
        parseDate(item.createdAt)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        let dateOnly = String(dateString.prefix(10))
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateOnly)
    }

    // 检查某个日期是否需要打卡（根据重复规则）
    private func isItemAvailableOn(date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)

        switch item.repeatTypeEnum {
        case .daily:
            return true
        case .weekday:
            return weekday >= 2 && weekday <= 6
        case .weekend:
            return weekday == 1 || weekday == 7
        case .custom:
            guard let repeatDays = item.repeatDays, !repeatDays.isEmpty else { return true }
            let days = repeatDays.split(separator: ",").compactMap { Int($0) }
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            return days.contains(adjustedWeekday)
        case .interval:
            guard let createdDate = itemCreatedDate else { return true }
            let daysSinceCreation = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdDate), to: calendar.startOfDay(for: date)).day ?? 0
            return daysSinceCreation >= 0 && daysSinceCreation % item.intervalDays == 0
        case .free:
            // 自由打卡不需要每天都打卡
            return false
        }
    }

    var body: some View {
        let days = generateDaysInMonth()

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    let dateStr = dateFormatter.string(from: date)
                    let isBeforeCreation = isDateBeforeCreation(date)
                    let isAvailable = isItemAvailableOn(date: date)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    ItemDayCell(
                        date: date,
                        record: records[dateStr],
                        item: item,
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > Date(),
                        isBeforeCreation: isBeforeCreation,
                        isAvailable: isAvailable,
                        isSelected: isSelected,
                        onTap: {
                            selectedDate = date
                        },
                        onImageTap: onImageTap
                    )
                } else {
                    Color.clear
                        .frame(height: 48)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // 检查日期是否在创建之前
    private func isDateBeforeCreation(_ date: Date) -> Bool {
        guard let createdDate = itemCreatedDate else { return false }
        return calendar.compare(date, to: createdDate, toGranularity: .day) == .orderedAscending
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

// MARK: - 单项日期单元格
struct ItemDayCell: View {
    let date: Date
    let record: CheckInRecord?  // 当天的打卡记录
    let item: CheckInItem       // 打卡项信息
    let isToday: Bool
    let isFuture: Bool
    let isBeforeCreation: Bool  // 打卡项创建之前的日期
    let isAvailable: Bool  // 根据重复规则是否需要打卡
    var isSelected: Bool = false  // 是否被选中
    var onTap: (() -> Void)? = nil  // 点击选中回调
    var onImageTap: ((String) -> Void)? = nil  // 图片点击回调（长按触发）

    private let calendar = Calendar.current

    private var isCompleted: Bool {
        record != nil
    }

    // 是否应该显示为未完成（需要打卡但未打卡）
    private var shouldShowAsIncomplete: Bool {
        !isFuture && !isBeforeCreation && !isCompleted && isAvailable
    }

    // 是否有图片
    private var hasImage: Bool {
        item.checkTypeEnum == .withImage && record?.imageUrl != nil && !(record?.imageUrl ?? "").isEmpty
    }

    // 获取数值
    private var valueInfo: (value: Double, unit: String)? {
        guard item.checkTypeEnum == .withValue, let value = record?.value else { return nil }
        return (value, item.valueUnit ?? "")
    }

    var backgroundColor: Color {
        // 选中状态优先
        if isSelected {
            return .blue
        }
        // 已完成的优先显示绿色（或图片背景）
        if isCompleted {
            return hasImage ? Color.clear : Color.green
        } else if isFuture || isBeforeCreation {
            return Color(.systemGray6)
        } else if !isAvailable {
            // 不需要打卡的日期（如自由打卡的未打卡日）
            return Color(.systemGray6)
        } else {
            // 未完成的过去日期 - 浅红色背景
            return Color.red.opacity(0.15)
        }
    }

    var textColor: Color {
        if isSelected {
            return .white
        } else if isCompleted {
            return .white
        } else if isFuture || isBeforeCreation || !isAvailable {
            return .gray
        } else {
            return .red.opacity(0.8)
        }
    }

    var body: some View {
        ZStack {
            // 背景层
            if hasImage && !isSelected, let imageUrl = record?.imageUrl {
                // 图片打卡：显示图片作为背景（选中时不显示图片背景）
                let fullURL = APIConfig.baseURL + imageUrl
                AsyncImage(url: URL(string: fullURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green)
                    }
                }
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(height: 48)
            }

            // 内容层
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)
                    .shadow(color: (hasImage && !isSelected) ? .black.opacity(0.7) : .clear, radius: 1)

                // 根据类型显示不同内容
                if let (value, unit) = valueInfo {
                    // 数值打卡：显示数值
                    Text("\(String(format: "%.0f", value))\(unit)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                } else if isCompleted {
                    // 已完成显示对勾
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white : (hasImage ? .white : .white.opacity(0.9)))
                        .shadow(color: (hasImage && !isSelected) ? .black.opacity(0.5) : .clear, radius: 1)
                } else if shouldShowAsIncomplete {
                    // 未完成但应该打卡的日期显示叉
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .red.opacity(0.6))
                }
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())  // 确保整个区域可点击
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture {
            // 长按查看图片大图
            if hasImage, let imageUrl = record?.imageUrl {
                onImageTap?(imageUrl)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

// MARK: - 选中日期的打卡记录
struct SelectedDateRecordsSection: View {
    let item: CheckInItem
    let selectedDate: Date
    let record: CheckInRecord?  // 选中日期的打卡记录
    var onImageTap: ((String) -> Void)? = nil

    private let calendar = Calendar.current

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")

        if calendar.isDateInToday(selectedDate) {
            return "今天"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "昨天"
        }
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateString)
                .font(.headline)

            if let record = record {
                // 有打卡记录
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)

                        Text("已打卡")
                            .font(.subheadline)
                            .foregroundColor(.green)

                        Spacer()

                        if let checkedAt = record.checkedAt {
                            Text(formatTime(checkedAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // 数值显示
                    if item.checkTypeEnum == .withValue, let value = record.value {
                        HStack {
                            Text("记录数值")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(String(format: "%.1f", value)) \(item.valueUnit ?? "")")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }

                    // 图片显示
                    if item.checkTypeEnum == .withImage,
                       let imageUrl = record.imageUrl, !imageUrl.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("打卡图片")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            AsyncImage(url: URL(string: APIConfig.baseURL + imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxHeight: 200)
                                        .clipped()
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            onImageTap?(imageUrl)
                                        }
                                case .failure:
                                    HStack {
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                        Text("图片加载失败")
                                            .foregroundColor(.gray)
                                    }
                                default:
                                    ProgressView()
                                        .frame(height: 100)
                                }
                            }
                        }
                    }

                    // 备注
                    if let note = record.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备注")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(note)
                                .font(.body)
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                // 无打卡记录
                HStack {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    Text("未打卡")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func formatTime(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        if dateString.count > 11 {
            let start = dateString.index(dateString.startIndex, offsetBy: 11)
            let end = dateString.index(start, offsetBy: 5, limitedBy: dateString.endIndex) ?? dateString.endIndex
            return String(dateString[start..<end])
        }
        return dateString
    }
}

#Preview {
    NavigationView {
        CheckInItemDetailView(item: CheckInItem(
            id: 1,
            userId: 1,
            name: "早起",
            scheduledTime: "06:00",
            icon: nil,
            color: nil,
            remind: true,
            repeatType: 0,
            repeatDays: nil,
            intervalDays: 1,
            checkType: 0,
            valueUnit: nil,
            isActive: true,
            createdAt: ""
        ))
    }
}
