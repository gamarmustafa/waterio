//
//  waterioApp.swift
//  waterio
//
//  Created by Gamar Mustafa on 09.07.26.
//

import SwiftUI
import HealthKit
import WidgetKit

@main
struct waterioApp: App {
    init() {
        Self.startObservingWater()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Observer queries must be re-registered on every launch — including the
    /// background launches HealthKit performs to deliver updates. Each new
    /// water sample then reloads the widget within seconds.
    private static func startObservingWater() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = WaterShared.healthStore

        let query = HKObserverQuery(sampleType: WaterShared.waterType,
                                    predicate: nil) { _, completionHandler, error in
            if error == nil {
                WidgetCenter.shared.reloadAllTimelines()
            }
            completionHandler()
        }
        store.execute(query)

        store.enableBackgroundDelivery(for: WaterShared.waterType,
                                       frequency: .immediate) { success, _ in
            if !success {
                store.enableBackgroundDelivery(for: WaterShared.waterType,
                                               frequency: .hourly) { _, _ in }
            }
        }
    }
}
