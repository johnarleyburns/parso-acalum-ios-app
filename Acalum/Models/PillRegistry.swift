import Foundation

/// Catalog-backed discovery pills. Each pill carries:
/// - `embeddingPhrase`: free text fed to CLAP for semantic retrieval.
/// - `metadataTerms`: strict terms that may assert a literal "tag present" match.
///   Generic words (music, classical, old, early) are deliberately avoided so a
///   pill never claims a false metadata match.
/// Listening Mode pills are semantic-only: they shape direction via CLAP but
/// never assert a metadata match.
///
/// Counts referenced below are include/default embedded tracks in the current
/// indexer snapshot and are used to keep the set grounded in what is listenable.
enum PillRegistry {
    static let all: [Pill] = sound + style + tradition + listeningMode

    // MARK: Sound — instruments and ensembles

    static let sound: [Pill] = [
        Pill(id: "sound:orchestra", label: "Orchestra", category: .sound,
             embeddingPhrase: "full orchestra, symphonic ensemble",
             metadataTerms: ["orchestra", "orchestral", "symphony", "symphonic"]),
        Pill(id: "sound:choir", label: "Vocal / Choir", category: .sound,
             embeddingPhrase: "choral voices, choir, vocal ensemble",
             metadataTerms: ["choir", "choral", "chorus", "vocal"]),
        Pill(id: "sound:piano", label: "Piano", category: .sound,
             embeddingPhrase: "solo piano",
             metadataTerms: ["piano", "pianoforte"]),
        Pill(id: "sound:organ", label: "Organ", category: .sound,
             embeddingPhrase: "pipe organ, church organ",
             metadataTerms: ["organ"]),
        Pill(id: "sound:guitar", label: "Guitar", category: .sound,
             embeddingPhrase: "classical guitar, acoustic guitar",
             metadataTerms: ["guitar"]),
    ]

    // MARK: Style — genre / form / family

    static let style: [Pill] = [
        Pill(id: "style:classical", label: "Classical", category: .style,
             embeddingPhrase: "classical music, art music",
             metadataTerms: ["classical"]),
        Pill(id: "style:jazz", label: "Jazz", category: .style,
             embeddingPhrase: "jazz",
             metadataTerms: ["jazz"]),
        Pill(id: "style:opera", label: "Opera", category: .style,
             embeddingPhrase: "opera, operatic aria",
             metadataTerms: ["opera", "operatic", "aria"]),
        Pill(id: "style:stage_screen", label: "Stage & Screen", category: .style,
             embeddingPhrase: "stage and screen, film score, musical theatre",
             metadataTerms: ["stage", "screen", "soundtrack", "film score", "broadway", "musical theatre"]),
        Pill(id: "style:easy_listening", label: "Easy Listening", category: .style,
             embeddingPhrase: "easy listening, light orchestral",
             metadataTerms: ["easy listening"]),
    ]

    // MARK: Tradition — period, regional tradition, or collection type

    static let tradition: [Pill] = [
        Pill(id: "tradition:baroque", label: "Baroque", category: .tradition,
             embeddingPhrase: "baroque era, harpsichord, counterpoint",
             metadataTerms: ["baroque"]),
        Pill(id: "tradition:romantic", label: "Romantic Era", category: .tradition,
             embeddingPhrase: "romantic era classical music, nineteenth century",
             metadataTerms: ["romantic"]),
        Pill(id: "tradition:folk_world", label: "Folk & World", category: .tradition,
             embeddingPhrase: "folk and world music",
             metadataTerms: ["folk", "world music"]),
        Pill(id: "tradition:latin_bossa", label: "Latin / Bossa", category: .tradition,
             embeddingPhrase: "latin music, bossa nova",
             metadataTerms: ["latin", "bossa"]),
        Pill(id: "tradition:african", label: "African Music", category: .tradition,
             embeddingPhrase: "african music",
             metadataTerms: ["african"]),
        Pill(id: "tradition:gregorian", label: "Gregorian Chant", category: .tradition,
             embeddingPhrase: "gregorian chant, plainsong",
             metadataTerms: ["gregorian", "plainchant", "plainsong"]),
        Pill(id: "tradition:indian_classical", label: "Indian Classical", category: .tradition,
             embeddingPhrase: "indian classical music, raga",
             metadataTerms: ["raga", "sitar", "hindustani", "carnatic", "indian classical"]),
        Pill(id: "tradition:gamelan", label: "Gamelan", category: .tradition,
             embeddingPhrase: "gamelan, indonesian percussion ensemble",
             metadataTerms: ["gamelan"]),
    ]

    // MARK: Listening Mode — semantic modifiers (CLAP direction only)

    static let listeningMode: [Pill] = [
        Pill(id: "mode:quiet", label: "Quiet", category: .listeningMode,
             embeddingPhrase: "calm, quiet, peaceful, gentle",
             metadataTerms: []),
        Pill(id: "mode:focus", label: "Focus", category: .listeningMode,
             embeddingPhrase: "focus music, concentration, unobtrusive",
             metadataTerms: []),
        Pill(id: "mode:reading", label: "Reading", category: .listeningMode,
             embeddingPhrase: "reading music, unobtrusive background music",
             metadataTerms: []),
        Pill(id: "mode:sleep", label: "Sleep", category: .listeningMode,
             embeddingPhrase: "sleep music, soothing, very quiet",
             metadataTerms: []),
        Pill(id: "mode:explore", label: "Explore", category: .listeningMode,
             embeddingPhrase: "adventurous, unusual, surprising public domain recordings",
             metadataTerms: []),
    ]
}
