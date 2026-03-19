import Foundation
import HealthKit

@Observable
final class HealthKitManager {
    private let healthStore = HKHealthStore()
    var isAuthorized = false
    var authorizationError: String?
    
    // 检查 HealthKit 是否可用
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // 请求授权
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            authorizationError = "此设备不支持健康数据"
            return false
        }
        
        // 定义需要读取的数据类型
        guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            authorizationError = "无法访问健康数据类型"
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [systolicType, diastolicType, heartRateType]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            authorizationError = nil
            return true
        } catch {
            authorizationError = "授权失败: \(error.localizedDescription)"
            return false
        }
    }
    
    // 导入血压数据
    func importBloodPressureData() async throws -> [ImportedReading] {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            throw HealthKitError.typeNotAvailable
        }
        
        // 创建查询条件 - 获取所有血压数据
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // 查询收缩压数据
        let systolicSamples = try await querySamples(for: systolicType, predicate: predicate, sortDescriptor: sortDescriptor)
        
        // 查询舒张压数据
        let diastolicSamples = try await querySamples(for: diastolicType, predicate: predicate, sortDescriptor: sortDescriptor)
        
        // 将数据配对
        return try await pairBloodPressureReadings(systolic: systolicSamples, diastolic: diastolicSamples)
    }
    
    // 查询样本数据
    private func querySamples(for type: HKQuantityType, predicate: NSPredicate, sortDescriptor: NSSortDescriptor) async throws -> [HKQuantitySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let quantitySamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: quantitySamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // 配对收缩压和舒张压数据
    private func pairBloodPressureReadings(systolic: [HKQuantitySample], diastolic: [HKQuantitySample]) async throws -> [ImportedReading] {
        var readings: [ImportedReading] = []
        
        // 创建舒张压字典，按时间索引
        var diastolicByTime: [Date: HKQuantitySample] = [:]
        for sample in diastolic {
            diastolicByTime[sample.startDate] = sample
        }
        
        // 配对数据
        for systolicSample in systolic {
            // 查找相同时间的舒张压数据
            if let diastolicSample = diastolicByTime[systolicSample.startDate] {
                let systolicValue = Int(systolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                let diastolicValue = Int(diastolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury()))
                
                // 尝试获取心率数据
                let heartRate = try? await fetchHeartRate(around: systolicSample.startDate)
                
                readings.append(ImportedReading(
                    systolic: systolicValue,
                    diastolic: diastolicValue,
                    heartRate: heartRate ?? 60, // 如果没有心率数据，默认为 60
                    measuredAt: systolicSample.startDate
                ))
            }
        }
        
        return readings
    }
    
    // 获取指定时间附近的心率数据（前后5分钟内）
    private func fetchHeartRate(around date: Date) async throws -> Int? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        
        let fiveMinutesBefore = date.addingTimeInterval(-300)
        let fiveMinutesAfter = date.addingTimeInterval(300)
        
        let predicate = HKQuery.predicateForSamples(withStart: fiveMinutesBefore, end: fiveMinutesAfter, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await querySamples(for: heartRateType, predicate: predicate, sortDescriptor: sortDescriptor)
        
        // 找到最接近测量时间的心率数据
        let closestSample = samples.min { sample1, sample2 in
            abs(sample1.startDate.timeIntervalSince(date)) < abs(sample2.startDate.timeIntervalSince(date))
        }
        
        if let sample = closestSample {
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            return Int(bpm)
        }
        
        return nil
    }
}

// 导入的血压记录结构
struct ImportedReading {
    let systolic: Int
    let diastolic: Int
    let heartRate: Int
    let measuredAt: Date
}

// 错误类型
enum HealthKitError: LocalizedError {
    case notAuthorized
    case typeNotAvailable
    case queryFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "未授权访问健康数据"
        case .typeNotAvailable:
            return "健康数据类型不可用"
        case .queryFailed:
            return "查询健康数据失败"
        }
    }
}
