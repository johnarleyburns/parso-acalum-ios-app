import Foundation

enum MockData {
    static let pills: [Pill] = PillRegistry.all

    static var tracks: [Track] { makeMockTracks() }

    private static func makeMockTracks() -> [Track] {
        let mm1 = MoodMatch(
            index: 87,
            summary: "Strong acoustic + mood match",
            components: [
                MoodComponent(label: "Acoustic character", detail: "cosine 0.78", share: 78, matched: true),
                MoodComponent(label: "Instrument: Guitar", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Mood: Calm", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Mood: Romantic", detail: "tag present", share: 100, matched: true),
            ],
            context: ["Fresh — not played in your last 300"]
        )
        let mm2 = MoodMatch(
            index: 85,
            summary: "Strong acoustic + mood match",
            components: [
                MoodComponent(label: "Acoustic character", detail: "cosine 0.74", share: 74, matched: true),
                MoodComponent(label: "Instrument: Piano", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Mood: Romantic", detail: "tag present", share: 100, matched: true),
            ],
            context: ["Fresh — not played in your last 300"]
        )
        let mm3 = MoodMatch(
            index: 72,
            summary: "Good acoustic match, partial mood",
            components: [
                MoodComponent(label: "Acoustic character", detail: "cosine 0.61", share: 61, matched: true),
                MoodComponent(label: "Instrument: Piano", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Mood: Melancholy", detail: "tag present", share: 100, matched: true),
            ],
            context: ["Fresh — not played in your last 300"]
        )
        let mm4 = MoodMatch(
            index: 68,
            summary: "Good acoustic match, partial mood",
            components: [
                MoodComponent(label: "Acoustic character", detail: "cosine 0.56", share: 56, matched: true),
                MoodComponent(label: "Instrument: Choir", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Mood: Sacred", detail: "tag present", share: 100, matched: true),
            ],
            context: ["Fresh — not played in your last 300"]
        )
        let mm5 = MoodMatch(
            index: 78,
            summary: "Good acoustic match, partial mood",
            components: [
                MoodComponent(label: "Acoustic character", detail: "cosine 0.68", share: 68, matched: true),
                MoodComponent(label: "Instrument: Piano", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Mood: Melancholy", detail: "tag present", share: 100, matched: true),
                MoodComponent(label: "Context: Late Night", detail: "tag present", share: 100, matched: true),
            ],
            context: ["Fresh — not played in your last 300"]
        )

        return [
            Track(
                id: "track_001",
                title: "Recuerdos de la Alhambra",
                composer: "Francisco Tarrega",
                performer: "Andres Segovia",
                sourceName: "Internet Archive",
                sourceURL: URL(string: "https://archive.org/details/RecuerdosDeLaAlhambra"),
                audioURL: URL(string: "https://archive.org/download/78_recuerdos-de-la-alhambra_andres-segovia-tarrega_gbia0002029a/Recuerdos%20de%20la%20Alhambra%20-%20Andr%C3%A9s%20Segovia-restored.mp3")!,
                durationSeconds: 326,
                artworkURL: nil,
                license: "Public Domain",
                year: 1927,
                explanation: TrackExplanation(
                    reasons: ["Matches guitar", "Matches calm mood", "Classic Spanish guitar repertoire"],
                    matchedPills: ["Guitar", "Calm"],
                    similarityScore: 0.91,
                    userTasteScore: 0.74
                ),
                moodMatch: mm1
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
                artworkURL: nil,
                license: "Public Domain",
                year: 1951,
                explanation: TrackExplanation(
                    reasons: ["Matches piano", "Calm and romantic mood", "Impressionist masterpiece"],
                    matchedPills: ["Piano", "Calm", "Romantic"],
                    similarityScore: 0.88,
                    userTasteScore: 0.80
                ),
                moodMatch: mm2
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
                artworkURL: nil,
                license: "Public Domain",
                year: 1888,
                explanation: TrackExplanation(
                    reasons: ["Matches piano", "Melancholy mood", "Minimalist and reflective"],
                    matchedPills: ["Piano", "Melancholy"],
                    similarityScore: 0.85,
                    userTasteScore: 0.72
                ),
                moodMatch: mm3
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
                artworkURL: nil,
                license: "Public Domain",
                year: 1936,
                explanation: TrackExplanation(
                    reasons: ["Matches choir/vocal", "Sacred mood", "Romantic era"],
                    matchedPills: ["Choir", "Sacred"],
                    similarityScore: 0.82,
                    userTasteScore: 0.68
                ),
                moodMatch: mm4
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
                artworkURL: nil,
                license: "Public Domain",
                year: 1934,
                explanation: TrackExplanation(
                    reasons: ["Matches piano", "Melancholy and romantic", "Late night listening"],
                    matchedPills: ["Piano", "Melancholy", "Late Night"],
                    similarityScore: 0.89,
                    userTasteScore: 0.76
                ),
                moodMatch: mm5
            ),
        ]
    }
}
