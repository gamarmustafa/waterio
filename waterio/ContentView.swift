//
//  ContentView.swift
//  waterio
//
//  Created by Gamar Mustafa on 09.07.26.
//

import SwiftUI
import HealthKit
import WidgetKit

struct ContentView: View {
    @State private var goalLiters = WaterShared.loadGoal()
    @State private var accessRequested = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "drop.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text("Waterio lives in your widget")
                .font(.title2.bold())

            Text("This app has no interface of its own. Grant Health access once, set your goal, then add the Waterio widget to your Home Screen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if accessRequested {
                Label("Health access requested — now add the widget", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Button {
                    requestHealthAccess()
                } label: {
                    Label("Grant Health Access", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Stepper(value: $goalLiters, in: 0.5...6, step: 0.25) {
                HStack {
                    Text("Daily goal")
                    Spacer()
                    Text(WaterShared.formatLiters(goalLiters))
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: goalLiters) {
                WaterShared.saveGoal(goalLiters)
                WidgetCenter.shared.reloadAllTimelines()
            }

            Spacer()

            Text("Tapping the widget opens the Health app.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
    }

    private func requestHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        Task {
            try? await WaterShared.healthStore.requestAuthorization(toShare: [], read: [WaterShared.waterType])
            accessRequested = true
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

#Preview {
    ContentView()
}
