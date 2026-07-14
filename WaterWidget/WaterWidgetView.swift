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
        return entry.liters / entry.goalLiters
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
    // Past 100% the ring closes and the overflow wraps a second lap on top,
    // separated by a hairline seam so the overlapping tip stays visible.
    private var circular: some View {
        let lap = (progress - 1).truncatingRemainder(dividingBy: 1)
        // On exact laps (200%, 300%, ...) keep the tip visible at 12 o'clock
        // instead of collapsing into a plain closed circle.
        let fullLap = progress > 1 && (lap == 0 || lap > 0.99)
        let overflow = fullLap ? 1 : lap
        return ZStack {
            Circle()
                .stroke(.secondary.opacity(0.4), lineWidth: 12)
            if progress < 1 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .stroke(.primary, lineWidth: 12)
                if overflow > 0 {
                    ZStack {
                        // Seam only at the leading tip, so the lap reads as a
                        // continuation of the ring rather than a separate arc.
                        Circle()
                            .trim(from: max(0, overflow - 0.001), to: overflow)
                            .stroke(.black, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                            .blendMode(.destinationOut)
                        // On a full lap, draw a short tail behind the tip so it
                        // merges into the ring below instead of floating as a dot.
                        Circle()
                            .trim(from: fullLap ? overflow - 0.05 : 0, to: overflow)
                            .stroke(.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    }
                    .rotationEffect(.degrees(-90))
                }
            }
            Image(systemName: "drop.fill")
                .font(.system(size: 18.5))
        }
        .compositingGroup()
        .padding(7)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.blue.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(progress, 1))
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
    WaterEntry(date: .now, liters: 2.7, goalLiters: 2, needsSetup: false)
    WaterEntry(date: .now, liters: 2, goalLiters: 1, needsSetup: false)
}
