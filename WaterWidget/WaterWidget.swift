//
//  WaterWidget.swift
//  WaterWidget
//

import WidgetKit
import SwiftUI

struct WaterEntry: TimelineEntry {
    let date: Date
    let liters: Double
    let goalLiters: Double
    /// True when HealthKit was unreadable and no cached value exists yet —
    /// usually means the app was never opened to grant access.
    let needsSetup: Bool

    static let placeholder = WaterEntry(date: .now, liters: 1.25, goalLiters: 2, needsSetup: false)
}

struct WaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await currentEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            let refresh = Date(timeIntervalSinceNow: 30 * 60)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func currentEntry() async -> WaterEntry {
        let goal = WaterShared.loadGoal()
        do {
            let liters = try await WaterShared.fetchTodayWaterLiters()
            WaterShared.cache(todayLiters: liters)
            return WaterEntry(date: .now, liters: liters, goalLiters: goal, needsSetup: false)
        } catch {
            // Health data is unreadable (device locked, access not granted, ...).
            if let cached = WaterShared.loadCachedTodayLiters() {
                return WaterEntry(date: .now, liters: cached, goalLiters: goal, needsSetup: false)
            }
            return WaterEntry(date: .now, liters: 0, goalLiters: goal, needsSetup: true)
        }
    }
}

struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WaterWidget", provider: WaterProvider()) { entry in
            WaterWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Water Intake")
        .description("Today's water from Apple Health.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
