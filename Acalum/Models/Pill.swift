import Foundation

enum PillCategory: String, Codable, CaseIterable {
    // New catalog-backed categories (Fit/Direction model).
    case sound
    case style
    case tradition
    case listeningMode

    // Legacy categories kept for compatibility with saved state and tests.
    case instrument
    case mood
    case era
    case context
    case texture

    /// User-facing section header.
    var displayName: String {
        switch self {
        case .sound: return "Sound"
        case .style: return "Style"
        case .tradition: return "Tradition"
        case .listeningMode: return "Listening Mode"
        case .instrument: return "Instrument"
        case .mood: return "Mood"
        case .era: return "Era"
        case .context: return "Context"
        case .texture: return "Texture"
        }
    }
}

struct Pill: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let category: PillCategory

    /// Free text fed into the CLAP query (drives semantic retrieval).
    let embeddingPhrase: String
    /// Strict catalog terms used to claim a literal "tag present" match.
    /// Empty means the pill is semantic-only (shapes direction via CLAP, never
    /// asserts a metadata match — e.g. Listening Mode pills).
    let metadataTerms: [String]
    /// Terms that suppress a metadata match if present in the row.
    let negativeTerms: [String]

    /// Backward-compatible accessor for the old single-phrase contract.
    var semanticPhrase: String { embeddingPhrase }
    /// True when this pill can assert a literal catalog/tag match.
    var hasMetadataTerms: Bool { !metadataTerms.isEmpty }

    init(
        id: String,
        label: String,
        category: PillCategory,
        embeddingPhrase: String,
        metadataTerms: [String],
        negativeTerms: [String] = []
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.embeddingPhrase = embeddingPhrase
        self.metadataTerms = metadataTerms
        self.negativeTerms = negativeTerms
    }

    /// Legacy initializer: a single semantic phrase, no metadata terms.
    init(id: String, label: String, category: PillCategory, semanticPhrase: String = "") {
        self.id = id
        self.label = label
        self.category = category
        self.embeddingPhrase = semanticPhrase
        self.metadataTerms = []
        self.negativeTerms = []
    }
}

typealias DiscoveryPill = Pill
