import Foundation

enum PillCategory: String, Codable, CaseIterable {
    case instrument
    case mood
    case era
    case context
    case texture
}

struct Pill: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let category: PillCategory
}
