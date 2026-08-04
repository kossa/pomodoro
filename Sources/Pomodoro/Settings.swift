import SwiftUI

/// User preferences, backed by UserDefaults so they survive relaunches.
final class Settings: ObservableObject {
    @AppStorage("focusMinutes") var focusMinutes: Int = 25 { willSet { objectWillChange.send() } }
    @AppStorage("shortBreakMinutes") var shortBreakMinutes: Int = 5 { willSet { objectWillChange.send() } }
    @AppStorage("longBreakMinutes") var longBreakMinutes: Int = 15 { willSet { objectWillChange.send() } }
    @AppStorage("sessionsUntilLongBreak") var sessionsUntilLongBreak: Int = 4 { willSet { objectWillChange.send() } }
    @AppStorage("longBreaksEnabled") var longBreaksEnabled: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("autoStartNext") var autoStartNext: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("playSound") var playSound: Bool = true { willSet { objectWillChange.send() } }
    // What the menu bar item shows. At least one part always stays visible so the
    // item remains findable and clickable.
    @AppStorage("menuBarShowIcon") var menuBarShowIcon: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("menuBarShowMinutes") var menuBarShowMinutes: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("menuBarShowSeconds") var menuBarShowSeconds: Bool = true { willSet { objectWillChange.send() } }

    init(defaults: UserDefaults = .standard) {
        Self.migrateMenuBarStyle(defaults)
    }

    /// Carries the pre-1.4 three-way style over to the individual switches.
    private static func migrateMenuBarStyle(_ defaults: UserDefaults) {
        guard let style = defaults.string(forKey: "menuBarStyle") else { return }
        switch style {
        case "timeOnly":
            defaults.set(false, forKey: "menuBarShowIcon")
        case "iconOnly":
            defaults.set(false, forKey: "menuBarShowMinutes")
            defaults.set(false, forKey: "menuBarShowSeconds")
        default:
            break
        }
        defaults.removeObject(forKey: "menuBarStyle")
    }

    var menuBarIsBlank: Bool { !menuBarShowIcon && !menuBarShowMinutes && !menuBarShowSeconds }

    /// The menu bar label. Seconds alone keep an "s" so a bare number can't be read
    /// as minutes. With everything switched off the item is a blank — still there to
    /// click, but silent, leaving notifications as the cue.
    func menuBarTitle(phase: Phase, remaining: TimeInterval) -> String {
        let total = Int(max(0, remaining.rounded(.up)))
        var parts: [String] = []

        if menuBarShowIcon { parts.append(phase.symbol) }
        if menuBarShowMinutes, menuBarShowSeconds {
            parts.append(String(format: "%02d:%02d", total / 60, total % 60))
        } else if menuBarShowMinutes {
            parts.append("\(total / 60)")
        } else if menuBarShowSeconds {
            parts.append("\(total)s")
        }

        // A space, not an empty string: it keeps the item clickable.
        return parts.isEmpty ? " " : parts.joined(separator: " ")
    }

    /// Chime played when each phase *ends*. Empty string means silent.
    @AppStorage("focusEndSound") var focusEndSound: String = "Glass" { willSet { objectWillChange.send() } }
    @AppStorage("shortBreakEndSound") var shortBreakEndSound: String = "Ping" { willSet { objectWillChange.send() } }
    @AppStorage("longBreakEndSound") var longBreakEndSound: String = "Hero" { willSet { objectWillChange.send() } }

    func endSound(for phase: Phase) -> String? {
        guard playSound else { return nil }
        let name: String
        switch phase {
        case .focus: name = focusEndSound
        case .shortBreak: name = shortBreakEndSound
        case .longBreak: name = longBreakEndSound
        }
        return name.isEmpty ? nil : name
    }

    func endSoundBinding(for phase: Phase) -> Binding<String> {
        switch phase {
        case .focus: return Binding(get: { self.focusEndSound }, set: { self.focusEndSound = $0 })
        case .shortBreak: return Binding(get: { self.shortBreakEndSound }, set: { self.shortBreakEndSound = $0 })
        case .longBreak: return Binding(get: { self.longBreakEndSound }, set: { self.longBreakEndSound = $0 })
        }
    }
}
