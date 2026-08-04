import SwiftUI

struct MenuView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: Settings
    @ObservedObject var stats: Stats

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
        .frame(width: 260)
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
        HStack(spacing: 8) {
            Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.borderedProminent)
            Button("Reset") { engine.reset() }
            Button("Skip") { engine.skip() }
        }
        .frame(maxWidth: .infinity)
    }

    private var forceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Force start").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("🍅 Focus") { engine.forceStart(.focus) }
                Button("☕️ Break") { engine.forceStartBreak() }
                Button("🌴 Long") { engine.forceStart(.longBreak) }
            }
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
            DisclosureGroup("Settings", isExpanded: $showingSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    stepper("Focus", value: $settings.focusMinutes, range: 1...120, unit: "min")
                    stepper("Short break", value: $settings.shortBreakMinutes, range: 1...60, unit: "min")
                    stepper("Long break", value: $settings.longBreakMinutes, range: 1...60, unit: "min")
                    stepper("Long break every", value: $settings.sessionsUntilLongBreak, range: 2...12, unit: "sessions")
                    Toggle("Auto-start next session", isOn: $settings.autoStartNext)
                    Toggle("Sound", isOn: $settings.playSound)
                    Toggle("Show countdown in menu bar", isOn: $settings.showTimeInMenuBar)
                }
                .padding(.top, 6)
            }
            .font(.callout)

            Button("Quit Pomodoro") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) \(unit)").foregroundStyle(.secondary)
            }
        }
    }
}
