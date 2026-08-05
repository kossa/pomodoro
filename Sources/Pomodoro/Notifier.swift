import AppKit
import UserNotifications

/// End-of-session alerts. Prefers UNUserNotificationCenter (needs a real .app bundle);
/// falls back to `osascript` so the app is never silent when authorization is unavailable.
final class Notifier: NSObject {
    /// Called when the user clicks the banner (or its action button), so the next
    /// session can begin straight from the notification.
    var onActivate: (() -> Void)?

    private var authorized = false
    private var center: UNUserNotificationCenter? {
        // Requesting the center outside a bundle raises an exception, so guard on it.
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    private static let categoryIdentifier = "session.complete"
    private static let startActionIdentifier = "session.start"

    func requestAuthorization() {
        guard let center else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async { self?.authorized = granted }
        }
    }

    /// `soundName` is a system sound; nil is silent.
    /// `actionTitle` adds a button to the banner; without it, clicking the body is the only action.
    func notify(title: String, body: String, soundName: String?, actionTitle: String? = nil) {
        if authorized, let center {
            registerCategory(actionTitle: actionTitle, on: center)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = Self.categoryIdentifier
            // The chime is played directly so the user's per-phase choice is honoured
            // and it isn't muted by the banner's own sound settings.
            content.sound = nil
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request, withCompletionHandler: nil)
        } else {
            displayViaOsascript(title: title, body: body)
        }

        SoundLibrary.play(soundName)
    }

    /// The category carries the action button, so it is re-registered whenever that
    /// button's title changes — it names the phase that is about to start.
    private func registerCategory(actionTitle: String?, on center: UNUserNotificationCenter) {
        let actions = actionTitle.map {
            [UNNotificationAction(identifier: Self.startActionIdentifier, title: $0, options: [])]
        } ?? []
        let category = UNNotificationCategory(identifier: Self.categoryIdentifier,
                                              actions: actions,
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    private func displayViaOsascript(title: String, body: String) {
        let script = "display notification \(body.asAppleScriptString) with title \(title.asAppleScriptString)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier, Self.startActionIdentifier:
            DispatchQueue.main.async { [weak self] in self?.onActivate?() }
        default:
            break
        }
        completionHandler()
    }

    /// Without this the banner is suppressed whenever the app happens to be active,
    /// which would silently drop the alert while a settings window is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}

private extension String {
    /// Quoted and escaped for embedding in an AppleScript literal.
    var asAppleScriptString: String {
        "\"" + replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
