import SwiftUI
import Charts

// MARK: - 打卡统计视图
struct CheckInStatisticsView: View {
    let item: CheckInItem

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var statistics: DetailedStatistics?
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum StatsPeriod: String, CaseIterable {
        case week = "week"
        case month = "month"
        case year = "year"

        var title: String {
            switch self {
            case .week: return "近7天"
            case .month: return "近30天"
            case .year: return "近一年"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 周期选择器
                Picker("统计周期", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.rawValue) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .padding(.vertical, 40)
                } else if let stats = statistics {
                    // 概要卡片
                    SummaryCard(statistics: stats)

                    // 趋势图表
                    TrendChartView(trendData: stats.trendData, item: item)

                    // 数值分析（仅数值型打卡）
                    if item.needsNumberInput, stats.avgValue != nil {
                        ValueAnalysisCard(statistics: stats, unit: item.valueUnit ?? "")
                    }

                    // 打卡习惯卡片
                    if !stats.bestDay.isEmpty {
                        HabitCard(bestDay: stats.bestDay)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("详细统计")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStatistics()
        }
        .onChange(of: selectedPeriod) { _ in
            Task {
                await loadStatistics()
            }
        }
    }

    private func loadStatistics() async {
        isLoading = true
        errorMessage = nil

        do {
            statistics = try await CheckInService.shared.getDetailedStatistics(
                itemId: item.id,
                period: selectedPeriod.rawValue
            )
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - 概要卡片
struct SummaryCard: View {
    let statistics: DetailedStatistics

    var body: some View {
        VStack(spacing: 16) {
            // 完成率环形图
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: statistics.completionRate / 100)
                        .stroke(statistics.completionRate >= 80 ? Color.green : Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(statistics.completionRate))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("完成率")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 100, height: 100)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("已完成")
                            .foregroundColor(.gray)
                        Text("\(statistics.completedDays)")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("天")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("应完成")
                            .foregroundColor(.gray)
                        Text("\(statistics.totalDays)")
                            .fontWeight(.bold)
                        Text("天")
                            .foregroundColor(.gray)
                    }
                }
            }

            Divider()

            // 连续天数
            HStack {
                VStack(spacing: 4) {
                    Text("\(statistics.currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("当前连续")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("\(statistics.longestStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("最长连续")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - 趋势图表
struct TrendChartView: View {
    let trendData: [TrendDataPoint]
    let item: CheckInItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡趋势")
                .font(.headline)

            if item.needsNumberInput {
                // 数值型：折线图
                Chart(trendData) { point in
                    if let value = point.value {
                        LineMark(
                            x: .value("日期", formatDate(point.date)),
                            y: .value("数值", value)
                        )
                        .foregroundStyle(Color.blue)

                        PointMark(
                            x: .value("日期", formatDate(point.date)),
                            y: .value("数值", value)
                        )
                        .foregroundStyle(Color.blue)
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel(item.valueUnit ?? "")
            } else {
                // 普通型：柱状图
                Chart(trendData) { point in
                    BarMark(
                        x: .value("日期", formatDate(point.date)),
                        y: .value("完成", point.completed)
                    )
                    .foregroundStyle(point.completed > 0 ? Color.green : Color.red.opacity(0.3))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func formatDate(_ dateString: String) -> String {
        // 只显示日期的月/日部分
        let parts = dateString.split(separator: "-")
        if parts.count >= 3 {
            return "\(parts[1])/\(parts[2])"
        }
        return dateString
    }
}

// MARK: - 数值分析卡片
struct ValueAnalysisCard: View {
    let statistics: DetailedStatistics
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数值分析")
                .font(.headline)

            HStack {
                ValueStatItem(
                    title: "平均值",
                    value: statistics.avgValue,
                    unit: unit,
                    color: .blue
                )

                Spacer()

                ValueStatItem(
                    title: "最大值",
                    value: statistics.maxValue,
                    unit: unit,
                    color: .green
                )

                Spacer()

                ValueStatItem(
                    title: "最小值",
                    value: statistics.minValue,
                    unit: unit,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct ValueStatItem: View {
    let title: String
    let value: Double?
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            if let v = value {
                Text("\(String(format: "%.1f", v))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("-")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - 打卡习惯卡片
struct HabitCard: View {
    let bestDay: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡习惯")
                .font(.headline)

            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("最佳打卡日")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(bestDay)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

#Preview {
    NavigationView {
        CheckInStatisticsView(item: CheckInItem(
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
            contentType: nil,
            allowImage: nil,
            valueUnit: nil,
            isActive: true,
            createdAt: ""
        ))
    }
}
