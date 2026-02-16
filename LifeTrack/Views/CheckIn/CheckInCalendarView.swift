import SwiftUI

// MARK: - 打卡日历视图
struct CheckInCalendarView: View {
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var items: [CheckInItem] = []
    @State private var monthRecords: [String: [CheckInRecord]] = [:] // date -> records
    @State private var isLoading = false

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
                        records: monthRecords[dateFormatter.string(from: selectedDate)] ?? []
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("打卡日历")
            .task {
                await loadItems()
                await loadMonthData()
            }
        }
    }

    private func loadItems() async {
        do {
            items = try await CheckInService.shared.getItems()
        } catch {
            print("加载打卡项失败: \(error)")
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
            let response = try await CheckInService.shared.getRecords(startDate: startStr, endDate: endStr)
            // 按日期分组（处理日期格式，只取前10个字符 YYYY-MM-DD）
            var grouped: [String: [CheckInRecord]] = [:]
            for record in response.list {
                let dateKey = String(record.checkDate.prefix(10))
                if grouped[dateKey] == nil {
                    grouped[dateKey] = []
                }
                grouped[dateKey]?.append(record)
            }
            monthRecords = grouped
        } catch {
            print("加载记录失败: \(error)")
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
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        completedCount: records[dateFormatter.string(from: date)]?.count ?? 0,
                        totalCount: items.count
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
    let completedCount: Int
    let totalCount: Int

    private let calendar = Calendar.current

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if completionRate >= 1.0 {
            return .green.opacity(0.3)
        } else if completionRate > 0 {
            return .orange.opacity(0.2)
        } else {
            return Color(.systemBackground)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))

            // 完成指示点
            if completedCount > 0 && !isSelected {
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
                Spacer()
                    .frame(height: 6)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(8)
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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private var recordItemIds: Set<Int> {
        Set(records.map { $0.itemId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.headline)

                Spacer()

                Text("\(records.count)/\(items.count) 完成")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if items.isEmpty {
                Text("暂无打卡项")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: recordItemIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(recordItemIds.contains(item.id) ? .green : .gray)

                        Text(item.name)
                            .foregroundColor(recordItemIds.contains(item.id) ? .primary : .gray)

                        Spacer()

                        if let time = item.scheduledTime, !time.isEmpty {
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
