import ApplicationServices
import AppKit
import EventKit
import Foundation
import ServiceManagement

@MainActor
final class PermissionCenter {
    private let accessibilityService = AccessibilityPermissionService()

    func snapshot(
        folderAccessCount: Int,
        experimentalDockTweaksEnabled: Bool,
        calendarAgendaEnabled: Bool = false
    ) -> [PermissionState] {
        [
            PermissionState(
                id: "accessibility",
                name: "Accessibility",
                status: accessibilityService.isTrusted() ? .granted : .missing,
                detail: "Only needed for the optional window-arranging helpers. MacForge asks the first time you use one.",
                isRequired: false
            ),
            PermissionState(
                id: "file-access",
                name: "File & Folder Access",
                status: folderAccessCount > 0 ? .granted : .limited,
                detail: folderAccessCount > 0 ? "\(folderAccessCount) folder access root(s) saved." : "Add folders explicitly before using File Hub actions.",
                isRequired: false
            ),
            PermissionState(
                id: "calendar",
                name: "Calendars",
                status: calendarPermissionStatus(agendaEnabled: calendarAgendaEnabled),
                detail: calendarAgendaEnabled
                    ? "Used to show your next event in the island shortly before it starts."
                    : "Requested only if you enable the Calendar agenda widget.",
                isRequired: false
            ),
            PermissionState(
                id: "automation",
                name: "Automation",
                status: .disabled,
                detail: AutomationPermissionNotes.appleEventsUsage,
                isRequired: false
            ),
            PermissionState(
                id: "launch-at-login",
                name: "Launch at Login",
                status: launchAtLoginEnabled ? .granted : .disabled,
                detail: "Managed with SMAppService when enabled by the user.",
                isRequired: false
            ),
            PermissionState(
                id: "dock-tweaks",
                name: "Experimental Dock Tweaks",
                status: experimentalDockTweaksEnabled ? .granted : .disabled,
                detail: AutomationPermissionNotes.dockTweaksUsage,
                isRequired: false
            )
        ]
    }

    var accessibilityGranted: Bool {
        accessibilityService.isTrusted()
    }

    private func calendarPermissionStatus(agendaEnabled: Bool) -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .granted
        case .denied, .restricted:
            return agendaEnabled ? .missing : .disabled
        case .writeOnly:
            return .limited
        case .notDetermined:
            return .disabled
        @unknown default:
            return .unknown
        }
    }

    var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func requestAccessibility() {
        _ = accessibilityService.isTrusted(prompt: true)
        accessibilityService.openAccessibilitySettings()
    }

    /// Shows only the macOS "grant Accessibility" system dialog (which has its
    /// own "Open System Settings" button) without also force-opening Settings.
    /// Used for the gentle launch-time prompt.
    func promptAccessibilityDialog() {
        _ = accessibilityService.isTrusted(prompt: true)
    }

    func setLaunchAtLogin(_ enabled: Bool) -> CommandResult {
        guard #available(macOS 13.0, *) else {
            return .failure("Launch at Login", "Launch at Login requires macOS 13 or later.")
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return .success("Launch at Login", enabled ? "MacForge will open at login." : "MacForge will no longer open at login.")
        } catch {
            return .failure("Launch at Login", "macOS could not update the login item.", details: [error.localizedDescription])
        }
    }
}
