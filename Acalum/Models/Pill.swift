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
    let semanticPhrase: String

    init(id: String, label: String, category: PillCategory, semanticPhrase: String = "") {
        self.id = id
        self.label = label
        self.category = category
        self.semanticPhrase = semanticPhrase
    }
}

typealias DiscoveryPill = Pill
