import Foundation

struct CSVImporter {

    struct CSVReading {
        let systolic: Int
        let diastolic: Int
        let heartRate: Int
        let measuredAt: Date
    }

    enum CSVError: LocalizedError {
        case invalidFormat(line: Int)
        case noValidData
        case fileReadError

        var errorDescription: String? {
            switch self {
            case .invalidFormat(let line):
                return "第 \(line) 行格式错误"
            case .noValidData:
                return "文件中没有有效的血压数据"
            case .fileReadError:
                return "无法读取文件"
            }
        }
    }

    /// Parse CSV content string into readings
    /// Expected CSV format: date,time,period,systolic,diastolic,heart_rate
    /// Example: 2026-03-19,06:17,AM,126,93,0
    static func parse(content: String) throws -> [CSVReading] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            throw CSVError.noValidData
        }

        var readings: [CSVReading] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current

        // Skip header row
        for (index, line) in lines.dropFirst().enumerated() {
            let columns = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Expected: date, time, period, systolic, diastolic, heart_rate
            guard columns.count >= 5 else { continue }

            let dateStr = columns[0]
            let timeStr = columns[1]

            guard let systolic = Int(columns[3]),
                  let diastolic = Int(columns[4]) else {
                continue
            }

            let heartRate = columns.count >= 6 ? (Int(columns[5]) ?? 0) : 0

            // Parse datetime
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let datetimeStr = "\(dateStr) \(timeStr)"

            guard let date = dateFormatter.date(from: datetimeStr) else {
                continue
            }

            // Validate ranges
            guard systolic > 0 && systolic < 300 && diastolic > 0 && diastolic < 200 else {
                continue
            }

            readings.append(CSVReading(
                systolic: systolic,
                diastolic: diastolic,
                heartRate: heartRate,
                measuredAt: date
            ))
        }

        guard !readings.isEmpty else {
            throw CSVError.noValidData
        }

        return readings.sorted { $0.measuredAt < $1.measuredAt }
    }
}
