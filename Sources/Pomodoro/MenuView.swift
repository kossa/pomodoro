import SwiftUI

/// The settings pane is split so the popover stays short.
enum SettingsTab: String, CaseIterable, Identifiable {
    case timer
    case sounds
    case shortcuts
    case general

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .sounds: return "speaker.wave.2"
        case .shortcuts: return "keyboard"
        case .general: return "gearshape"
        }
    }

    var title: String {
        switch self {
        case .timer: return "Timer"
        case .sounds: return "Sounds"
        case .shortcuts: return "Shortcuts"
        case .general: return "General"
        }
    }
}

struct MenuView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: Settings
    @ObservedObject var stats: Stats
    @ObservedObject var shortcuts: Shortcuts
    @ObservedObject var updater: Updater

    @State private var showingSettings = false
    @State private var tab: SettingsTab = .timer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            controls
            Divider()
            forceSection
            Divider()
            statsSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(engine.phase.symbol)  \(engine.phase.title)")
                .font(.headline)
            Text(engine.formattedRemaining)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            ProgressView(value: engine.progress)
                .progressViewStyle(.linear)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            iconButton(engine.isRunning ? "pause.fill" : "play.fill",
                       help: engine.isRunning ? "Pause" : "Start",
                       prominent: true) { engine.toggle() }
            iconButton("arrow.counterclockwise", help: "Reset this session") { engine.reset() }
            iconButton("forward.end.fill", help: "Skip to the next session") { engine.skip() }
        }
        .frame(maxWidth: .infinity)
    }

    private var forceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Force start").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                iconButton("target", help: "Force start a focus session") { engine.forceStart(.focus) }
                iconButton("cup.and.saucer.fill", help: "Force start a break") { engine.forceStartBreak() }
                if settings.longBreaksEnabled {
                    iconButton("bed.double.fill", help: "Force start a long break") { engine.forceStart(.longBreak) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statsSection: some View {
        HStack {
            Label("\(stats.today) today", systemImage: "checkmark.circle")
            Spacer()
            Text("\(stats.thisWeek) this week")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            // A plain DisclosureGroup only reacts to clicks on its chevron, so the
            // header is its own button covering the whole row.
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showingSettings.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(showingSettings ? 90 : 0))
                    Text("Settings")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.callout)

            if showingSettings {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $tab) {
                        ForEach(SettingsTab.allCases) { tab in
                            Image(systemName: tab.symbol)
                                .help(tab.title)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Text(tab.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // No fixed height here: a floor makes the taller tabs report a
                    // smaller size than they draw, and the Quit row lands on top
                    // of them. Each tab sizes itself instead.
                    Group {
                        switch tab {
                        case .timer: timerTab
                        case .sounds: sounds
                        case .shortcuts: shortcutSection
                        case .general: generalTab
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.top, 8)
                .font(.callout)
            }

            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q")
                Spacer()
            }
        }
    }

    private var timerTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepper("Focus", value: $settings.focusMinutes, range: 1...120, unit: "min")
            stepper("Short break", value: $settings.shortBreakMinutes, range: 1...60, unit: "min")
            Toggle("Long breaks", isOn: $settings.longBreaksEnabled)
            if settings.longBreaksEnabled {
                stepper("Long break", value: $settings.longBreakMinutes, range: 1...60, unit: "min")
                stepper("Long break every", value: $settings.sessionsUntilLongBreak, range: 2...12, unit: "sessions")
            }
            Divider()
            Toggle("Auto-start next session", isOn: $settings.autoStartNext)
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu bar shows").font(.caption).foregroundStyle(.secondary)
                Toggle("Tomato", isOn: $settings.menuBarShowIcon)
                Toggle("Minutes", isOn: $settings.menuBarShowMinutes)
                Toggle("Seconds", isOn: $settings.menuBarShowSeconds)
                if settings.menuBarIsBlank {
                    Text("The item stays clickable but shows nothing — notifications and shortcuts still work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            updatesSection
        }
    }

    private var sounds: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Sound", isOn: $settings.playSound)
            if settings.playSound {
                soundPicker("Focus ends", phase: .focus)
                soundPicker("Break ends", phase: .shortBreak)
                if settings.longBreaksEnabled {
                    soundPicker("Long break ends", phase: .longBreak)
                }
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Check for updates daily", isOn: $updater.checkDaily)

            HStack {
                Text("Version \(updater.currentVersion)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check now") { Task { await updater.check() } }
                    .disabled(updater.state == .checking || updater.state == .downloading)
            }

            updateStatus
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updater.state {
        case .idle:
            if let last = updater.lastChecked {
                Text("Last checked \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .checking:
            Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .downloading:
            Label("Downloading…", systemImage: "arrow.down.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .available(release):
            VStack(alignment: .leading, spacing: 6) {
                Label("Version \(release.version) is available", systemImage: "sparkles")
                    .font(.caption)
                HStack {
                    Button("Update and restart") { Task { await updater.install(release) } }
                        .buttonStyle(.borderedProminent)
                    Button("Notes") { NSWorkspace.shared.open(release.pageURL) }
                }
            }
        case let .failed(message):
            Label("Update check failed: \(message)", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Global shortcuts").font(.caption).foregroundStyle(.secondary)
            ForEach(HotKeyAction.allCases) { action in
                ShortcutRecorder(action: action, shortcuts: shortcuts)
            }
        }
    }

    private func soundPicker(_ title: String, phase: Phase) -> some View {
        let binding = settings.endSoundBinding(for: phase)
        return HStack {
            Picker(title, selection: binding) {
                Text("None").tag(SoundLibrary.silentName)
                Divider()
                ForEach(SoundLibrary.names, id: \.self) { Text($0).tag($0) }
            }
            Button {
                SoundLibrary.play(binding.wrappedValue)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Preview")
            .disabled(binding.wrappedValue.isEmpty)
        }
    }

    @ViewBuilder
    private func iconButton(_ symbol: String, help: String, prominent: Bool = false,
                            action: @escaping () -> Void) -> some View {
        let label = Image(systemName: symbol)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 34, height: 24)

        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .help(help)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .help(help)
        }
    }

    /// A typable field with a stepper beside it. Out-of-range or non-numeric input
    /// snaps back to the nearest allowed value when the field is committed.
    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        let clamped = Binding<Int>(
            get: { min(max(value.wrappedValue, range.lowerBound), range.upperBound) },
            set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )

        return HStack(spacing: 6) {
            Text(title)
            Spacer(minLength: 8)
            TextField("", value: clamped, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .labelsHidden()
                .help("Type a value between \(range.lowerBound) and \(range.upperBound)")
            Text(unit)
                .foregroundStyle(.secondary)
                .font(.caption)
            Stepper(value: clamped, in: range) { EmptyView() }
                .labelsHidden()
        }
    }
}
