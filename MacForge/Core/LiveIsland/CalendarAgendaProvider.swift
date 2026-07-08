import AppKit
import EventKit
import Foundation

/// Surfaces the next upcoming calendar event as an ambient Live Island
/// snapshot. Calendar access is requested only when the user turns the widget
/// on — never at launch — and events are cached and refreshed on EventKit
/// change notifications instead of hitting the database every poll.
@MainActor
final class CalendarAgendaProvider: LiveIslandProvider {
    nonisolated static let providerID = "calendar-agenda"

    /// How far ahead the agenda looks for the next event.
    static let lookahead: TimeInterval = 12 * 60 * 60
    /// The event surfaces in the island this long before it starts.
    static let surfaceWindow: TimeInterval = 45 * 60
    /// Cached events are refetched at most this often (change notifications
    /// invalidate the cache immediately).
    static let cacheLifetime: TimeInterval = 120

    let id = CalendarAgendaProvider.providerID
    let displayName = "Calendar"
    private(set) var latestDiagnostic: LiveIslandProviderDiagnostic?

    private let store = EKEventStore()
    private var cachedEvent: (title: String, startDate: Date, endDate: Date)?
    private var lastFetchAt: Date?
    private var storeObserver: NSObjectProtocol?

    init() {
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastFetchAt = nil
            }
        }
    }

    static var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    static var hasFullAccess: Bool {
        authorizationStatus == .fullAccess
    }

    /// Requests full calendar access (the macOS 14 API). Called only from the
    /// settings/onboarding toggle, keeping the permission tied to the feature.
    static func requestAccess() async -> Bool {
        let store = EKEventStore()
        return (await (try? store.requestFullAccessToEvents())) ?? false
    }

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.calendarAgendaEnabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard Self.hasFullAccess else {
            latestDiagnostic = diagnostic(
                status: "Needs Calendar Permission",
                appStatus: "Grant Calendars access in System Settings > Privacy & Security.",
                permissionNeeded: true,
                updatedAt: now
            )
            return nil
        }

        refreshCacheIfNeeded(now: now)

        guard let event = cachedEvent, event.endDate > now else {
            latestDiagnostic = diagnostic(status: "Available", appStatus: "No upcoming events", updatedAt: now)
            return nil
        }

        // Stay ambient: only surface shortly before the event and while it is
        // in progress, so the agenda never squats in the island all day.
        guard event.startDate.timeIntervalSince(now) <= Self.surfaceWindow else {
            latestDiagnostic = diagnostic(
                status: "Available",
                appStatus: "Next: \(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))",
                updatedAt: now
            )
            return nil
        }

        latestDiagnostic = diagnostic(status: "Active", appStatus: "Showing \(event.title)", updatedAt: now)

        return LiveIslandSnapshot(
            providerID: id,
            providerName: displayName,
            kind: .calendar,
            priority: .calendar,
            title: event.title,
            subtitle: Self.subtitle(for: event.startDate, endDate: event.endDate, now: now),
            appName: "Calendar",
            bundleIdentifier: "com.apple.iCal",
            symbolName: "calendar",
            startedAt: now,
            expiresAt: min(event.endDate, now.addingTimeInterval(90)),
            actions: [LiveIslandAction(.openSource, title: "Open Calendar")]
        )
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        guard action == .openSource else {
            return .failure(displayName, "\(action.title) is not available for calendar events.")
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else {
            return .failure(displayName, "Calendar.app was not found.")
        }
        NSWorkspace.shared.open(url)
        return .success(displayName, "Opened Calendar.")
    }

    static func subtitle(for startDate: Date, endDate: Date, now: Date) -> String {
        if startDate > now {
            let minutes = max(1, Int((startDate.timeIntervalSince(now) / 60).rounded()))
            if minutes >= 60 {
                return "in \(minutes / 60)h \(minutes % 60)m"
            }
            return "in \(minutes)m"
        }
        return "until \(endDate.formatted(date: .omitted, time: .shortened))"
    }

    private func refreshCacheIfNeeded(now: Date) {
        if let lastFetchAt, now.timeIntervalSince(lastFetchAt) < Self.cacheLifetime {
            return
        }

        store.refreshSourcesIfNecessary()
        let predicate = store.predicateForEvents(
            withStart: now,
            end: now.addingTimeInterval(Self.lookahead),
            calendars: nil
        )
        let next = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate != nil && $0.endDate > now && $0.startDate != nil }
            .sorted { $0.startDate < $1.startDate }
            .first
        cachedEvent = next.map { event in
            (title: event.title ?? "Upcoming event", startDate: event.startDate, endDate: event.endDate)
        }
        lastFetchAt = now
    }

    private func diagnostic(
        status: String,
        appStatus: String,
        permissionNeeded: Bool = false,
        updatedAt: Date
    ) -> LiveIslandProviderDiagnostic {
        LiveIslandProviderDiagnostic(
            id: id,
            providerName: displayName,
            isEnabled: true,
            status: status,
            appStatus: appStatus,
            lastPollAt: updatedAt,
            permissionNeeded: permissionNeeded,
            updatedAt: updatedAt
        )
    }
}
