import Foundation
import SwiftData

@Model
final class BPReading {
    var systolic: Int
    var diastolic: Int
    var heartRate: Int
    var measuredAt: Date
    var createdAt: Date

    init(systolic: Int, diastolic: Int, heartRate: Int, measuredAt: Date) {
        self.systolic = systolic
        self.diastolic = diastolic
        self.heartRate = heartRate
        self.measuredAt = measuredAt
        self.createdAt = Date()
    }

    var classification: BPClassification {
        BPClassification.classify(systolic: systolic, diastolic: diastolic)
    }
}

enum BPClassification: String, CaseIterable {
    case normal = "正常"
    case elevated = "偏高"
    case high1 = "高血压一级"
    case high2 = "高血压二级"
    case crisis = "高血压危象"

    static func classify(systolic: Int, diastolic: Int) -> BPClassification {
        if systolic >= 180 || diastolic >= 120 {
            return .crisis
        } else if systolic >= 140 || diastolic >= 90 {
            return .high2
        } else if systolic >= 130 || diastolic >= 80 {
            return .high1
        } else if systolic >= 120 {
            return .elevated
        } else {
            return .normal
        }
    }

    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .normal:   return (0.22, 0.78, 0.35)  // green
        case .elevated: return (1.0, 0.8, 0.0)     // yellow
        case .high1:    return (1.0, 0.58, 0.0)    // orange
        case .high2:    return (1.0, 0.27, 0.23)   // red
        case .crisis:   return (0.6, 0.0, 0.0)     // dark red
        }
    }

    var rangeDescription: String {
        switch self {
        case .normal:   return "< 120 且 < 80"
        case .elevated: return "120-129 且 < 80"
        case .high1:    return "130-139 或 80-89"
        case .high2:    return "140-179 或 90-119"
        case .crisis:   return "≥ 180 或 ≥ 120"
        }
    }
}
