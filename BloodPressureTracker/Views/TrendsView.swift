import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedDays = 1
    @State private var showCustomDatePicker = false
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var isCustomRange = false
    @State private var selectedReading: BPReading?

    private let dayOptions = [
        (label: "1天", value: 1),
        (label: "5天", value: 5),
        (label: "10天", value: 10),
    ]

    private var readings: [BPReading] {
        if isCustomRange {
            return store.readingsForDateRange(from: customStartDate, to: customEndDate)
        }
        return store.readingsForDays(selectedDays)
    }

    private var averages: DataStore.Averages {
        store.averages(for: readings)
    }

    private var weeklyData: [DataStore.WeeklyData] {
        store.weeklyAverages(for: readings)
    }

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

    // Dynamic Y axis range for BP chart
    private var bpYDomain: ClosedRange<Int> {
        guard !readings.isEmpty else { return 40...200 }
        let maxSys = readings.map(\.systolic).max() ?? 160
        let minDia = readings.map(\.diastolic).min() ?? 60
        let lower = max(0, minDia - 20)
        let upper = maxSys + 20
        return lower...upper
    }

    // Dynamic Y axis range for HR chart
    private var hrYDomain: ClosedRange<Int> {
        guard !readings.isEmpty else { return 40...160 }
        let maxHR = readings.map(\.heartRate).max() ?? 100
        let minHR = readings.map(\.heartRate).min() ?? 50
        let lower = max(0, minHR - 15)
        let upper = maxHR + 15
        return lower...upper
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
                            withAnimation {
                                isCustomRange = false
                                selectedDays = option.value
                            }
                        } label: {
                            Text(option.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(!isCustomRange && selectedDays == option.value ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(!isCustomRange && selectedDays == option.value ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }

                    Button {
                        showCustomDatePicker = true
                    } label: {
                        Text("自选")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isCustomRange ? Color.accentColor : Color(.systemGray5))
                            .foregroundStyle(isCustomRange ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                // Custom date range display
                if isCustomRange {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(formatDateRange(customStartDate, customEndDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

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
        .sheet(isPresented: $showCustomDatePicker) {
            CustomDateRangePicker(
                startDate: $customStartDate,
                endDate: $customEndDate,
                onConfirm: {
                    isCustomRange = true
                    showCustomDatePicker = false
                },
                onCancel: {
                    showCustomDatePicker = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    // MARK: - Summary Cards

    @ViewBuilder
    private var summaryCards: some View {
        HStack(spacing: 12) {
            TrendCard(
                title: "血压",
                icon: "heart.fill",
                iconColor: .accentColor,
                mainValue: String(format: "%.0f/%.0f", averages.systolic, averages.diastolic),
                unit: "mmHg",
                trend: bpTrend.map { ($0.recent - $0.older, "mmHg") }
            )

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

            // Selected reading tooltip
            if let selected = selectedReading {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDateTime(selected.measuredAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("收缩压: \(selected.systolic)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                            Text("舒张压: \(selected.diastolic)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.cyan)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation { selectedReading = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            Chart {
                ForEach(readings) { reading in
                    LineMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("收缩压", reading.systolic),
                        series: .value("类型", "收缩压")
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(selectedReading?.id == reading.id ? Color.accentColor : Color.accentColor.opacity(0.7))
                            .frame(width: selectedReading?.id == reading.id ? 8 : 5)
                    }

                    LineMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("舒张压", reading.diastolic),
                        series: .value("类型", "舒张压")
                    )
                    .foregroundStyle(Color.cyan)
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(selectedReading?.id == reading.id ? Color.cyan : Color.cyan.opacity(0.7))
                            .frame(width: selectedReading?.id == reading.id ? 8 : 5)
                    }
                }

                // Selected point vertical line
                if let selected = selectedReading {
                    RuleMark(x: .value("选中", selected.measuredAt))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
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
            .chartYScale(domain: bpYDomain)
            .chartLegend(position: .bottom)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let x = value.location.x
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    // Find nearest reading
                                    let nearest = readings.min { a, b in
                                        abs(a.measuredAt.timeIntervalSince(date)) < abs(b.measuredAt.timeIntervalSince(date))
                                    }
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedReading = nearest
                                    }
                                }
                        )
                }
            }
            .frame(height: 220)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .padding(.horizontal)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
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
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("时间", reading.measuredAt),
                        y: .value("心率", reading.heartRate)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle())
                    .symbolSize(20)
                }

                if averages.count > 0 {
                    RuleMark(y: .value("平均心率", averages.heartRate))
                        .foregroundStyle(.red.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartYScale(domain: hrYDomain)
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

// MARK: - Custom Date Range Picker

struct CustomDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("选择日期范围")
                    .font(.headline)
                    .padding(.top)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("起始日期")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("结束日期")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                // Quick presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("快速选择")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    HStack(spacing: 10) {
                        QuickDateButton(label: "近1周") {
                            startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                            endDate = Date()
                        }
                        QuickDateButton(label: "近1月") {
                            startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            endDate = Date()
                        }
                        QuickDateButton(label: "近3月") {
                            startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                            endDate = Date()
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { onConfirm() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct QuickDateButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
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
