//
//  WaterShared.swift
//  waterio
//
//  Shared between the app and the widget extension.
//

import Foundation
import HealthKit

struct DayWater: Identifiable {
    let date: Date
    let liters: Double
    var id: Date { date }
}

struct WaterDrink: Identifiable {
    let id: UUID
    let date: Date
    let liters: Double
    let sourceBundleID: String
}

enum WaterShared {
    static let appGroupID = "group.almabaw.waterio"
    static let widgetDeepLinkURL = URL(string: "waterio://health")!

    static let defaultGoalLiters = 2.0

    private static let goalKey = "dailyGoalLiters"
    private static let quickAddKey = "quickAddLiters"
    static let defaultQuickAddLiters = 0.25
    private static let cachedLitersKey = "cachedTodayLiters"
    private static let cachedDayKey = "cachedDay"

    static let healthStore = HKHealthStore()
    static let waterType = HKQuantityType(.dietaryWater)

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Goal

    static func loadGoal() -> Double {
        let value = defaults.double(forKey: goalKey)
        return value > 0 ? value : defaultGoalLiters
    }

    static func saveGoal(_ liters: Double) {
        defaults.set(liters, forKey: goalKey)
    }

    // MARK: - Quick add amount

    static func loadQuickAdd() -> Double {
        let value = defaults.double(forKey: quickAddKey)
        return value > 0 ? value : defaultQuickAddLiters
    }

    static func saveQuickAdd(_ liters: Double) {
        defaults.set(liters, forKey: quickAddKey)
    }

    // MARK: - Cache (fallback for when Health data is unreadable, e.g. device locked)

    static func cache(todayLiters liters: Double) {
        defaults.set(liters, forKey: cachedLitersKey)
        defaults.set(Calendar.current.startOfDay(for: .now).timeIntervalSinceReferenceDate,
                     forKey: cachedDayKey)
    }

    /// Returns the cached value only if it was written today; nil otherwise.
    static func loadCachedTodayLiters() -> Double? {
        guard defaults.object(forKey: cachedLitersKey) != nil else { return nil }
        let cachedDay = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: cachedDayKey))
        guard cachedDay == Calendar.current.startOfDay(for: .now) else { return nil }
        return defaults.double(forKey: cachedLitersKey)
    }

    // MARK: - HealthKit

    /// Sums today's dietary water samples. Throws if Health data is unavailable
    /// (no authorization, device locked, ...); "no samples yet" counts as 0.
    static func fetchTodayWaterLiters() async throws -> Double {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: waterType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, statistics, error in
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                let liters = statistics?.sumQuantity()?.doubleValue(for: .liter()) ?? 0
                continuation.resume(returning: liters)
            }
            healthStore.execute(query)
        }
    }

    /// Daily totals for the last `daysBack` days, oldest first, today last.
    /// Days without samples come back as 0.
    static func fetchDailyWaterLiters(daysBack: Int) async throws -> [DayWater] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(daysBack - 1), to: anchor)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: waterType,
                                                    quantitySamplePredicate: predicate,
                                                    options: .cumulativeSum,
                                                    anchorDate: anchor,
                                                    intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, collection, error in
                if let error, (error as? HKError)?.code != .errorNoData {
                    continuation.resume(throwing: error)
                    return
                }
                let days = (0..<daysBack).map { offset -> DayWater in
                    let date = calendar.date(byAdding: .day, value: offset, to: start)!
                    let sum = collection?.statistics(for: date)?.sumQuantity()
                    return DayWater(date: date, liters: sum?.doubleValue(for: .liter()) ?? 0)
                }
                continuation.resume(returning: days)
            }
            healthStore.execute(query)
        }
    }

    /// Today's individual water samples, newest first.
    static func fetchTodayDrinks() async throws -> [WaterDrink] {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: waterType,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let drinks = (samples as? [HKQuantitySample] ?? []).map {
                    WaterDrink(id: $0.uuid,
                               date: $0.startDate,
                               liters: $0.quantity.doubleValue(for: .liter()),
                               sourceBundleID: $0.sourceRevision.source.bundleIdentifier)
                }
                continuation.resume(returning: drinks)
            }
            healthStore.execute(query)
        }
    }

    /// Writes a water sample dated now.
    static func logWater(liters: Double) async throws {
        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let now = Date.now
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: now, end: now)
        try await healthStore.save(sample)
    }

    /// Deletes a water sample. HealthKit only permits deleting samples this
    /// app wrote itself — entries from other apps (including manual entries
    /// in the Health app) are refused with an authorization error.
    static func deleteDrink(id: UUID) async throws {
        let sample: HKSample = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: waterType,
                                      predicate: HKQuery.predicateForObject(with: id),
                                      limit: 1,
                                      sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let sample = samples?.first {
                    continuation.resume(returning: sample)
                } else {
                    continuation.resume(throwing: HKError(.errorNoData))
                }
            }
            healthStore.execute(query)
        }
        try await healthStore.delete(sample)
    }

    // MARK: - Formatting

    static func formatLiters(_ liters: Double) -> String {
        liters.formatted(.number.precision(.fractionLength(0...2))) + "L"
    }
}
