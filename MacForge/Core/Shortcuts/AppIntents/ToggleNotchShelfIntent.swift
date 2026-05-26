import AppIntents
import Foundation

enum MacForgeCommandRequestKind: Codable, Hashable {
    case toggleNotchShelf
    case tileFocusedWindow(String)
    case openPinnedFolder(String)
    case applyPreset(String)
}

struct MacForgeCommandRequest: Codable, Hashable, Identifiable {
    var id: UUID
    var kind: MacForgeCommandRequestKind
    var createdAt: Date

    init(id: UUID = UUID(), kind: MacForgeCommandRequestKind, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
    }
}

struct MacForgeCommandBus {
    static let shared = MacForgeCommandBus()
    static let didEnqueueNotification = Notification.Name("MacForgeCommandBusDidEnqueue")

    private let pendingRequestsKey = "MacForgePendingCommandRequests"

    func enqueue(_ kind: MacForgeCommandRequestKind) {
        var requests = pendingRequests()
        requests.append(MacForgeCommandRequest(kind: kind))
        if let data = try? JSONEncoder.macForge.encode(requests) {
            UserDefaults.standard.set(data, forKey: pendingRequestsKey)
            NotificationCenter.default.post(name: Self.didEnqueueNotification, object: nil)
        }
    }

    func drain() -> [MacForgeCommandRequest] {
        let requests = pendingRequests().sorted { $0.createdAt < $1.createdAt }
        UserDefaults.standard.removeObject(forKey: pendingRequestsKey)
        return requests
    }

    private func pendingRequests() -> [MacForgeCommandRequest] {
        guard let data = UserDefaults.standard.data(forKey: pendingRequestsKey),
              let requests = try? JSONDecoder.macForge.decode([MacForgeCommandRequest].self, from: data) else {
            return []
        }
        return requests
    }
}

@available(macOS 14.0, *)
struct ToggleNotchShelfIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notch Shelf"
    static var description = IntentDescription("Toggle MacForge's floating Notch Shelf.")

    func perform() async throws -> some IntentResult {
        MacForgeCommandBus.shared.enqueue(.toggleNotchShelf)
        return .result()
    }
}
