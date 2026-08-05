import AppKit
import Combine
import SwiftUI

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var settings: Settings
    @StateObject private var stats: Stats
    @StateObject private var engine: TimerEngine
    @StateObject private var shortcuts: Shortcuts
    @StateObject private var updater: Updater

    private let notifier = Notifier()
    private let coordinator: HotKeyCoordinator

    init() {
        let settings = Settings()
        let stats = Stats()
        let shortcuts = Shortcuts()
        let notifier = self.notifier
        let engine = MainActor.assumeIsolated {
            TimerEngine(settings: settings, stats: stats, notifier: notifier)
        }

        let updater = MainActor.assumeIsolated { Updater() }

        _settings = StateObject(wrappedValue: settings)
        _stats = StateObject(wrappedValue: stats)
        _shortcuts = StateObject(wrappedValue: shortcuts)
        _engine = StateObject(wrappedValue: engine)
        _updater = StateObject(wrappedValue: updater)
        coordinator = HotKeyCoordinator(engine: engine, shortcuts: shortcuts)

        // Clicking the "X complete" banner starts the phase it just moved on to.
        // `start()` is a no-op when auto-start already got there first.
        notifier.onActivate = { [weak engine] in
            MainActor.assumeIsolated { engine?.start() }
        }
        notifier.requestAuthorization()
        MainActor.assumeIsolated { updater.checkIfDue() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(engine: engine, settings: settings, stats: stats,
                     shortcuts: shortcuts, updater: updater)
        } label: {
            // Monospaced digits keep the item's width steady, so a changing
            // countdown doesn't force the menu bar to re-lay-out every second.
            Text(menuBarTitle).monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        settings.menuBarTitle(phase: engine.phase, remaining: engine.remaining)
    }
}

/// Keeps the registered global hotkeys in sync with the saved bindings.
@MainActor
final class HotKeyCoordinator {
    private let engine: TimerEngine
    private var cancellable: AnyCancellable?

    init(engine: TimerEngine, shortcuts: Shortcuts) {
        self.engine = engine
        cancellable = shortcuts.$bindings
            .receive(on: RunLoop.main)
            .sink { [weak self] bindings in self?.register(bindings) }
    }

    private func register(_ bindings: [String: HotKeyCombo]) {
        var byAction: [HotKeyAction: HotKeyCombo] = [:]
        for (key, combo) in bindings {
            guard let action = HotKeyAction(rawValue: key) else { continue }
            byAction[action] = combo
        }
        HotKeyManager.shared.apply(byAction) { [weak self] action in
            MainActor.assumeIsolated { self?.perform(action) }
        }
    }

    private func perform(_ action: HotKeyAction) {
        switch action {
        case .toggle: engine.toggle()
        case .forceFocus: engine.forceStart(.focus)
        case .forceBreak: engine.forceStartBreak()
        }
    }
}

/// Menu-bar-only behaviour. LSUIElement covers this for the bundled app;
/// this keeps `swift run` from bouncing a Dock icon too.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
