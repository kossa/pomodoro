import Foundation

/// Completed focus sessions per calendar day, keyed "yyyy-MM-dd".
/// Only the last 30 days are kept.
final class Stats: ObservableObject {
    private static let storageKey = "dailyCompletedFocus"
    private static let retainedDays = 30

    @Published private(set) var counts: [String: Int]

    /// Totals are stored rather than computed: the view reads them on every layout
    /// pass, and parsing every stored date each time showed up in profiles.
    @Published private(set) var today: Int = 0
    @Published private(set) var thisWeek: Int = 0

    private let defaults: UserDefaults
    private var summaryDay: String = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            counts = decoded
        } else {
            counts = [:]
        }
        prune()
        refreshSummary()
    }

    /// Rebuilds the totals, and rolls them over when the day has changed.
    func refreshSummary() {
        let key = Self.key(for: Date())
        summaryDay = key
        today = counts[key] ?? 0

        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            thisWeek = today
            return
        }
        thisWeek = counts.reduce(into: 0) { total, entry in
            guard let date = Self.date(from: entry.key), date >= weekStart else { return }
            total += entry.value
        }
    }

    /// Cheap enough to call from a view: it only does work once a day.
    func refreshSummaryIfDayChanged() {
        if summaryDay != Self.key(for: Date()) { refreshSummary() }
    }

    func recordCompletedFocus() {
        let key = Self.key(for: Date())
        counts[key, default: 0] += 1
        persist()
        refreshSummary()
    }

    func resetToday() {
        counts[Self.key(for: Date())] = 0
        persist()
        refreshSummary()
    }

    private func prune() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.retainedDays, to: Date()) else { return }
        let kept = counts.filter { key, _ in
            guard let date = Self.date(from: key) else { return false }
            return date >= cutoff
        }
        if kept.count != counts.count {
            counts = kept
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(counts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func key(for date: Date) -> String { formatter.string(from: date) }
    private static func date(from key: String) -> Date? { formatter.date(from: key) }
}
