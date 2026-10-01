import Foundation

/// Predefined project templates for quick start (F-02)
struct ProjectTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let bpm: Int
    let keyRoot: String
    let keyMode: KeyMode
    let timeTop: Int
    let timeBottom: Int
    let sections: [(name: String, bars: Int, colorHex: String)]
    let tags: [String]
    
    static let templates: [ProjectTemplate] = [
        ProjectTemplate(
            name: String(localized: "Pop Song"),
            description: String(localized: "Standard verse-chorus structure"),
            icon: "music.mic",
            bpm: 120,
            keyRoot: "C",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "Intro", comment: "Song section name"), 4, "#4A90D9"),
                (String(localized: "Verse 1", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Verse 2", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Bridge", comment: "Song section name"), 4, "#9B59B6"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Outro", comment: "Song section name"), 4, "#4A90D9"),
            ],
            tags: ["pop"]
        ),
        ProjectTemplate(
            name: String(localized: "Rock Anthem"),
            description: String(localized: "Driving rock structure with solo section"),
            icon: "guitars.fill",
            bpm: 140,
            keyRoot: "E",
            keyMode: .minor,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "Intro Riff", comment: "Song section name"), 4, "#D94A4A"),
                (String(localized: "Verse 1", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Pre-Chorus", comment: "Song section name"), 4, "#D9A04A"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Verse 2", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Pre-Chorus", comment: "Song section name"), 4, "#D9A04A"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Solo", comment: "Song section name"), 8, "#9B59B6"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Outro", comment: "Song section name"), 4, "#4A90D9"),
            ],
            tags: ["rock"]
        ),
        ProjectTemplate(
            name: String(localized: "Jazz Standard"),
            description: String(localized: "32-bar AABA form"),
            icon: "pianokeys",
            bpm: 140,
            keyRoot: "F",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "A1", comment: "Song section name"), 8, "#D9A04A"),
                (String(localized: "A2", comment: "Song section name"), 8, "#D9A04A"),
                (String(localized: "B (Bridge)", comment: "Song section name"), 8, "#9B59B6"),
                (String(localized: "A3", comment: "Song section name"), 8, "#D9A04A"),
            ],
            tags: ["jazz"]
        ),
        ProjectTemplate(
            name: String(localized: "Blues 12-Bar"),
            description: String(localized: "Classic 12-bar blues form"),
            icon: "music.quarternote.3",
            bpm: 100,
            keyRoot: "A",
            keyMode: .blues,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "12-Bar Blues", comment: "Song section name"), 12, "#4A90D9"),
            ],
            tags: ["blues"]
        ),
        ProjectTemplate(
            name: String(localized: "Ballad"),
            description: String(localized: "Slow, emotional structure"),
            icon: "heart.fill",
            bpm: 72,
            keyRoot: "G",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "Intro", comment: "Song section name"), 4, "#4A90D9"),
                (String(localized: "Verse 1", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Verse 2", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Bridge", comment: "Song section name"), 8, "#9B59B6"),
                (String(localized: "Final Chorus", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Outro", comment: "Song section name"), 4, "#4A90D9"),
            ],
            tags: ["ballad"]
        ),
        ProjectTemplate(
            name: String(localized: "EDM Drop"),
            description: String(localized: "Build-up and drop structure"),
            icon: "waveform.path.ecg",
            bpm: 128,
            keyRoot: "A",
            keyMode: .minor,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "Intro", comment: "Song section name"), 8, "#4A90D9"),
                (String(localized: "Build Up", comment: "Song section name"), 8, "#D9A04A"),
                (String(localized: "Drop", comment: "Song section name"), 16, "#D94A4A"),
                (String(localized: "Break", comment: "Song section name"), 8, "#6B7B6B"),
                (String(localized: "Build Up 2", comment: "Song section name"), 8, "#D9A04A"),
                (String(localized: "Drop 2", comment: "Song section name"), 16, "#D94A4A"),
                (String(localized: "Outro", comment: "Song section name"), 8, "#4A90D9"),
            ],
            tags: ["edm", "electronic"]
        ),
        ProjectTemplate(
            name: String(localized: "Latin Rhythm"),
            description: String(localized: "Son/Salsa influenced structure"),
            icon: "music.note.list",
            bpm: 180,
            keyRoot: "C",
            keyMode: .minor,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                (String(localized: "Intro", comment: "Song section name"), 8, "#4A90D9"),
                (String(localized: "Verse (Cuerpo)", comment: "Song section name"), 16, "#6B7B6B"),
                (String(localized: "Coro (Chorus)", comment: "Song section name"), 8, "#D94A4A"),
                (String(localized: "Montuno", comment: "Song section name"), 16, "#9B59B6"),
                (String(localized: "Mambo", comment: "Song section name"), 8, "#D9A04A"),
                (String(localized: "Coro Final", comment: "Song section name"), 8, "#D94A4A"),
            ],
            tags: ["latin", "salsa"]
        ),
        ProjectTemplate(
            name: String(localized: "Blank Canvas"),
            description: String(localized: "Start from scratch"),
            icon: "doc.text",
            bpm: 120,
            keyRoot: "C",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [],
            tags: []
        ),
    ]
}
