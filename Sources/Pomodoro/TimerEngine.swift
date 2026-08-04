import Combine
import Foundation

/// Single source of truth for the running session.
/// The remaining time is derived from an absolute end date, so the countdown stays
/// correct across sleep and timer coalescing.
@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false
    /// Focus sessions finished in the current cycle, used to place the long break.
    @Published private(set) var focusInCycle = 0

    private let settings: Settings
    private let stats: Stats
    private let notifier: Notifier

    private var endDate: Date?
    private var ticker: AnyCancellable?
    private var settingsObserver: AnyCancellable?

    init(settings: Settings, stats: Stats, notifier: Notifier) {
        self.settings = settings
        self.stats = stats
        self.notifier = notifier
        self.remaining = Phase.focus.duration(settings)

        // Editing a duration while that phase sits idle should update the shown time.
        settingsObserver = settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self, !self.isRunning else { return }
                self.remaining = self.phase.duration(self.settings)
            }
    }

    var progress: Double {
        let total = phase.duration(settings)
        guard total > 0 else { return 0 }
        return min(max(1 - remaining / total, 0), 1)
    }

    var formattedRemaining: String {
        let clamped = max(0, remaining.rounded(.up))
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = phase.duration(settings) }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        startTicking()
    }

    func pause() {
        guard isRunning else { return }
        remaining = max(0, endDate?.timeIntervalSinceNow ?? remaining)
        isRunning = false
        endDate = nil
        ticker?.cancel()
        ticker = nil
    }

    func toggle() { isRunning ? pause() : start() }

    /// Back to the beginning of the current phase, stopped.
    func reset() {
        stop()
        remaining = phase.duration(settings)
    }

    /// End this session early and move to whatever comes next, without crediting it.
    func skip() {
        advance(credit: false, autoStart: settings.autoStartNext)
    }

    /// Jump straight into a phase, whatever the cycle says. Nothing is credited.
    func forceStart(_ phase: Phase) {
        stop()
        self.phase = phase
        remaining = phase.duration(settings)
        start()
    }

    /// Start the next break the cycle would give (short, or long when due).
    func forceStartBreak() {
        forceStart(nextBreakPhase())
    }

    // MARK: - Internals

    private func stop() {
        isRunning = false
        endDate = nil
        ticker?.cancel()
        ticker = nil
    }

    private func startTicking() {
        ticker?.cancel()
        // One tick a second is all the display needs, and the tolerance lets the
        // system coalesce the wake-ups with others rather than firing precisely.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        ticker = AnyCancellable { timer.invalidate() }
    }

    private func tick() {
        guard isRunning, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            complete()
        } else if Int(left.rounded(.up)) != Int(remaining.rounded(.up)) {
            // Publishing only when the shown second changes keeps SwiftUI from
            // re-rendering the menu bar item on every tick.
            remaining = left
        }
    }

    private func complete() {
        let finished = phase
        advance(credit: true, autoStart: settings.autoStartNext)

        let next = phase
        let body: String
        if settings.autoStartNext {
            body = "\(next.title) started · \(Int(next.duration(settings) / 60)) min"
        } else {
            body = "Ready for \(next.title.lowercased())"
        }
        notifier.notify(title: "\(finished.symbol) \(finished.title) complete",
                        body: body,
                        soundName: settings.endSound(for: finished))
    }

    private func advance(credit: Bool, autoStart: Bool) {
        stop()

        if phase == .focus {
            if credit {
                stats.recordCompletedFocus()
                focusInCycle += 1
            }
            phase = nextBreakPhase()
        } else {
            if phase == .longBreak { focusInCycle = 0 }
            phase = .focus
        }

        remaining = phase.duration(settings)
        if autoStart { start() }
    }

    private func nextBreakPhase() -> Phase {
        guard settings.longBreaksEnabled else { return .shortBreak }
        let cycleLength = max(1, settings.sessionsUntilLongBreak)
        return focusInCycle > 0 && focusInCycle % cycleLength == 0 ? .longBreak : .shortBreak
    }
}
