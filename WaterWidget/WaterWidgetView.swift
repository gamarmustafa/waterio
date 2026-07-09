//
//  WaterWidgetView.swift
//  WaterWidget
//

import WidgetKit
import SwiftUI

struct WaterWidgetView: View {
    let entry: WaterEntry

    private var progress: Double {
        guard entry.goalLiters > 0 else { return 0 }
        return min(entry.liters / entry.goalLiters, 1)
    }

    var body: some View {
        Group {
            if entry.needsSetup {
                setupHint
            } else {
                progressRing
            }
        }
        .widgetURL(WaterShared.widgetDeepLinkURL)
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
