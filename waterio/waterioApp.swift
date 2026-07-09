//
//  waterioApp.swift
//  waterio
//
//  Created by Gamar Mustafa on 09.07.26.
//

import SwiftUI
import UIKit
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
                .onOpenURL { url in
                    guard url.scheme == "waterio" else { return }
                    openHealthApp()
                }
        }
    }

    /// The widget can only launch its own app, so we trampoline straight into
    /// Apple Health. The x-apple-health scheme is undocumented and has no
    /// working path for the Water page, so Browse is the deepest reliable stop.
    private func openHealthApp() {
        let candidates = [
            "x-apple-health://browse",
            "x-apple-health://",
        ].compactMap(URL.init(string:))
        open(candidates)
    }

    private func open(_ candidates: [URL]) {
        guard let url = candidates.first else { return }
        UIApplication.shared.open(url) { success in
            if !success {
                open(Array(candidates.dropFirst()))
            }
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
