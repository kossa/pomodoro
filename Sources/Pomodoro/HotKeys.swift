import AppKit
import Carbon.HIToolbox

/// Things a global shortcut can trigger.
enum HotKeyAction: String, CaseIterable, Identifiable {
    case toggle
    case forceFocus
    case forceBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggle: return "Start / Pause"
        case .forceFocus: return "Force focus"
        case .forceBreak: return "Force break"
        }
    }
}

/// A recorded key combination. `label` is captured at record time so the key can be
/// displayed without reimplementing keyboard-layout translation.
struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    /// `NSEvent.ModifierFlags` raw value.
    var modifiers: UInt
    var label: String

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var display: String {
        var parts = ""
        if flags.contains(.control) { parts += "⌃" }
        if flags.contains(.option) { parts += "⌥" }
        if flags.contains(.shift) { parts += "⇧" }
        if flags.contains(.command) { parts += "⌘" }
        return parts + label
    }

    /// Carbon wants its own modifier constants.
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }
}

/// Persisted shortcut bindings.
final class Shortcuts: ObservableObject {
    private static let storageKey = "hotKeyBindings"

    @Published private(set) var bindings: [String: HotKeyCombo] {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: HotKeyCombo].self, from: data) {
            bindings = decoded
        } else {
            // ⌃⌥Space is unclaimed by macOS out of the box.
            bindings = [HotKeyAction.toggle.rawValue:
                HotKeyCombo(keyCode: UInt32(kVK_Space), modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue, label: "Space")]
        }
    }

    func combo(for action: HotKeyAction) -> HotKeyCombo? { bindings[action.rawValue] }

    func set(_ combo: HotKeyCombo?, for action: HotKeyAction) {
        if let combo {
            bindings[action.rawValue] = combo
        } else {
            bindings.removeValue(forKey: action.rawValue)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Registers system-wide hotkeys through Carbon, which — unlike a global NSEvent
/// monitor — needs no Accessibility permission.
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    /// Actions whose shortcut the system accepted. A combination already owned by
    /// another app is missing here, which the settings UI flags as a conflict.
    /// Updated only from the main queue, where `apply` is called.
    @Published private(set) var registered: Set<HotKeyAction> = []

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private let signature: OSType = 0x504F_4D4F  // 'POMO'

    private init() {}

    /// Replaces every registration with the given set.
    func apply(_ bindings: [HotKeyAction: HotKeyCombo], perform: @escaping (HotKeyAction) -> Void) {
        installHandlerIfNeeded()
        unregisterAll()

        for (index, action) in HotKeyAction.allCases.enumerated() {
            guard let combo = bindings[action] else { continue }
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: signature, id: id)
            let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, hotKeyID,
                                             GetApplicationEventTarget(), 0, &ref)
            // A conflicting shortcut (already owned by another app) simply doesn't register.
            guard status == noErr, let ref else { continue }
            refs[id] = ref
            actions[id] = { perform(action) }
            registered.insert(action)
        }
    }

    private func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
        registered.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return noErr }
            DispatchQueue.main.async { HotKeyManager.shared.fire(id: hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
