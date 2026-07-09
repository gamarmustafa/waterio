# Waterio

Waterio is a widget-first iOS application for tracking daily water intake through Apple Health. The application itself is intentionally minimal: its primary interfaces are a Home Screen widget that displays the day's intake and a Control Center control that logs water with a single tap, without opening the app.

## Features

- **Home Screen widget** — displays today's water intake as a progress ring against a configurable daily goal. Data is read directly from HealthKit; the most recent value is cached in an App Group container and shown when Health data is unavailable (for example, while the device is locked).
- **Control Center control** — an iOS 18 control that logs a configurable quick-add amount to Apple Health in the background. The underlying App Intent is also available as a Shortcuts action and can be assigned to the Action Button.
- **In-app overview** — today's total, a seven-day intake chart with a goal reference line, and a chronological log of the day's entries. Entries written by Waterio can be removed with a swipe.
- **Settings** — daily goal and quick-add amount, both adjustable in the app and shared with the widget and control via an App Group.
- **Background delivery** — an `HKObserverQuery` with HealthKit background delivery reloads the widget within seconds of a new water sample being written, regardless of which app wrote it.

## Architecture

The project consists of two targets with a shared source directory:

| Component | Description |
| --- | --- |
| `waterio` | The application target. Requests HealthKit authorization, hosts the overview screen, and registers the background-delivery observer. |
| `WaterWidgetExtension` | The WidgetKit extension containing the Home Screen widget (`WaterWidget`) and the Control Center control (`LogWaterControl`). |
| `Shared/` | Sources compiled into both targets: HealthKit queries and persistence (`WaterShared.swift`) and the logging intent (`LogWaterIntent.swift`). |

## Requirements

- iOS 18.0 or later
- Xcode 26 or later
- An Apple Developer account (free or paid) for HealthKit and App Group code signing

## Building and Running

1. Clone the repository and open `waterio.xcodeproj` in Xcode.
2. Select your development team under *Signing & Capabilities* for both the `waterio` and `WaterWidgetExtension` targets. If the bundle identifier is unavailable, change it consistently across both targets.
3. Build and run the `waterio` scheme on a device or simulator.
4. On first launch, grant read and write access to Water data when prompted.
5. Add the widget: long-press the Home Screen → *Edit* → *Add Widget* → search for "waterio".
6. Add the control: open Control Center → long-press → *Add a Control* → search for "Log Water".

Applications signed with a free personal team expire after seven days and must be reinstalled from Xcode.

## Technical Notes

- **Deletion scope.** HealthKit permits an application to delete only samples that it wrote itself. Entries created by other sources (including the Health app) are listed but cannot be removed from within Waterio.
- **Health app navigation.** Apple does not provide a documented deep link to a specific data type in the Health app. The "Open Health" action uses the undocumented `x-apple-health://browse` URL and lands on the Browse tab, from which the Water section is one tap away.
