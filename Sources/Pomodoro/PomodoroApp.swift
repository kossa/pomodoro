import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var settings: Settings
    @StateObject private var stats: Stats
    @StateObject private var engine: TimerEngine

    private let notifier = Notifier()

    init() {
        let settings = Settings()
        let stats = Stats()
        let notifier = self.notifier
        _settings = StateObject(wrappedValue: settings)
        _stats = StateObject(wrappedValue: stats)
        _engine = StateObject(wrappedValue: MainActor.assumeIsolated {
            TimerEngine(settings: settings, stats: stats, notifier: notifier)
        })
        notifier.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(engine: engine, settings: settings, stats: stats)
        } label: {
            Text(menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        settings.showTimeInMenuBar
            ? "\(engine.phase.symbol) \(engine.formattedRemaining)"
            : engine.phase.symbol
    }
}

/// Menu-bar-only behaviour. LSUIElement covers this for the bundled app;
/// this keeps `swift run` from bouncing a Dock icon too.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
