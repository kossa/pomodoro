import AppKit
import UserNotifications

/// End-of-session alerts. Prefers UNUserNotificationCenter (needs a real .app bundle);
/// falls back to `osascript` so the app is never silent when authorization is unavailable.
final class Notifier {
    private var authorized = false
    private var center: UNUserNotificationCenter? {
        // Requesting the center outside a bundle raises an exception, so guard on it.
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func requestAuthorization() {
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async { self?.authorized = granted }
        }
    }

    func notify(title: String, body: String, playSound: Bool) {
        if authorized, let center {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if playSound { content.sound = .default }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request, withCompletionHandler: nil)
        } else {
            displayViaOsascript(title: title, body: body)
            if playSound { NSSound(named: "Glass")?.play() }
            return
        }

        // The banner sound can be suppressed by Focus modes; the chime is the reliable cue.
        if playSound { NSSound(named: "Glass")?.play() }
    }

    private func displayViaOsascript(title: String, body: String) {
        let script = "display notification \(body.asAppleScriptString) with title \(title.asAppleScriptString)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}

private extension String {
    /// Quoted and escaped for embedding in an AppleScript literal.
    var asAppleScriptString: String {
        "\"" + replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
