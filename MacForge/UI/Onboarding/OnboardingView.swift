import SwiftUI

/// First-run welcome flow: enable the island, pick widgets, and see exactly
/// which permissions exist and when they are asked for. No permission is
/// requested here except the ones the user explicitly opts into.
struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)

            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
        }
        .frame(width: 540, height: 520)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: step)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            welcomeStep
        case 1:
            widgetsStep
        default:
            permissionsStep
        }
    }

    // MARK: - Step 1: the island

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(
                symbol: "macbook.gen2",
                title: "Welcome to MacForge",
                subtitle: "MacForge turns your MacBook's notch into a Dynamic Island: now playing, timers, downloads, files, and agent activity — right where the camera housing is."
            )

            Toggle(isOn: $environment.notchConfig.enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn on the Notch Island")
                        .font(.callout.weight(.semibold))
                    Text("Hover over the notch to expand it. Nothing else changes on your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            Label("Works on notched and notchless Macs — displays without a camera cutout get a virtual island at the top center.", systemImage: "display")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 2: widgets

    private var widgetsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(
                symbol: "waveform",
                title: "Choose your live widgets",
                subtitle: "Each source can be changed later in Island & Widgets. macOS asks for consent per app the first time a source reads playback state."
            )

            VStack(spacing: 8) {
                widgetToggle("Now Playing — Apple Music", symbol: "music.note", isOn: $environment.liveIslandSettings.appleMusicEnabled)
                widgetToggle("Now Playing — Spotify", symbol: "music.note.list", isOn: $environment.liveIslandSettings.spotifyEnabled)
                widgetToggle("Timers", symbol: "timer", isOn: $environment.liveIslandSettings.timersEnabled)
                widgetToggle("Volume HUD in the island", symbol: "speaker.wave.2", isOn: $environment.liveIslandSettings.volumeHUDEnabled)
                widgetToggle(
                    "Calendar agenda (asks for Calendar access)",
                    symbol: "calendar",
                    isOn: Binding(
                        get: { environment.liveIslandSettings.calendarAgendaEnabled },
                        set: { environment.setCalendarAgendaEnabled($0) }
                    )
                )
            }
        }
    }

    private func widgetToggle(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
                .font(.callout)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 3: permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader(
                symbol: "lock.shield",
                title: "Permissions, only when needed",
                subtitle: "MacForge never asks for anything at launch. Every permission is tied to a feature and requested the moment you use it."
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(environment.permissionStates) { state in
                        PermissionRowView(state: state, action: nil)
                    }
                }
            }

            Label("Everything runs locally. No analytics, no network accounts.", systemImage: "hand.raised")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            environment.refreshPermissions()
        }
    }

    // MARK: - Chrome

    private func stepHeader(symbol: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.mint)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if step > 0 {
                Button("Back") {
                    step -= 1
                }
                .buttonStyle(.bordered)
            }

            Button(step == stepCount - 1 ? "Get Started" : "Continue") {
                if step == stepCount - 1 {
                    environment.hasCompletedOnboarding = true
                    dismiss()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
}
