//
//  LogWaterIntent.swift
//  waterio
//
//  Shared between the app and the widget extension. Powers the Control
//  Center button and is automatically exposed to Shortcuts and the
//  Action Button.
//

import AppIntents
import WidgetKit

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Adds your quick-add amount of water to Apple Health.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let liters = WaterShared.loadQuickAdd()
        try await WaterShared.logWater(liters: liters)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Logged \(WaterShared.formatLiters(liters))")
    }
}
