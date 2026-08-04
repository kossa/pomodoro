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
    @AppStorage("showTimeInMenuBar") var showTimeInMenuBar: Bool = true { willSet { objectWillChange.send() } }

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
