import Foundation

enum PermissionStatus: String, Codable, CaseIterable, Hashable {
    case granted
    case missing
    case limited
    case disabled
    case unknown

    var label: String {
        switch self {
        case .granted: "Granted"
        case .missing: "Missing"
        case .limited: "Limited"
        case .disabled: "Disabled"
        case .unknown: "Unknown"
        }
    }
}

struct PermissionState: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var status: PermissionStatus
    var detail: String
    var isRequired: Bool
}
