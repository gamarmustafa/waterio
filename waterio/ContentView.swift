//
//  ContentView.swift
//  waterio
//
//  Created by Gamar Mustafa on 09.07.26.
//

import SwiftUI
import HealthKit
import WidgetKit
import Charts

struct ContentView: View {
    @State private var goalLiters = WaterShared.loadGoal()
    @State private var quickAddLiters = WaterShared.loadQuickAdd()
    @State private var days: [DayWater] = []
    @State private var drinks: [WaterDrink] = []
    @State private var errorMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    private var todayLiters: Double { days.last?.liters ?? 0 }

    var body: some View {
        List {
            Group {
                header
                ProgressView(value: goalLiters > 0 ? min(todayLiters / goalLiters, 1) : 0)
                    .tint(.blue)
                chart
                Button {
                    addDrink()
                } label: {
                    Label("Add \(WaterShared.formatLiters(quickAddLiters))", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .listRowSeparator(.hidden)

            if !drinks.isEmpty {
                Section("Today") {
                    ForEach(drinks) { drink in
                        drinkRow(drink)
                    }
                }
            }

            Group {
                Stepper(value: $quickAddLiters, in: 0.05...1, step: 0.05) {
                    HStack {
                        Text("Quick add")
                        Spacer()
                        Text(WaterShared.formatLiters(quickAddLiters))
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: quickAddLiters) {
                    WaterShared.saveQuickAdd(quickAddLiters)
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

                Button {
                    openHealthApp()
                } label: {
                    Label("Open Health", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .alert("Health Error",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await setup() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await refresh() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.title)
                .foregroundStyle(.blue.gradient)
            Text(WaterShared.formatLiters(todayLiters))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("of \(WaterShared.formatLiters(goalLiters)) today")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var chart: some View {
        Chart(days) { day in
            BarMark(x: .value("Day", day.date, unit: .day),
                    y: .value("Water", day.liters))
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            RuleMark(y: .value("Goal", goalLiters))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.secondary)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .frame(height: 150)
    }

    private func drinkRow(_ drink: WaterDrink) -> some View {
        HStack {
            Image(systemName: "drop")
                .font(.caption)
                .foregroundStyle(.blue)
            Text(drink.date, style: .time)
            Spacer()
            Text(WaterShared.formatLiters(drink.liters))
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .swipeActions(edge: .trailing) {
            if isOwnedByWaterio(drink) {
                Button(role: .destructive) {
                    delete(drink)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    /// HealthKit only lets us delete samples Waterio (app or widget
    /// extension) wrote itself.
    private func isOwnedByWaterio(_ drink: WaterDrink) -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return drink.sourceBundleID.hasPrefix(bundleID)
    }

    private func addDrink() {
        Task {
            do {
                try await WaterShared.logWater(liters: quickAddLiters)
                await refresh()
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                errorMessage = "Couldn't save to Health. Check that Waterio may write Water data in Health → Sharing → Apps."
            }
        }
    }

    private func delete(_ drink: WaterDrink) {
        Task {
            do {
                try await WaterShared.deleteDrink(id: drink.id)
                await refresh()
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                errorMessage = "This entry wasn't logged by Waterio, so it can only be deleted in the Health app."
            }
        }
    }

    private func setup() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Shows the permission sheet on first launch only; a no-op afterwards.
        try? await WaterShared.healthStore.requestAuthorization(toShare: [WaterShared.waterType],
                                                                read: [WaterShared.waterType])
        await refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refresh() async {
        async let dailyTotals = WaterShared.fetchDailyWaterLiters(daysBack: 7)
        async let todayDrinks = WaterShared.fetchTodayDrinks()
        if let fetched = try? await dailyTotals {
            withAnimation { days = fetched }
        }
        if let fetched = try? await todayDrinks {
            withAnimation { drinks = fetched }
        }
    }

    /// The x-apple-health scheme is undocumented and has no working path for
    /// the Water page, so Browse is the deepest reliable stop.
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
}

#Preview {
    ContentView()
}
