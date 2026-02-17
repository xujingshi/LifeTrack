import SwiftUI

// MARK: - 单个打卡项详情视图（含日历）
struct CheckInItemDetailView: View {
    let item: CheckInItem
    @Environment(\.dismiss) var dismiss

    @State private var currentMonth = Date()
    @State private var monthRecords: [String: CheckInRecord] = [:] // 日期 -> 记录的映射
    @State private var statistics: ItemStatistics?
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    @State private var showStatistics = false
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

                // 单项日历网格
                ItemCalendarGrid(
                    currentMonth: currentMonth,
                    records: monthRecords,
                    item: item
                )

                // 打卡记录列表
                RecentRecordsSection(item: item)
            }
            .padding()
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
    let records: [String: CheckInRecord]  // 日期 -> 记录的映射
    let item: CheckInItem  // 打卡项（包含创建日期和重复规则）

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
                    ItemDayCell(
                        date: date,
                        record: records[dateStr],
                        item: item,
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > Date(),
                        isBeforeCreation: isBeforeCreation,
                        isAvailable: isAvailable
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
        if isCompleted {
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
            if hasImage, let imageUrl = record?.imageUrl {
                // 图片打卡：显示图片作为背景
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
                    .shadow(color: hasImage ? .black.opacity(0.7) : .clear, radius: 1)

                // 根据类型显示不同内容
                if let (value, unit) = valueInfo {
                    // 数值打卡：显示数值
                    Text("\(String(format: "%.0f", value))\(unit)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                } else if isCompleted {
                    // 已完成显示对勾
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(hasImage ? .white : .white.opacity(0.9))
                        .shadow(color: hasImage ? .black.opacity(0.5) : .clear, radius: 1)
                } else if shouldShowAsIncomplete {
                    // 未完成但应该打卡的日期显示叉
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.6))
                }
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

// MARK: - 最近打卡记录
struct RecentRecordsSection: View {
    let item: CheckInItem

    @State private var records: [CheckInRecord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近打卡")
                .font(.headline)

            if records.isEmpty {
                Text("暂无打卡记录")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(records.prefix(10)) { record in
                    HStack(spacing: 8) {
                        // 状态图标
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        // 日期
                        Text(formatDate(record.checkDate))
                            .font(.subheadline)

                        // 数值或图片缩略图（紧跟日期）
                        if item.checkTypeEnum == .withValue, let value = record.value {
                            Text("\(String(format: "%.1f", value)) \(item.valueUnit ?? "")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        } else if item.checkTypeEnum == .withImage,
                                  let imageUrl = record.imageUrl, !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: APIConfig.baseURL + imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                default:
                                    ProgressView()
                                }
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Spacer()

                        // 打卡时间（最右侧）
                        if let checkedAt = record.checkedAt {
                            Text(formatTime(checkedAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .task {
            await loadRecords()
        }
    }

    private func loadRecords() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let endDate = formatter.string(from: Date())
        let startDate = formatter.string(from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())

        do {
            let response = try await CheckInService.shared.getRecords(itemId: item.id, startDate: startDate, endDate: endDate)
            records = response.list.sorted { $0.checkDate > $1.checkDate }
        } catch {
            print("加载记录失败: \(error)")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // 解析日期字符串 (yyyy-MM-dd 或带时间的格式)
        let cleanDate = String(dateString.prefix(10))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: cleanDate) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ dateString: String) -> String {
        // 尝试解析 ISO 8601 格式 (2026-02-17T08:30:00Z)
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        // 尝试解析带时区的格式 (2026-02-17T08:30:00+08:00)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        // 简单截取时间部分
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
