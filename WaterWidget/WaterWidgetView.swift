//
//  WaterWidgetView.swift
//  WaterWidget
//

import WidgetKit
import SwiftUI

struct WaterWidgetView: View {
    let entry: WaterEntry
    @Environment(\.widgetFamily) private var family

    private var progress: Double {
        guard entry.goalLiters > 0 else { return 0 }
        return min(entry.liters / entry.goalLiters, 1)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            default:
                if entry.needsSetup {
                    setupHint
                } else {
                    progressRing
                }
            }
        }
        .widgetURL(WaterShared.widgetDeepLinkURL)
    }

    // Fitness-ring style: full closed circle, progress clockwise from 12 o'clock.
    private var circular: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.4), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "drop.fill")
                .font(.system(size: 18.5))
        }
        .padding(7)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.blue.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [.cyan, .blue],
                                   startPoint: .top,
                                   endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(WaterShared.formatLiters(entry.liters))
                    .font(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("of \(WaterShared.formatLiters(entry.goalLiters))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .padding(4)
    }

    private var setupHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.title)
                .foregroundStyle(.blue)
            Text("Open Waterio once to grant Health access")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview(as: .systemSmall) {
    WaterWidget()
} timeline: {
    WaterEntry.placeholder
    WaterEntry(date: .now, liters: 0.5, goalLiters: 2, needsSetup: false)
    WaterEntry(date: .now, liters: 0, goalLiters: 2, needsSetup: true)
}

#Preview(as: .accessoryCircular) {
    WaterWidget()
} timeline: {
    WaterEntry.placeholder
}
