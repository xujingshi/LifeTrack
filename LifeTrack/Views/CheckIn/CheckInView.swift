import SwiftUI

struct CheckInView: View {
    @State private var items: [CheckInItem] = []
    @State private var dayRecords: [Int: CheckInRecord] = [:] // itemId -> record
    @State private var statistics: CheckInStatistics?
    @State private var isLoading = false
    @State private var showAddItem = false
    @State private var showCalendar = false
    @State private var errorMessage: String?
    @State private var selectedDate = Date()

    private let calendar = Calendar.current

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var isFuture: Bool {
        selectedDate > Date()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计卡片（含日期切换）
                    if items.count > 0 {
                        DayStatisticsCard(
                            selectedDate: $selectedDate,
                            completed: isFuture ? 0 : dayRecords.count,
                            total: items.count,
                            onDateChange: {
                                Task {
                                    await loadDayRecords()
                                }
                            }
                        )
                    }

                    // 当日打卡
                    VStack(alignment: .leading, spacing: 12) {
                        if items.isEmpty {
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
                            ForEach(items) { item in
                                NavigationLink(destination: CheckInItemDetailView(item: item)) {
                                    CheckInItemRow(
                                        item: item,
                                        isChecked: dayRecords[item.id] != nil,
                                        onToggle: {
                                            Task {
                                                await toggleCheckIn(item: item)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isFuture)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
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
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
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
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true

        // 并行加载数据
        async let itemsTask = CheckInService.shared.getItems()
        async let statsTask = CheckInService.shared.getStatistics()

        do {
            items = try await itemsTask
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
            // 打卡
            let request = CreateCheckInRecordRequest(
                itemId: item.id,
                checkDate: dateString,
                note: nil
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
        selectedDate > Date()
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

    var body: some View {
        HStack(spacing: 12) {
            // 打卡按钮
            Button(action: onToggle) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(isChecked ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(isChecked)
                    .foregroundColor(isChecked ? .gray : .primary)

                if let time = item.scheduledTime, !time.isEmpty {
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // 重复类型标签
            Text(item.repeatTypeEnum.title)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)

            // 详情箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(isChecked ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - 添加打卡项视图
struct AddCheckInItemView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var scheduledTime = Date()
    @State private var hasTime = false
    @State private var repeatType: RepeatType = .daily
    @State private var remind = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onAdd: (CheckInItem) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("打卡项名称", text: $name)
                }

                Section("时间设置") {
                    Toggle("设置打卡时间", isOn: $hasTime)

                    if hasTime {
                        DatePicker("时间", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }

                    Toggle("开启提醒", isOn: $remind)
                }

                Section("重复规则") {
                    Picker("重复", selection: $repeatType) {
                        ForEach(RepeatType.allCases.filter { $0 != .custom && $0 != .interval }, id: \.rawValue) { type in
                            Text(type.title).tag(type)
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
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func saveItem() async {
        isLoading = true

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let request = CreateCheckInItemRequest(
            name: name,
            scheduledTime: hasTime ? formatter.string(from: scheduledTime) : nil,
            icon: nil,
            color: nil,
            remind: remind,
            repeatType: repeatType.rawValue,
            repeatDays: nil,
            intervalDays: nil
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

#Preview {
    CheckInView()
}
