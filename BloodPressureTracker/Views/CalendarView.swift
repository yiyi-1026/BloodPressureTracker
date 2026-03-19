import SwiftUI

struct CalendarView: View {
    @Environment(DataStore.self) private var store
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showDeleteAlert = false
    @State private var readingToDelete: BPReading?

    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Int?] {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1 // 0-based Sunday

        var days: [Int?] = Array(repeating: nil, count: firstWeekday)
        days += range.map { Optional($0) }
        return days
    }

    private var datesWithData: Set<Int> {
        store.datesWithReadings(in: currentMonth)
    }

    private var selectedDateReadings: [BPReading] {
        store.readingsForDate(selectedDate)
    }

    private var isToday: (Int) -> Bool {
        { day in
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) else { return false }
            return calendar.isDateInToday(date)
        }
    }

    private var isSelectedDay: (Int) -> Bool {
        { day in
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }

    private var remainingDaysInMonth: Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return 0
        }
        let today = calendar.component(.day, from: Date())
        let sameMonth = calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
        return sameMonth ? max(0, range.count - today) : range.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title
                Text("血压记录")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // Stats cards
                HStack(spacing: 12) {
                    StatCard(title: "总记录", value: "\(store.totalCount())", icon: "list.bullet")
                    StatCard(title: "本月", value: "\(store.monthCount(for: currentMonth))", icon: "calendar")
                    StatCard(title: "剩余天数", value: "\(remainingDaysInMonth)", icon: "clock")
                }
                .padding(.horizontal)

                // Month navigation
                HStack {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text(monthString)
                        .font(.headline)
                    Spacer()
                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 24)
                
                // Back to today button
                if !calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month) {
                    Button {
                        backToToday()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle.fill")
                            Text("回到今天")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Weekday headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                        if let day {
                            CalendarDayCell(
                                day: day,
                                hasData: datesWithData.contains(day),
                                isToday: isToday(day),
                                isSelected: isSelectedDay(day)
                            )
                            .onTapGesture { selectDay(day) }
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal)

                // Selected date readings
                if !selectedDateReadings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        let formatter = { () -> DateFormatter in
                            let f = DateFormatter()
                            f.locale = Locale(identifier: "zh_CN")
                            f.dateFormat = "M月d日 EEEE"
                            return f
                        }()
                        Text(formatter.string(from: selectedDate))
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(selectedDateReadings) { reading in
                                ReadingRow(reading: reading) {
                                    readingToDelete = reading
                                    showDeleteAlert = true
                                }
                                if reading.id != selectedDateReadings.last?.id {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "heart.text.clipboard")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("该日期暂无记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                }

                // Tip
                Text("建议每天在固定时间测量血压")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 20)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let reading = readingToDelete {
                    withAnimation { store.deleteReading(reading) }
                }
            }
        } message: {
            Text("确定要删除这条血压记录吗？")
        }
    }

    private func changeMonth(_ offset: Int) {
        withAnimation {
            if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
                currentMonth = newMonth
            }
        }
    }
    
    private func backToToday() {
        withAnimation {
            currentMonth = Date()
            selectedDate = Date()
        }
    }

    private func selectDay(_ day: Int) {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        if let date = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) {
            withAnimation { selectedDate = date }
        }
    }
}

// MARK: - Supporting Views

struct CalendarDayCell: View {
    let day: Int
    let hasData: Bool
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)

            Circle()
                .strokeBorder(isToday ? Color.blue : Color.clear, lineWidth: 2)

            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                if hasData {
                    Text("✓")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(" ")
                        .font(.system(size: 8))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}
