import SwiftUI
import PhotosUI

struct CheckInView: View {
    @State private var items: [CheckInItem] = []
    @State private var dayRecords: [Int: CheckInRecord] = [:] // itemId -> record
    @State private var statistics: CheckInStatistics?
    @State private var isLoading = false
    @State private var showAddItem = false
    @State private var showCalendar = false
    @State private var errorMessage: String?
    @State private var selectedDate = Date()
    @State private var currentDateString = "" // 用于检测跨天

    // 数值输入相关
    @State private var valueInputItem: CheckInItem?
    @State private var inputValue: String = ""

    // 图片输入相关
    @State private var imageInputItem: CheckInItem?
    @State private var selectedPhoto: PhotosPickerItem?

    private let calendar = Calendar.current
    private let midnightTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect() // 每分钟检查一次

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var isFuture: Bool {
        // 比较日期部分，忽略时间
        calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: Date())
    }

    // 过滤出在选中日期可用的打卡项（检查创建日期和重复规则）
    private var availableItems: [CheckInItem] {
        items.filter { item in
            // 1. 检查创建日期
            if let itemDate = parseCreatedAt(item.createdAt) {
                if calendar.compare(itemDate, to: selectedDate, toGranularity: .day) == .orderedDescending {
                    return false  // 创建日期在选中日期之后，不显示
                }
            }

            // 2. 检查重复规则
            return isItemAvailableOn(item: item, date: selectedDate)
        }
    }

    private func isItemAvailableOn(item: CheckInItem, date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)  // 1=周日, 2=周一, ..., 7=周六

        switch item.repeatTypeEnum {
        case .daily:
            return true
        case .weekday:
            // 工作日：周一到周五 (weekday 2-6)
            return weekday >= 2 && weekday <= 6
        case .weekend:
            // 周末：周六周日 (weekday 1 或 7)
            return weekday == 1 || weekday == 7
        case .custom:
            // 自定义：检查 repeat_days（格式如 "1,3,5" 表示周一三五）
            guard let repeatDays = item.repeatDays, !repeatDays.isEmpty else { return true }
            let days = repeatDays.split(separator: ",").compactMap { Int($0) }
            // repeat_days 中 1=周一, ..., 7=周日；需要转换
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1  // 转换为 1=周一, 7=周日
            return days.contains(adjustedWeekday)
        case .interval:
            // 间隔天数：从创建日期开始，每隔 N 天
            guard let createdDate = parseCreatedAt(item.createdAt) else { return true }
            let daysSinceCreation = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdDate), to: calendar.startOfDay(for: date)).day ?? 0
            return daysSinceCreation >= 0 && daysSinceCreation % item.intervalDays == 0
        case .free:
            // 自由打卡：始终显示，但不计入待完成
            return true
        }
    }

    // 常规打卡项（需要按时完成的）
    private var regularItems: [CheckInItem] {
        availableItems.filter { !$0.isFreeType }
    }

    // 自由打卡项（不定时记录的）
    private var freeItems: [CheckInItem] {
        availableItems.filter { $0.isFreeType }
    }

    private func parseCreatedAt(_ dateString: String) -> Date? {
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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计卡片（含日期切换）- 只要有打卡项就显示，方便切换日期
                    // 注意：统计只计算常规打卡项，不包含自由打卡项
                    if items.count > 0 {
                        let regularCompletedCount = regularItems.filter { dayRecords[$0.id] != nil }.count
                        DayStatisticsCard(
                            selectedDate: $selectedDate,
                            completed: isFuture ? 0 : regularCompletedCount,
                            total: regularItems.count,
                            onDateChange: {
                                Task {
                                    await loadDayRecords()
                                }
                            }
                        )
                    }

                    // 常规打卡项（需要每天/定时完成的）
                    VStack(alignment: .leading, spacing: 12) {
                        if regularItems.isEmpty && freeItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("暂无打卡项")
                                    .foregroundColor(.gray)
                                Button("添加打卡项") {
                                    showAddItem = true
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            if !regularItems.isEmpty {
                                Text("待完成")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)

                                ForEach(regularItems) { item in
                                    let isChecked = dayRecords[item.id] != nil
                                    CheckInItemRow(
                                        item: item,
                                        isChecked: isChecked,
                                        onToggle: {
                                            Task {
                                                await toggleCheckIn(item: item)
                                            }
                                        },
                                        onTapCenter: isChecked ? nil : {
                                            Task {
                                                await toggleCheckIn(item: item)
                                            }
                                        },
                                        detailDestination: AnyView(CheckInItemDetailView(item: item, onDelete: {
                                            items.removeAll { $0.id == item.id }
                                        }))
                                    )
                                    .disabled(isFuture)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)

                    // 自由打卡项（不定时记录的，如体重）
                    if !freeItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("自由记录")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)

                            ForEach(freeItems) { item in
                                let isChecked = dayRecords[item.id] != nil
                                FreeCheckInItemRow(
                                    item: item,
                                    todayRecord: dayRecords[item.id],
                                    onRecord: {
                                        Task {
                                            await toggleCheckIn(item: item)
                                        }
                                    },
                                    onTapCenter: isChecked ? nil : {
                                        Task {
                                            await toggleCheckIn(item: item)
                                        }
                                    },
                                    detailDestination: AnyView(CheckInItemDetailView(item: item, onDelete: {
                                        items.removeAll { $0.id == item.id }
                                    }))
                                )
                                .disabled(isFuture)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("打卡")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        NavigationLink {
                            CheckInOverallStatisticsView()
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                        }

                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddCheckInItemView { item in
                    items.append(item)
                }
            }
            .sheet(isPresented: $showCalendar) {
                CheckInCalendarView()
            }
            .sheet(item: $valueInputItem) { item in
                ValueInputSheet(
                    item: item,
                    inputValue: $inputValue,
                    onSave: { value in
                        Task {
                            await doCheckIn(item: item, value: value, imageUrl: nil)
                        }
                        valueInputItem = nil
                    },
                    onCancel: {
                        valueInputItem = nil
                    }
                )
            }
            .sheet(item: $imageInputItem) { item in
                ImageInputSheet(
                    item: item,
                    selectedPhoto: $selectedPhoto,
                    onSave: { imageUrl in
                        Task {
                            await doCheckIn(item: item, value: nil, imageUrl: imageUrl)
                        }
                        imageInputItem = nil
                    },
                    onCancel: {
                        imageInputItem = nil
                    }
                )
            }
            .refreshable {
                await loadData()
            }
            .task {
                currentDateString = todayString()
                await loadData()
            }
            .onReceive(midnightTimer) { _ in
                // 检查是否跨天
                let newDateString = todayString()
                if newDateString != currentDateString {
                    currentDateString = newDateString
                    selectedDate = Date() // 重置为今天
                    Task {
                        await loadData()
                    }
                }
            }
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func loadData() async {
        isLoading = true

        // 并行加载数据
        async let itemsTask = CheckInService.shared.getItems()
        async let statsTask = CheckInService.shared.getStatistics()

        do {
            items = try await itemsTask
            // 调试：打印加载的打卡项
            for item in items {
                print("DEBUG loadData: name=\(item.name), checkType=\(item.checkType ?? -1), valueUnit=\(item.valueUnit ?? "nil")")
            }
            statistics = try await statsTask
            await loadDayRecords()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadDayRecords() async {
        do {
            let records = try await CheckInService.shared.getRecords(startDate: dateString, endDate: dateString)
            dayRecords = Dictionary(uniqueKeysWithValues: records.list.map { ($0.itemId, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleCheckIn(item: CheckInItem) async {
        if let existingRecord = dayRecords[item.id] {
            // 取消打卡
            do {
                try await CheckInService.shared.cancelCheckIn(id: existingRecord.id)
                dayRecords.removeValue(forKey: item.id)
                if isToday {
                    await loadStatistics()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            // 调试信息
            print("DEBUG: item.name=\(item.name), checkType=\(item.checkType ?? -1), checkTypeEnum=\(item.checkTypeEnum)")

            switch item.checkTypeEnum {
            case .withValue:
                // 弹出数值输入框
                print("DEBUG: 显示数值输入框 for \(item.name)")
                valueInputItem = item
                inputValue = ""
            case .withImage:
                // 弹出图片选择框
                print("DEBUG: 显示图片选择框 for \(item.name)")
                imageInputItem = item
                selectedPhoto = nil
            case .normal:
                // 普通打卡
                print("DEBUG: 普通打卡 for \(item.name)")
                await doCheckIn(item: item, value: nil, imageUrl: nil)
            }
        }
    }

    private func doCheckIn(item: CheckInItem, value: Double?, imageUrl: String? = nil) async {
        let request = CreateCheckInRecordRequest(
            itemId: item.id,
            checkDate: dateString,
            note: nil,
            imageUrl: imageUrl,
            value: value
        )
        do {
            let record = try await CheckInService.shared.checkIn(request)
            dayRecords[item.id] = record
            if isToday {
                await loadStatistics()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStatistics() async {
        do {
            statistics = try await CheckInService.shared.getStatistics()
        } catch {
            // 忽略统计加载错误
        }
    }
}

// MARK: - 当日统计卡片（含日期切换）
struct DayStatisticsCard: View {
    @Binding var selectedDate: Date
    let completed: Int
    let total: Int
    var onDateChange: () -> Void

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var isFuture: Bool {
        // 比较日期部分，忽略时间
        calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: Date())
    }

    private var dateText: String {
        if isToday {
            return "今日"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "昨日"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: selectedDate)
        }
    }

    var completionRate: Double {
        guard total > 0 && !isFuture else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 日期切换行
                HStack(spacing: 12) {
                    Button {
                        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        onDateChange()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    Text("\(dateText)完成")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Button {
                        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        onDateChange()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                // 完成数量
                if isFuture {
                    Text("--")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(completed)")
                            .font(.system(size: 36, weight: .bold))
                        Text("/\(total)")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // 环形进度
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                if !isFuture {
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(completionRate >= 1.0 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(isFuture ? "--" : "\(Int(completionRate * 100))%")
                    .font(.headline)
                    .foregroundColor(isFuture ? .gray : .primary)
            }
            .frame(width: 60, height: 60)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - 统计卡片
struct StatisticsCard: View {
    let statistics: CheckInStatistics

    var completionRate: Double {
        guard statistics.todayTotal > 0 else { return 0 }
        return Double(statistics.todayCompleted) / Double(statistics.todayTotal)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("今日完成")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(statistics.todayCompleted)")
                            .font(.system(size: 36, weight: .bold))
                        Text("/\(statistics.todayTotal)")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // 环形进度
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(completionRate * 100))%")
                        .font(.headline)
                }
                .frame(width: 60, height: 60)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - 打卡项行
struct CheckInItemRow: View {
    let item: CheckInItem
    let isChecked: Bool
    let onToggle: () -> Void
    var onTapCenter: (() -> Void)? = nil  // 点击中间区域的回调（未打卡时触发打卡）
    var detailDestination: AnyView? = nil  // 详情页

    var body: some View {
        HStack(spacing: 12) {
            // 打卡按钮
            Button(action: onToggle) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isChecked ? .green : .gray)
            }

            // 中间可点击区域（包含名称、Spacer和标签）
            if let onTapCenter = onTapCenter {
                // 未打卡时，点击中间区域触发打卡
                clickableContent
                    .onTapGesture {
                        onTapCenter()
                    }
            } else if let destination = detailDestination {
                // 已打卡时，点击中间区域跳转详情
                NavigationLink(destination: destination) {
                    clickableContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                clickableContent
            }

            // 详情箭头（始终可点击跳转详情页）
            if let destination = detailDestination {
                NavigationLink(destination: destination) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding()
        .background(isChecked ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    // 可点击的内容区域（包含名称、Spacer和标签）
    private var clickableContent: some View {
        HStack {
            centerContent

            Spacer()

            // 重复类型标签
            Text(item.repeatTypeEnum.title)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .contentShape(Rectangle())  // 扩展点击热区
    }

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(isChecked)
                    .foregroundColor(isChecked ? .gray : .primary)

                // 打卡类型图标
                if item.checkTypeEnum != .normal {
                    Image(systemName: item.checkTypeEnum.icon)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let time = item.scheduledTime, !time.isEmpty {
                Text(time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - 自由打卡项行（用于不定时记录，如体重）
struct FreeCheckInItemRow: View {
    let item: CheckInItem
    let todayRecord: CheckInRecord?
    let onRecord: () -> Void
    var onTapCenter: (() -> Void)? = nil  // 点击中间区域的回调（未打卡时触发打卡）
    var detailDestination: AnyView? = nil  // 详情页

    var body: some View {
        HStack(spacing: 12) {
            // 记录按钮
            Button(action: onRecord) {
                Image(systemName: todayRecord != nil ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 28))
                    .foregroundColor(todayRecord != nil ? .green : .orange)
            }

            // 中间可点击区域（包含名称、Spacer和标签）
            if let onTapCenter = onTapCenter {
                // 未打卡时，点击中间区域触发打卡
                clickableContent
                    .onTapGesture {
                        onTapCenter()
                    }
            } else if let destination = detailDestination {
                // 已打卡时，点击中间区域跳转详情
                NavigationLink(destination: destination) {
                    clickableContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                clickableContent
            }

            // 详情箭头（始终可点击跳转详情页）
            if let destination = detailDestination {
                NavigationLink(destination: destination) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding()
        .background(todayRecord != nil ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
        .cornerRadius(10)
    }

    // 可点击的内容区域（包含名称、Spacer和标签）
    private var clickableContent: some View {
        HStack {
            centerContent

            Spacer()

            // 自由记录标签
            Text("自由")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(4)
        }
        .contentShape(Rectangle())  // 扩展点击热区
    }

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // 打卡类型图标
                if item.checkTypeEnum != .normal {
                    Image(systemName: item.checkTypeEnum.icon)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // 显示今日记录的数值（如果有）
            if let record = todayRecord {
                if let value = record.value, let unit = item.valueUnit {
                    Text("今日: \(String(format: "%.1f", value)) \(unit)")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("今日已记录")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Text("点击记录")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - 添加打卡项视图
struct AddCheckInItemView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var scheduledTime = Date()
    @State private var hasTime = false
    @State private var repeatType: RepeatType = .daily
    @State private var checkType: CheckType = .normal
    @State private var valueUnit = ""
    @State private var remind = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedWeekdays: Set<Int> = []  // 1=周一, 7=周日
    @State private var intervalDays: Int = 2  // 间隔天数

    var onAdd: (CheckInItem) -> Void

    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("打卡项名称", text: $name)
                }

                Section("打卡类型") {
                    Picker("类型", selection: $checkType) {
                        ForEach(CheckType.allCases, id: \.rawValue) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(checkType.description)
                        .font(.caption)
                        .foregroundColor(.gray)

                    // 数值记录时需要填写单位
                    if checkType == .withValue {
                        TextField("数值单位（如 kg、步）", text: $valueUnit)
                    }
                }

                Section("时间设置") {
                    Toggle("设置打卡时间", isOn: $hasTime)

                    if hasTime {
                        DatePicker("时间", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }

                    Toggle("开启提醒", isOn: $remind)
                }

                Section {
                    Picker("重复规则", selection: $repeatType) {
                        ForEach(RepeatType.allCases, id: \.rawValue) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    Text(repeatType.description)
                        .font(.caption)
                        .foregroundColor(.gray)

                    // 自定义星期选择器
                    if repeatType == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("选择打卡日")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            HStack(spacing: 8) {
                                ForEach(1...7, id: \.self) { day in
                                    WeekdayButton(
                                        label: weekdayLabels[day - 1],
                                        isSelected: selectedWeekdays.contains(day),
                                        onTap: { toggleWeekday(day) }
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 间隔天数输入
                    if repeatType == .interval {
                        Stepper("每隔 \(intervalDays) 天", value: $intervalDays, in: 2...30)
                    }
                } header: {
                    Text("重复规则")
                } footer: {
                    if repeatType == .free {
                        Text("自由记录适合不需要每天打卡的项目，如记录体重变化")
                    } else if repeatType == .custom && selectedWeekdays.isEmpty {
                        Text("请至少选择一天")
                            .foregroundColor(.red)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("添加打卡项")
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
                            await saveItem()
                        }
                    }
                    .disabled(name.isEmpty || isLoading || (repeatType == .custom && selectedWeekdays.isEmpty))
                }
            }
        }
    }

    private func toggleWeekday(_ day: Int) {
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
    }

    private func saveItem() async {
        isLoading = true

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // 生成 repeat_days 字符串
        var repeatDays: String? = nil
        if repeatType == .custom {
            repeatDays = selectedWeekdays.sorted().map(String.init).joined(separator: ",")
        }

        let request = CreateCheckInItemRequest(
            name: name,
            scheduledTime: hasTime ? formatter.string(from: scheduledTime) : nil,
            icon: nil,
            color: nil,
            remind: remind,
            repeatType: repeatType.rawValue,
            repeatDays: repeatDays,
            intervalDays: repeatType == .interval ? intervalDays : nil,
            checkType: checkType.rawValue,
            valueUnit: checkType == .withValue ? valueUnit : nil
        )

        do {
            let item = try await CheckInService.shared.createItem(request)
            onAdd(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 星期选择按钮
struct WeekdayButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(18)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 数值输入弹窗
struct ValueInputSheet: View {
    let item: CheckInItem
    @Binding var inputValue: String
    var onSave: (Double) -> Void
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 项目名称
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                // 数值输入
                HStack(spacing: 12) {
                    TextField("输入数值", text: $inputValue)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 36, weight: .medium))
                        .multilineTextAlignment(.center)
                        .focused($isFocused)

                    if let unit = item.valueUnit, !unit.isEmpty {
                        Text(unit)
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("记录数值")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let value = Double(inputValue) {
                            onSave(value)
                        }
                    }
                    .disabled(Double(inputValue) == nil)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.height(280)])
    }
}

// MARK: - 图片输入弹窗
struct ImageInputSheet: View {
    let item: CheckInItem
    @Binding var selectedPhoto: PhotosPickerItem?
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 项目名称
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                // 图片预览或选择器
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)

                    // 重新选择按钮
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text("重新选择")
                            .foregroundColor(.blue)
                    }
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                            Text("选择图片")
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("上传图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await uploadAndSave()
                        }
                    }
                    .disabled(selectedImage == nil || isUploading)
                }
            }
            .overlay {
                if isUploading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("上传中...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: selectedPhoto) { newValue in
            Task {
                await loadImage(from: newValue)
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                selectedImage = uiImage
            }
        } catch {
            errorMessage = "加载图片失败"
        }
    }

    private func uploadAndSave() async {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "图片处理失败"
            return
        }

        isUploading = true
        errorMessage = nil

        do {
            let imageUrl = try await CheckInService.shared.uploadImage(imageData: imageData)
            onSave(imageUrl)
        } catch {
            errorMessage = "上传失败: \(error)"
        }

        isUploading = false
    }
}

#Preview {
    CheckInView()
}
