import SwiftUI

// MARK: - 单个打卡项详情视图（含日历）
struct CheckInItemDetailView: View {
    let item: CheckInItem

    @State private var currentMonth = Date()
    @State private var monthRecords: Set<String> = [] // 已完成的日期集合
    @State private var statistics: ItemStatistics?
    @State private var isLoading = false

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
                    completedDates: monthRecords
                )

                // 打卡记录列表
                RecentRecordsSection(itemId: item.id)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMonthData()
            await loadStatistics()
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
            // 截取日期格式为 YYYY-MM-DD
            monthRecords = Set(response.list.map { String($0.checkDate.prefix(10)) })
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
    let completedDates: Set<String>

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
                    ItemDayCell(
                        date: date,
                        isCompleted: completedDates.contains(dateFormatter.string(from: date)),
                        isToday: calendar.isDateInToday(date),
                        isFuture: date > Date()
                    )
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
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
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool

    private let calendar = Calendar.current

    var backgroundColor: Color {
        if isFuture {
            return Color(.systemGray6)
        } else if isCompleted {
            return Color.green
        } else {
            // 未完成的过去日期 - 浅红色背景
            return Color.red.opacity(0.15)
        }
    }

    var textColor: Color {
        if isFuture {
            return .gray
        } else if isCompleted {
            return .white
        } else {
            return .red.opacity(0.8)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .frame(height: 48)

            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)

                // 状态图标
                if !isFuture {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

// MARK: - 最近打卡记录
struct RecentRecordsSection: View {
    let itemId: Int

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
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        Text(record.checkDate)
                            .font(.subheadline)

                        Spacer()

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
            let response = try await CheckInService.shared.getRecords(itemId: itemId, startDate: startDate, endDate: endDate)
            records = response.list.sorted { $0.checkDate > $1.checkDate }
        } catch {
            print("加载记录失败: \(error)")
        }
    }

    private func formatTime(_ dateString: String) -> String {
        // 简化处理，实际应该解析完整时间戳
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
            isActive: true,
            createdAt: ""
        ))
    }
}
