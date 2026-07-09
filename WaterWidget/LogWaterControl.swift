//
//  LogWaterControl.swift
//  WaterWidget
//
//  Control Center button that logs the quick-add amount without
//  opening the app.
//

import WidgetKit
import SwiftUI

struct LogWaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LogWaterControl") {
            ControlWidgetButton(action: LogWaterIntent()) {
                Label("Log Water", systemImage: "drop.fill")
            }
        }
        .displayName("Log Water")
        .description("Adds your quick-add amount to Apple Health.")
    }
}
