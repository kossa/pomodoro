import Foundation

enum Phase: String, Codable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var symbol: String {
        switch self {
        case .focus: return "🍅"
        case .shortBreak: return "☕️"
        case .longBreak: return "🌴"
        }
    }

    var isBreak: Bool { self != .focus }

    func duration(_ settings: Settings) -> TimeInterval {
        switch self {
        case .focus: return TimeInterval(settings.focusMinutes * 60)
        case .shortBreak: return TimeInterval(settings.shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(settings.longBreakMinutes * 60)
        }
    }
}
