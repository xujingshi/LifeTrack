import SwiftUI
import Charts

// MARK: - 综合统计视图
struct CheckInOverallStatisticsView: View {
    @State private var overallStats: OverallStatistics?
    @State private var isLoading = true
    @State private var selectedPeriod: StatisticsPeriod = .week

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let stats = overallStats {
                VStack(spacing: 20) {
                    // 总览卡片
                    OverviewCard(stats: stats)

                    // 周期选择
                    Picker("统计周期", selection: $selectedPeriod) {
                        ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 趋势图表
                    TrendChartCard(trendData: stats.trendData, period: selectedPeriod)

                    // 打卡项排行榜
                    ItemRankingCard(rankings: stats.itemRankings)

                    // 习惯分析
                    HabitAnalysisCard(stats: stats)
                }
                .padding()
            } else {
                Text("暂无统计数据")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("打卡统计")
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
        do {
            overallStats = try await CheckInService.shared.getOverallStatistics(period: selectedPeriod.rawValue)
        } catch {
            print("加载统计失败: \(error)")
        }
        isLoading = false
    }
}

// MARK: - 统计周期
enum StatisticsPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"

    var title: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "今年"
        }
    }
}

// MARK: - 总览卡片
struct OverviewCard: View {
    let stats: OverallStatistics

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("总览")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                OverviewItem(
                    title: "总打卡",
                    value: "\(stats.totalCheckIns)",
                    unit: "次",
                    color: .blue
                )

                Divider().frame(height: 50)

                OverviewItem(
                    title: "活跃天数",
                    value: "\(stats.activeDays)",
                    unit: "天",
                    color: .green
                )

                Divider().frame(height: 50)

                OverviewItem(
                    title: "完成率",
                    value: String(format: "%.0f", stats.completionRate * 100),
                    unit: "%",
                    color: .orange
                )

                Divider().frame(height: 50)

                OverviewItem(
                    title: "连续",
                    value: "\(stats.currentStreak)",
                    unit: "天",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct OverviewItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 趋势图表卡片
struct TrendChartCard: View {
    let trendData: [DailyTrend]
    let period: StatisticsPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡趋势")
                .font(.headline)

            if trendData.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(trendData) { item in
                    BarMark(
                        x: .value("日期", item.displayDate),
                        y: .value("完成", item.completed)
                    )
                    .foregroundStyle(Color.green.gradient)

                    if item.total > item.completed {
                        BarMark(
                            x: .value("日期", item.displayDate),
                            y: .value("未完成", item.total - item.completed)
                        )
                        .foregroundStyle(Color.gray.opacity(0.3).gradient)
                    }
                }
                .frame(height: 180)
                .chartYAxisLabel("打卡数")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - 打卡项排行榜
struct ItemRankingCard: View {
    let rankings: [ItemRanking]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡项排行")
                .font(.headline)

            if rankings.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(rankings.enumerated()), id: \.element.itemId) { index, item in
                    HStack(spacing: 12) {
                        // 排名
                        ZStack {
                            Circle()
                                .fill(rankColor(index))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // 名称
                        Text(item.itemName)
                            .font(.subheadline)

                        Spacer()

                        // 完成率进度条
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(rankColor(index))
                                    .frame(width: geo.size.width * item.completionRate, height: 8)
                            }
                        }
                        .frame(width: 80, height: 8)

                        // 完成率数字
                        Text(String(format: "%.0f%%", item.completionRate * 100))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .trailing)
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

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .gray
        case 2: return .brown
        default: return .blue
        }
    }
}

// MARK: - 习惯分析卡片
struct HabitAnalysisCard: View {
    let stats: OverallStatistics

    private let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡习惯")
                .font(.headline)

            HStack(spacing: 20) {
                // 最佳打卡日
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.green)
                        Text("最佳打卡日")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Text(stats.bestWeekday >= 0 && stats.bestWeekday < 7 ? weekdays[stats.bestWeekday] : "-")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 50)

                // 最长连续
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("最长连续")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(stats.longestStreak)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("天")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 每周打卡分布
            if !stats.weekdayDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("每周分布")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let count = stats.weekdayDistribution[day]
                            let maxCount = stats.weekdayDistribution.max() ?? 1
                            let height = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) * 40 + 10 : 10

                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(day == stats.bestWeekday ? Color.green : Color.blue.opacity(0.6))
                                    .frame(height: height)

                                Text(String(weekdays[day].last!))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 70)
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
    NavigationView {
        CheckInOverallStatisticsView()
    }
}
