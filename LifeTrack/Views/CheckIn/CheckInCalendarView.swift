import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.xujingshi.LifeTrack", category: "CalendarView")

// MARK: - 打卡日历视图
struct CheckInCalendarView: View {
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var items: [CheckInItem] = []
    @State private var monthRecords: [String: [CheckInRecord]] = [:] // date -> records
    @State private var isLoading = false
    @State private var fullScreenImageUrl: String? = nil  // 全屏查看的图片

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 月份导航
                    MonthNavigator(
                        currentMonth: $currentMonth,
                        onMonthChange: { await loadMonthData() }
                    )

                    // 星期标题
                    WeekdayHeader()

                    // 日历网格
                    CalendarGrid(
                        currentMonth: currentMonth,
                        selectedDate: $selectedDate,
                        records: monthRecords,
                        items: items
                    )

                    // 选中日期的详情
                    SelectedDateDetail(
                        date: selectedDate,
                        items: items,
                        records: monthRecords[dateFormatter.string(from: selectedDate)] ?? [],
                        onImageTap: { imageUrl in
                            fullScreenImageUrl = imageUrl
                        }
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("打卡日历")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadItems()
                await loadMonthData()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullScreenImageUrl != nil },
            set: { if !$0 { fullScreenImageUrl = nil } }
        )) {
            if let imageUrl = fullScreenImageUrl {
                FullScreenImageView(imageUrl: imageUrl)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func loadItems() async {
        do {
            items = try await CheckInService.shared.getItems()
            logger.notice("加载打卡项成功: \(self.items.count) 个")
        } catch {
            logger.error("加载打卡项失败: \(error.localizedDescription)")
        }
    }

    private func loadMonthData() async {
        isLoading = true
        logger.notice("开始加载日历数据")

        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            isLoading = false
            return
        }

        let startStr = dateFormatter.string(from: startOfMonth)
        let endStr = dateFormatter.string(from: endOfMonth)

        do {
            let response = try await CheckInService.shared.getRecords(startDate: startStr, endDate: endStr)
            logger.notice("加载记录数: \(response.list.count)")

            // 按日期分组（处理日期格式，只取前10个字符 YYYY-MM-DD）
            var grouped: [String: [CheckInRecord]] = [:]
            var imageCount = 0
            var valueCount = 0

            for record in response.list {
                let dateKey = String(record.checkDate.prefix(10))
                if grouped[dateKey] == nil {
                    grouped[dateKey] = []
                }
                grouped[dateKey]?.append(record)

                // 统计图片和数值打卡
                if let imageUrl = record.imageUrl, !imageUrl.isEmpty {
                    imageCount += 1
                    let hasItem = record.item != nil
                    let checkType = record.item?.checkType ?? -1
                    logger.notice("图片记录: \(dateKey), hasItem=\(hasItem), checkType=\(checkType)")
                }
                if record.value != nil {
                    valueCount += 1
                    let hasItem = record.item != nil
                    let checkType = record.item?.checkType ?? -1
                    logger.notice("数值记录: \(dateKey), hasItem=\(hasItem), checkType=\(checkType)")
                }
            }
            monthRecords = grouped
            logger.notice("加载完成: 图片=\(imageCount), 数值=\(valueCount), 日期数=\(self.monthRecords.count)")
        } catch {
            logger.error("加载记录失败: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - 月份导航
struct MonthNavigator: View {
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

// MARK: - 星期标题
struct WeekdayHeader: View {
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

// MARK: - 日历网格
struct CalendarGrid: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let records: [String: [CheckInRecord]]
    let items: [CheckInItem]

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        let days = generateDaysInMonth()

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    let dateStr = dateFormatter.string(from: date)
                    let availableCount = availableItemsCount(for: date)
                    let dayRecords = records[dateStr] ?? []
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > Date(),
                        completedCount: dayRecords.count,
                        totalCount: availableCount
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
    }

    // 计算某个日期可用的打卡项数量（不包含自由打卡项）
    private func availableItemsCount(for date: Date) -> Int {
        items.filter { item in
            // 自由打卡不计入待完成
            if item.isFreeType { return false }
            // 检查创建日期
            if let itemDate = parseDate(item.createdAt) {
                if calendar.compare(itemDate, to: date, toGranularity: .day) == .orderedDescending {
                    return false
                }
            }
            // 检查重复规则
            return isItemAvailableOn(item: item, date: date)
        }.count
    }

    private func isItemAvailableOn(item: CheckInItem, date: Date) -> Bool {
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
            guard let createdDate = parseDate(item.createdAt) else { return true }
            let daysSinceCreation = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdDate), to: calendar.startOfDay(for: date)).day ?? 0
            return daysSinceCreation >= 0 && daysSinceCreation % item.intervalDays == 0
        case .free:
            // 自由打卡不计入待完成
            return false
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = ["yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ", "yyyy-MM-dd HH:mm:ss.SSSSSS", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) { return date }
        }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(dateString.prefix(10)))
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

// MARK: - 日期单元格
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let completedCount: Int
    let totalCount: Int

    private let calendar = Calendar.current

    var pendingCount: Int {
        max(0, totalCount - completedCount)
    }

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isFuture {
            return Color(.systemGray6)
        } else if totalCount == 0 {
            return Color(.systemBackground)
        } else if completionRate >= 1.0 {
            return .green.opacity(0.3)
        } else if completedCount > 0 {
            return .orange.opacity(0.2)
        } else if pendingCount > 0 {
            return .red.opacity(0.1)
        } else {
            return Color(.systemBackground)
        }
    }

    var textColor: Color {
        if isSelected {
            return .white
        } else if isFuture {
            return .gray
        } else {
            return .primary
        }
    }

    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .frame(height: 44)

            // 内容层
            VStack(spacing: 2) {
                // 日期数字
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(textColor)

                // 打卡指示点
                if !isSelected && completedCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(completedCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                        }
                        if completedCount > 3 {
                            Text("+")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                        }
                    }
                } else {
                    Spacer().frame(height: 6)
                }
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - 选中日期详情
struct SelectedDateDetail: View {
    let date: Date
    let items: [CheckInItem]
    let records: [CheckInRecord]
    var onImageTap: ((String) -> Void)? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private var recordItemIds: Set<Int> {
        Set(records.map { $0.itemId })
    }

    private let calendar = Calendar.current

    // 过滤出在选中日期可用的打卡项（检查创建日期和重复规则，不包含自由打卡项）
    private var availableItems: [CheckInItem] {
        items.filter { item in
            // 自由打卡不计入待完成
            if item.isFreeType { return false }
            // 1. 检查创建日期
            if let itemDate = parseDate(item.createdAt) {
                if calendar.compare(itemDate, to: date, toGranularity: .day) == .orderedDescending {
                    return false
                }
            }

            // 2. 检查重复规则
            return isItemAvailableOn(item: item, date: date)
        }
    }

    // 已完成的自由打卡项（包括图片打卡、数值打卡等）
    private var completedFreeItems: [CheckInItem] {
        items.filter { item in
            item.isFreeType && recordItemIds.contains(item.id)
        }
    }

    // 所有要显示的打卡项（可用项 + 已完成的自由打卡项）
    private var displayItems: [CheckInItem] {
        var result = availableItems
        // 添加已完成的自由打卡项（避免重复）
        for item in completedFreeItems {
            if !result.contains(where: { $0.id == item.id }) {
                result.append(item)
            }
        }
        return result
    }

    private func isItemAvailableOn(item: CheckInItem, date: Date) -> Bool {
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
            guard let createdDate = parseDate(item.createdAt) else { return true }
            let daysSinceCreation = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdDate), to: calendar.startOfDay(for: date)).day ?? 0
            return daysSinceCreation >= 0 && daysSinceCreation % item.intervalDays == 0
        case .free:
            // 自由打卡不计入待完成
            return false
        }
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

    // 获取某个打卡项的记录
    private func recordForItem(_ item: CheckInItem) -> CheckInRecord? {
        records.first { $0.itemId == item.id }
    }

    // 格式化打卡时间
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

        // 简单截取时间部分
        if dateString.count > 11 {
            let start = dateString.index(dateString.startIndex, offsetBy: 11)
            let end = dateString.index(start, offsetBy: 5, limitedBy: dateString.endIndex) ?? dateString.endIndex
            return String(dateString[start..<end])
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.headline)

                Spacer()

                Text("\(records.count)/\(availableItems.count) 完成")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if displayItems.isEmpty {
                Text("暂无打卡项")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(displayItems) { item in
                    let record = recordForItem(item)
                    let isCompleted = record != nil

                    HStack(spacing: 8) {
                        // 状态图标
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isCompleted ? .green : .gray)

                        // 名称
                        Text(item.name)
                            .foregroundColor(isCompleted ? .primary : .gray)

                        // 数值或图片缩略图（紧跟标题）
                        if let record = record {
                            if item.checkTypeEnum == .withValue, let value = record.value {
                                // 数值显示
                                Text("\(String(format: "%.1f", value)) \(item.valueUnit ?? "")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            } else if item.checkTypeEnum == .withImage,
                                      let imageUrl = record.imageUrl, !imageUrl.isEmpty {
                                // 图片缩略图（可点击查看大图）
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
                                .onTapGesture {
                                    onImageTap?(imageUrl)
                                }
                            }
                        }

                        Spacer()

                        // 打卡时间（最右侧）
                        if let record = record, let checkedAt = record.checkedAt {
                            Text(formatTime(checkedAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if let time = item.scheduledTime, !time.isEmpty {
                            Text(time)
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
    }
}

#Preview {
    CheckInCalendarView()
}
