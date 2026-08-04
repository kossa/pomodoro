import SwiftUI

struct MenuView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: Settings
    @ObservedObject var stats: Stats
    @ObservedObject var shortcuts: Shortcuts

    @State private var showingSettings = false

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
                    durations
                    Divider()
                    sounds
                    Divider()
                    shortcutSection
                    Divider()
                    Toggle("Auto-start next session", isOn: $settings.autoStartNext)
                    Picker("Menu bar", selection: Binding(get: { settings.menuBarStyle },
                                                          set: { settings.menuBarStyle = $0 })) {
                        ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
                    }
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

    private var durations: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepper("Focus", value: $settings.focusMinutes, range: 1...120, unit: "min")
            stepper("Short break", value: $settings.shortBreakMinutes, range: 1...60, unit: "min")
            Toggle("Long breaks", isOn: $settings.longBreaksEnabled)
            if settings.longBreaksEnabled {
                stepper("Long break", value: $settings.longBreakMinutes, range: 1...60, unit: "min")
                stepper("Long break every", value: $settings.sessionsUntilLongBreak, range: 2...12, unit: "sessions")
            }
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
