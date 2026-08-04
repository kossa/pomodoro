import SwiftUI

/// User preferences, backed by UserDefaults so they survive relaunches.
final class Settings: ObservableObject {
    @AppStorage("focusMinutes") var focusMinutes: Int = 25 { willSet { objectWillChange.send() } }
    @AppStorage("shortBreakMinutes") var shortBreakMinutes: Int = 5 { willSet { objectWillChange.send() } }
    @AppStorage("longBreakMinutes") var longBreakMinutes: Int = 15 { willSet { objectWillChange.send() } }
    @AppStorage("sessionsUntilLongBreak") var sessionsUntilLongBreak: Int = 4 { willSet { objectWillChange.send() } }
    @AppStorage("autoStartNext") var autoStartNext: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("playSound") var playSound: Bool = true { willSet { objectWillChange.send() } }
    @AppStorage("showTimeInMenuBar") var showTimeInMenuBar: Bool = true { willSet { objectWillChange.send() } }
}
