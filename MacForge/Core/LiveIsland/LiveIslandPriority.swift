import Foundation

enum LiveIslandPriority: Int, Codable, Comparable, Hashable {
    case idle = 0
    case backgroundMedia = 20
    case media = 30
    case download = 40
    case timer = 45
    case task = 60
    case error = 100

    static func < (lhs: LiveIslandPriority, rhs: LiveIslandPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
