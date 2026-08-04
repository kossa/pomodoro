import Carbon.HIToolbox
import SwiftUI

/// Click to record, then press a combination. Escape cancels, Delete clears.
struct ShortcutRecorder: View {
    let action: HotKeyAction
    @ObservedObject var shortcuts: Shortcuts
    @ObservedObject private var hotKeys = HotKeyManager.shared

    @State private var isRecording = false
    @State private var monitor: Any?

    private var isConflicting: Bool {
        shortcuts.combo(for: action) != nil && !hotKeys.registered.contains(action)
    }

    var body: some View {
        HStack {
            Text(action.title)
            Spacer()
            if isConflicting, !isRecording {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Another app already uses this shortcut — pick a different one")
            }
            Button(buttonLabel) { isRecording ? stopRecording() : startRecording() }
                .buttonStyle(.bordered)
                .tint(isRecording ? .accentColor : nil)
                .fixedSize()
            if shortcuts.combo(for: action) != nil, !isRecording {
                Button {
                    shortcuts.set(nil, for: action)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var buttonLabel: String {
        if isRecording { return "Press keys…" }
        return shortcuts.combo(for: action)?.display ?? "Record"
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil  // swallow the keystroke while recording
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            stopRecording()
            return
        case kVK_Delete, kVK_ForwardDelete:
            shortcuts.set(nil, for: action)
            stopRecording()
            return
        default:
            break
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // A bare key would fire while typing anywhere, so require a modifier.
        guard !modifiers.isEmpty else { return }

        let combo = HotKeyCombo(keyCode: UInt32(event.keyCode),
                                modifiers: modifiers.rawValue,
                                label: Self.label(for: event))
        shortcuts.set(combo, for: action)
        stopRecording()
    }

    /// Names for keys that have no printable character; otherwise the character itself.
    private static func label(for event: NSEvent) -> String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[Int(event.keyCode)] { return name }
        if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            return characters.uppercased()
        }
        return "Key \(event.keyCode)"
    }
}
