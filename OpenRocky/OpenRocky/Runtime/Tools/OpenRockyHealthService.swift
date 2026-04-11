//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import HealthKit

@MainActor
final class OpenRockyHealthService {
    static let shared = OpenRockyHealthService()

    private let store = HKHealthStore()
    private var isAuthorized = false

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        types.insert(HKQuantityType(.stepCount))
        types.insert(HKQuantityType(.heartRate))
        types.insert(HKQuantityType(.activeEnergyBurned))
        types.insert(HKQuantityType(.distanceWalkingRunning))
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }()

    func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw OpenRockyHealthError.notAvailable
        }
        guard !isAuthorized else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    func querySummary(dateString: String) async throws -> OpenRockyHealthSummary {
        try await requestAuthorizationIfNeeded()

        let date = try parseDate(dateString)
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        async let steps = querySum(type: .stepCount, unit: .count(), start: start, end: end)
        async let energy = querySum(type: .activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let distance = querySum(type: .distanceWalkingRunning, unit: .meter(), start: start, end: end)
        async let heartRate = queryAverage(type: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end)
        async let sleep = querySleepData(start: start, end: end)

        return OpenRockyHealthSummary(
            date: dateString,
            steps: try await steps,
            activeEnergyKcal: try await energy,
            distanceMeters: try await distance,
            avgHeartRateBpm: try await heartRate,
            sleep: try await sleep
        )
    }

    func queryMetric(metric: String, startDate: String, endDate: String) async throws -> OpenRockyHealthMetricResult {
        try await requestAuthorizationIfNeeded()

        let start = Calendar.current.startOfDay(for: try parseDate(startDate))
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: try parseDate(endDate)))!

        switch metric {
        case "steps":
            let value = try await querySum(type: .stepCount, unit: .count(), start: start, end: end)
            return OpenRockyHealthMetricResult(metric: metric, value: value, unit: "count")
        case "heart_rate":
            let value = try await queryAverage(type: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end)
            return OpenRockyHealthMetricResult(metric: metric, value: value, unit: "bpm")
        case "active_energy":
            let value = try await querySum(type: .activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
            return OpenRockyHealthMetricResult(metric: metric, value: value, unit: "kcal")
        case "distance_walking_running":
            let value = try await querySum(type: .distanceWalkingRunning, unit: .meter(), start: start, end: end)
            return OpenRockyHealthMetricResult(metric: metric, value: value, unit: "meters")
        case "sleep":
            let sleepData = try await querySleepData(start: start, end: end)
            return OpenRockyHealthMetricResult(metric: metric, value: sleepData.totalMinutes, unit: "minutes", sleep: sleepData)
        default:
            throw OpenRockyHealthError.unsupportedMetric(metric)
        }
    }

    // MARK: - Queries

    private func querySum(type: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func queryAverage(type: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .discreteAverage)
        let result = try await descriptor.result(for: store)
        guard let avg = result?.averageQuantity()?.doubleValue(for: unit) else { return nil }
        return (avg * 10).rounded() / 10
    }

    private func querySleepData(start: Date, end: Date) async throws -> OpenRockyHealthSleepData {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.categorySample(type: sleepType, predicate: predicate)
        let descriptor = HKSampleQueryDescriptor(predicates: [samplePredicate], sortDescriptors: [SortDescriptor(\.startDate, order: .forward)], limit: 100)
        let samples = try await descriptor.result(for: store)

        var totalMinutes: Double = 0
        var stages: [String: Double] = [:]

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60
            let stageName: String
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: stageName = "core"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: stageName = "deep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: stageName = "rem"
            case HKCategoryValueSleepAnalysis.awake.rawValue: stageName = "awake"
            case HKCategoryValueSleepAnalysis.inBed.rawValue: stageName = "in_bed"
            default: stageName = "other"
            }
            totalMinutes += duration
            stages[stageName, default: 0] += duration
        }

        let roundedStages = stages.mapValues { ($0 * 10).rounded() / 10 }
        return OpenRockyHealthSleepData(
            totalMinutes: (totalMinutes * 10).rounded() / 10,
            stagesMinutes: roundedStages
        )
    }

    private func parseDate(_ string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: string) else {
            throw OpenRockyHealthError.invalidDate(string)
        }
        return date
    }
}

enum OpenRockyHealthError: LocalizedError {
    case notAvailable
    case unsupportedMetric(String)
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "HealthKit is not available on this device."
        case .unsupportedMetric(let name):
            "Unsupported health metric: \(name)"
        case .invalidDate(let value):
            "Invalid date format: \(value). Expected YYYY-MM-DD."
        }
    }
}

// MARK: - Result Types

struct OpenRockyHealthSummary: Codable {
    let date: String
    let steps: Double
    let activeEnergyKcal: Double
    let distanceMeters: Double
    let avgHeartRateBpm: Double?
    let sleep: OpenRockyHealthSleepData

    enum CodingKeys: String, CodingKey {
        case date, steps, sleep
        case activeEnergyKcal = "active_energy_kcal"
        case distanceMeters = "distance_meters"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
    }
}

struct OpenRockyHealthMetricResult: Codable {
    let metric: String
    let value: Double?
    let unit: String?
    let sleep: OpenRockyHealthSleepData?

    init(metric: String, value: Double? = nil, unit: String? = nil, sleep: OpenRockyHealthSleepData? = nil) {
        self.metric = metric
        self.value = value
        self.unit = unit
        self.sleep = sleep
    }
}

struct OpenRockyHealthSleepData: Codable {
    let totalMinutes: Double
    let stagesMinutes: [String: Double]

    enum CodingKeys: String, CodingKey {
        case totalMinutes = "total_minutes"
        case stagesMinutes = "stages_minutes"
    }
}
