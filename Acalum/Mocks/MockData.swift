import Foundation

enum MockData {
    static let pills: [Pill] = [
        Pill(id: "instrument:guitar", label: "Guitar", category: .instrument, semanticPhrase: "solo classical guitar"),
        Pill(id: "instrument:piano", label: "Piano", category: .instrument, semanticPhrase: "solo piano"),
        Pill(id: "instrument:violin", label: "Violin", category: .instrument, semanticPhrase: "solo violin, strings"),
        Pill(id: "instrument:choir", label: "Choir", category: .instrument, semanticPhrase: "choral voices, choir"),
        Pill(id: "instrument:organ", label: "Organ", category: .instrument, semanticPhrase: "pipe organ, church organ"),
        Pill(id: "instrument:orchestra", label: "Orchestra", category: .instrument, semanticPhrase: "full orchestra, symphonic"),
        Pill(id: "mood:calm", label: "Calm", category: .mood, semanticPhrase: "calm, peaceful"),
        Pill(id: "mood:melancholy", label: "Melancholy", category: .mood, semanticPhrase: "melancholy, sad, reflective"),
        Pill(id: "mood:joyful", label: "Joyful", category: .mood, semanticPhrase: "joyful, uplifting, happy"),
        Pill(id: "mood:sacred", label: "Sacred", category: .mood, semanticPhrase: "sacred, spiritual, devotional"),
        Pill(id: "mood:romantic", label: "Romantic", category: .mood, semanticPhrase: "romantic, tender, warm"),
        Pill(id: "mood:nostalgic", label: "Nostalgic", category: .mood, semanticPhrase: "nostalgic, wistful, old-fashioned"),
        Pill(id: "context:reading", label: "Reading", category: .context, semanticPhrase: "reading music, unobtrusive background music"),
        Pill(id: "context:sleep", label: "Sleep", category: .context, semanticPhrase: "sleep music, soothing, very quiet"),
        Pill(id: "context:focus", label: "Focus", category: .context, semanticPhrase: "focus music, concentration, ambient"),
        Pill(id: "context:rainy_day", label: "Rainy Day", category: .context, semanticPhrase: "rainy day, contemplative, indoor"),
        Pill(id: "context:late_night", label: "Late Night", category: .context, semanticPhrase: "late night, quiet, intimate"),
        Pill(id: "era:baroque", label: "Baroque", category: .era, semanticPhrase: "baroque, harpsichord, counterpoint, 1600s 1700s"),
        Pill(id: "era:romantic", label: "Romantic Era", category: .era, semanticPhrase: "romantic era classical music, 1800s"),
        Pill(id: "era:medieval", label: "Medieval", category: .era, semanticPhrase: "medieval, ancient, gregorian, early music"),
        Pill(id: "era:jazz_age", label: "Jazz Age", category: .era, semanticPhrase: "jazz age, 1920s, swing, early jazz"),
        Pill(id: "era:early_1900s", label: "Early 1900s", category: .era, semanticPhrase: "early 1900s, vintage recordings, old recordings"),
    ]

    static let tracks: [Track] = [
        Track(
            id: "track_001",
            title: "Recuerdos de la Alhambra",
            composer: "Francisco Tarrega",
            performer: "Andres Segovia",
            sourceName: "Internet Archive",
            sourceURL: URL(string: "https://archive.org/details/RecuerdosDeLaAlhambra"),
            audioURL: URL(string: "https://archive.org/download/78_recuerdos-de-la-alhambra_andres-segovia-tarrega_gbia0002029a/Recuerdos%20de%20la%20Alhambra%20-%20Andr%C3%A9s%20Segovia-restored.mp3")!,
            durationSeconds: 326,
            license: "Public Domain",
            year: 1927,
            explanation: TrackExplanation(
                reasons: ["Matches guitar", "Matches calm mood", "Classic Spanish guitar repertoire"],
                matchedPills: ["Guitar", "Calm"],
                similarityScore: 0.91,
                userTasteScore: 0.74
            )
        ),
        Track(
            id: "track_002",
            title: "Clair de Lune",
            composer: "Claude Debussy",
            performer: "Walter Gieseking",
            sourceName: "Musopen",
            sourceURL: URL(string: "https://musopen.org/music/2034-suite-bergamasque-l-75/"),
            audioURL: URL(string: "https://archive.org/download/78_clair-de-lune_walter-gieseking-debussy_gbia0001791a/Clair%20de%20Lune%20-%20Walter%20Gieseking-restored.mp3")!,
            durationSeconds: 302,
            license: "Public Domain",
            year: 1951,
            explanation: TrackExplanation(
                reasons: ["Matches piano", "Calm and romantic mood", "Impressionist masterpiece"],
                matchedPills: ["Piano", "Calm", "Romantic"],
                similarityScore: 0.88,
                userTasteScore: 0.80
            )
        ),
        Track(
            id: "track_003",
            title: "Gymnopédie No. 1",
            composer: "Erik Satie",
            performer: "Reinbert de Leeuw",
            sourceName: "Internet Archive",
            sourceURL: URL(string: "https://archive.org/details/gymnopedies"),
            audioURL: URL(string: "https://archive.org/download/78_gymnopedie-no1_reinbert-de-leeuw-erik-satie_gbia0001234a/Gymnopedie%20No.1%20-%20restored.mp3")!,
            durationSeconds: 194,
            license: "Public Domain",
            year: 1888,
            explanation: TrackExplanation(
                reasons: ["Matches piano", "Melancholy mood", "Minimalist and reflective"],
                matchedPills: ["Piano", "Melancholy"],
                similarityScore: 0.85,
                userTasteScore: 0.72
            )
        ),
        Track(
            id: "track_004",
            title: "Ave Maria",
            composer: "Franz Schubert",
            performer: "Marian Anderson",
            sourceName: "Internet Archive",
            sourceURL: URL(string: "https://archive.org/details/ave-maria-schubert"),
            audioURL: URL(string: "https://archive.org/download/78_ave-maria_marian-anderson-schubert_gbia0005678a/Ave%20Maria%20-%20Marian%20Anderson-restored.mp3")!,
            durationSeconds: 278,
            license: "Public Domain",
            year: 1936,
            explanation: TrackExplanation(
                reasons: ["Matches choir/vocal", "Sacred mood", "Romantic era"],
                matchedPills: ["Choir", "Sacred"],
                similarityScore: 0.82,
                userTasteScore: 0.68
            )
        ),
        Track(
            id: "track_005",
            title: "Moonlight Sonata",
            composer: "Ludwig van Beethoven",
            performer: "Artur Schnabel",
            sourceName: "Internet Archive",
            sourceURL: URL(string: "https://archive.org/details/moonlight-sonata"),
            audioURL: URL(string: "https://archive.org/download/78_sonata-no14-moonlight_artur-schnabel-beethoven_gbia0003456a/Moonlight%20Sonata%20-%20Artur%20Schnabel-restored.mp3")!,
            durationSeconds: 378,
            license: "Public Domain",
            year: 1934,
            explanation: TrackExplanation(
                reasons: ["Matches piano", "Melancholy and romantic", "Late night listening"],
                matchedPills: ["Piano", "Melancholy", "Late Night"],
                similarityScore: 0.89,
                userTasteScore: 0.76
            )
        ),
    ]
}
