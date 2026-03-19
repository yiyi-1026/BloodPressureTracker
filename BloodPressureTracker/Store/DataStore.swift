import Foundation
import Foundation
import SwiftData
import SwiftUI

@Observable
final class DataStore {
    var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    func addReading(systolic: Int, diastolic: Int, heartRate: Int, measuredAt: Date) {
        let reading = BPReading(systolic: systolic, diastolic: diastolic, heartRate: heartRate, measuredAt: measuredAt)
        modelContext.insert(reading)
        try? modelContext.save()
    }
    
    func importReadings(_ readings: [ImportedReading]) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0

        let existingReadings = fetchAll()
        let existingDates = Set(existingReadings.map { $0.measuredAt })

        for reading in readings {
            if existingDates.contains(reading.measuredAt) {
                skipped += 1
                continue
            }

            let newReading = BPReading(
                systolic: reading.systolic,
                diastolic: reading.diastolic,
                heartRate: reading.heartRate,
                measuredAt: reading.measuredAt
            )
            modelContext.insert(newReading)
            imported += 1
        }

        try? modelContext.save()
        return (imported, skipped)
    }

    func importCSVReadings(_ readings: [CSVImporter.CSVReading]) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0

        let existingReadings = fetchAll()
        let existingDates = Set(existingReadings.map { $0.measuredAt })

        for reading in readings {
            if existingDates.contains(reading.measuredAt) {
                skipped += 1
                continue
            }

            let newReading = BPReading(
                systolic: reading.systolic,
                diastolic: reading.diastolic,
                heartRate: reading.heartRate,
                measuredAt: reading.measuredAt
            )
            modelContext.insert(newReading)
            imported += 1
        }

        try? modelContext.save()
        return (imported, skipped)
    }

    func deleteReading(_ reading: BPReading) {
        modelContext.delete(reading)
        try? modelContext.save()
    }

    func fetchAll() -> [BPReading] {
        let descriptor = FetchDescriptor<BPReading>(sortBy: [SortDescriptor(\.measuredAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Queries

    func readingsForDate(_ date: Date) -> [BPReading] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        let predicate = #Predicate<BPReading> { r in
            r.measuredAt >= start && r.measuredAt < end
        }
        let descriptor = FetchDescriptor<BPReading>(predicate: predicate, sortBy: [SortDescriptor(\.measuredAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func datesWithReadings(in month: Date) -> Set<Int> {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        let predicate = #Predicate<BPReading> { r in
            r.measuredAt >= startOfMonth && r.measuredAt < endOfMonth
        }
        let descriptor = FetchDescriptor<BPReading>(predicate: predicate)
        let readings = (try? modelContext.fetch(descriptor)) ?? []
        return Set(readings.map { calendar.component(.day, from: $0.measuredAt) })
    }

    func readingsForDateRange(from startDate: Date, to endDate: Date) -> [BPReading] {
        let start = Calendar.current.startOfDay(for: startDate)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) else {
            return []
        }
        let predicate = #Predicate<BPReading> { r in
            r.measuredAt >= start && r.measuredAt < end
        }
        let descriptor = FetchDescriptor<BPReading>(predicate: predicate, sortBy: [SortDescriptor(\.measuredAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func readingsForDays(_ days: Int) -> [BPReading] {
        if days == 0 {
            return fetchAll()
        }
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }
        let predicate = #Predicate<BPReading> { r in
            r.measuredAt >= start
        }
        let descriptor = FetchDescriptor<BPReading>(predicate: predicate, sortBy: [SortDescriptor(\.measuredAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func totalCount() -> Int {
        let descriptor = FetchDescriptor<BPReading>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func monthCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return 0
        }
        let predicate = #Predicate<BPReading> { r in
            r.measuredAt >= startOfMonth && r.measuredAt < endOfMonth
        }
        let descriptor = FetchDescriptor<BPReading>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Statistics

    struct Averages {
        var systolic: Double
        var diastolic: Double
        var heartRate: Double
        var count: Int
    }

    func averages(for readings: [BPReading]) -> Averages {
        guard !readings.isEmpty else {
            return Averages(systolic: 0, diastolic: 0, heartRate: 0, count: 0)
        }
        let count = Double(readings.count)
        return Averages(
            systolic: readings.map { Double($0.systolic) }.reduce(0, +) / count,
            diastolic: readings.map { Double($0.diastolic) }.reduce(0, +) / count,
            heartRate: readings.map { Double($0.heartRate) }.reduce(0, +) / count,
            count: readings.count
        )
    }

    struct WeeklyData: Identifiable {
        let id = UUID()
        let weekLabel: String
        let avgSystolic: Double
        let avgDiastolic: Double
        let avgHeartRate: Double
        let count: Int
    }

    func weeklyAverages(for readings: [BPReading]) -> [WeeklyData] {
        let calendar = Calendar.current
        var grouped: [String: [BPReading]] = [:]

        for reading in readings {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reading.measuredAt)
            guard let year = components.yearForWeekOfYear,
                  let week = components.weekOfYear else {
                continue
            }
            let key = String(format: "%04d-W%02d", year, week)
            grouped[key, default: []].append(reading)
        }

        return grouped.sorted { $0.key < $1.key }.map { key, readings in
            let avg = averages(for: readings)
            return WeeklyData(
                weekLabel: key,
                avgSystolic: avg.systolic,
                avgDiastolic: avg.diastolic,
                avgHeartRate: avg.heartRate,
                count: readings.count
            )
        }
    }
}
