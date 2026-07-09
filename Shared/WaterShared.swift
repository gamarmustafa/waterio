//
//  WaterShared.swift
//  waterio
//
//  Shared between the app and the widget extension.
//

import Foundation
import HealthKit

enum WaterShared {
    static let appGroupID = "group.almabaw.waterio"
    static let widgetDeepLinkURL = URL(string: "waterio://health")!

    static let defaultGoalLiters = 2.0

    private static let goalKey = "dailyGoalLiters"
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

    // MARK: - Formatting

    static func formatLiters(_ liters: Double) -> String {
        liters.formatted(.number.precision(.fractionLength(0...2))) + "L"
    }
}
