import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedDays = 7

    private let dayOptions = [
        (label: "7天", value: 7),
        (label: "30天", value: 30),
        (label: "90天", value: 90),
        (label: "全部", value: 0),
    ]

    private var readings: [BPReading] {
        store.readingsForDays(selectedDays)
    }

    private var averages: DataStore.Averages {
        store.averages(for: readings)
    }

    private var weeklyData: [DataStore.WeeklyData] {
        store.weeklyAverages(for: readings)
    }

    // Trend comparison: recent week vs older weeks
    private var bpTrend: (recent: Double, older: Double)? {
        guard weeklyData.count >= 2 else { return nil }
        let recent = weeklyData.last!.avgSystolic
        let older = weeklyData.dropLast().map(\.avgSystolic).reduce(0, +) / Double(weeklyData.count - 1)
        return (recent, older)
    }

    private var hrTrend: (recent: Double, older: Double)? {
        guard weeklyData.count >= 2 else { return nil }
        let recent = weeklyData.last!.avgHeartRate
        let older = weeklyData.dropLast().map(\.avgHeartRate).reduce(0, +) / Double(weeklyData.count - 1)
        return (recent, older)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title
                Text("趋势分析")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // Time filter
                HStack(spacing: 8) {
                    ForEach(dayOptions, id: \.value) { option in
                        Button {
                            withAnimation { selectedDays = option.value }
                        } label: {
                            Text(option.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedDays == option.value ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(selectedDays == option.value ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)

                if readings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("暂无数据")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("添加血压记录后即可查看趋势")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 60)
                } else {
                    // Summary cards
                    summaryCards

                    // BP Chart
                    bpChart

                    // HR Chart
                    hrChart

                    // Weekly averages table
                    weeklyTable
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Summary Cards

    @ViewBuilder
    private var summaryCards: some View {
        HStack(spacing: 12) {
            // BP trend card
            TrendCard(
                title: "血压",
                icon: "heart.fill",
                iconColor: .accentColor,
                mainValue: String(format: "%.0f/%.0f", averages.systolic, averages.diastolic),
                unit: "mmHg",
                trend: bpTrend.map { ($0.recent - $0.older, "mmHg") }
            )

            // HR trend card
            TrendCard(
                title: "心率",
                icon: "waveform.path.ecg",
                iconColor: .red,
                mainValue: String(format: "%.0f", averages.heartRate),
                unit: "bpm",
                trend: hrTrend.map { ($0.recent - $0.older, "bpm") }
            )
        }
        .padding(.horizontal)

        // Overall card
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.accentColor)
                Text("总览")
                    .font(.headline)
                Spacer()
                Text("共 \(averages.count) 条记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                VStack {
                    Text(String(format: "%.0f", averages.systolic))
                        .font(.title3).fontWeight(.bold)
                    Text("收缩压").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f", averages.diastolic))
                        .font(.title3).fontWeight(.bold)
                    Text("舒张压").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f", averages.heartRate))
                        .font(.title3).fontWeight(.bold).foregroundStyle(.red)
                    Text("心率").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .padding(.horizontal)
    }

    // MARK: - BP Chart

    @ViewBuilder
    private var bpChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("血压趋势")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(readings) { reading in
                    LineMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("收缩压", reading.systolic),
                        series: .value("类型", "收缩压")
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbol(Circle())
                    .symbolSize(20)

                    LineMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("舒张压", reading.diastolic),
                        series: .value("类型", "舒张压")
                    )
                    .foregroundStyle(Color.cyan)
                    .symbol(Circle())
                    .symbolSize(20)
                }

                // Hypertension threshold line
                RuleMark(y: .value("高血压线", 140))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("140")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }

                // Average lines
                if averages.count > 0 {
                    RuleMark(y: .value("平均收缩压", averages.systolic))
                        .foregroundStyle(Color.accentColor.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    RuleMark(y: .value("平均舒张压", averages.diastolic))
                        .foregroundStyle(Color.cyan.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartYScale(domain: 40...200)
            .chartLegend(position: .bottom)
            .frame(height: 220)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .padding(.horizontal)
    }

    // MARK: - HR Chart

    @ViewBuilder
    private var hrChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("心率趋势")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(readings) { reading in
                    AreaMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("心率", reading.heartRate)
                    )
                    .foregroundStyle(.red.opacity(0.1))

                    LineMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("心率", reading.heartRate)
                    )
                    .foregroundStyle(.red)
                    .symbol(Circle())
                    .symbolSize(20)
                }

                if averages.count > 0 {
                    RuleMark(y: .value("平均心率", averages.heartRate))
                        .foregroundStyle(.red.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartYScale(domain: 40...160)
            .frame(height: 180)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .padding(.horizontal)
    }

    // MARK: - Weekly Table

    @ViewBuilder
    private var weeklyTable: some View {
        if !weeklyData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("每周平均")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("周").fontWeight(.semibold).frame(width: 80, alignment: .leading)
                        Text("次数").fontWeight(.semibold).frame(width: 36)
                        Text("收缩压").fontWeight(.semibold).frame(maxWidth: .infinity)
                        Text("舒张压").fontWeight(.semibold).frame(maxWidth: .infinity)
                        Text("心率").fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    ForEach(weeklyData) { week in
                        HStack {
                            Text(week.weekLabel)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                            Text("\(week.count)")
                                .font(.caption)
                                .frame(width: 36)
                            Text(String(format: "%.0f", week.avgSystolic))
                                .font(.caption).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                            Text(String(format: "%.0f", week.avgDiastolic))
                                .font(.caption).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                            Text(String(format: "%.0f", week.avgHeartRate))
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        if week.id != weeklyData.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Trend Card

struct TrendCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let mainValue: String
    let unit: String
    let trend: (change: Double, unit: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text(mainValue)
                .font(.title2)
                .fontWeight(.bold)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let trend {
                HStack(spacing: 2) {
                    Image(systemName: trend.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.0f %@", trend.change, trend.unit))
                        .font(.caption)
                }
                .foregroundStyle(trend.change >= 0 ? .red : .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}
