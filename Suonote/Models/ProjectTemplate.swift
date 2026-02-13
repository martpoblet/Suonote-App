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
            name: "Pop Song",
            description: "Standard verse-chorus structure",
            icon: "music.mic",
            bpm: 120,
            keyRoot: "C",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("Intro", 4, "#4A90D9"),
                ("Verse 1", 8, "#6B7B6B"),
                ("Chorus", 8, "#D94A4A"),
                ("Verse 2", 8, "#6B7B6B"),
                ("Chorus", 8, "#D94A4A"),
                ("Bridge", 4, "#9B59B6"),
                ("Chorus", 8, "#D94A4A"),
                ("Outro", 4, "#4A90D9"),
            ],
            tags: ["pop"]
        ),
        ProjectTemplate(
            name: "Rock Anthem",
            description: "Driving rock structure with solo section",
            icon: "guitars.fill",
            bpm: 140,
            keyRoot: "E",
            keyMode: .minor,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("Intro Riff", 4, "#D94A4A"),
                ("Verse 1", 8, "#6B7B6B"),
                ("Pre-Chorus", 4, "#D9A04A"),
                ("Chorus", 8, "#D94A4A"),
                ("Verse 2", 8, "#6B7B6B"),
                ("Pre-Chorus", 4, "#D9A04A"),
                ("Chorus", 8, "#D94A4A"),
                ("Solo", 8, "#9B59B6"),
                ("Chorus", 8, "#D94A4A"),
                ("Outro", 4, "#4A90D9"),
            ],
            tags: ["rock"]
        ),
        ProjectTemplate(
            name: "Jazz Standard",
            description: "32-bar AABA form",
            icon: "pianokeys",
            bpm: 140,
            keyRoot: "F",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("A1", 8, "#D9A04A"),
                ("A2", 8, "#D9A04A"),
                ("B (Bridge)", 8, "#9B59B6"),
                ("A3", 8, "#D9A04A"),
            ],
            tags: ["jazz"]
        ),
        ProjectTemplate(
            name: "Blues 12-Bar",
            description: "Classic 12-bar blues form",
            icon: "music.quarternote.3",
            bpm: 100,
            keyRoot: "A",
            keyMode: .blues,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("12-Bar Blues", 12, "#4A90D9"),
            ],
            tags: ["blues"]
        ),
        ProjectTemplate(
            name: "Ballad",
            description: "Slow, emotional structure",
            icon: "heart.fill",
            bpm: 72,
            keyRoot: "G",
            keyMode: .major,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("Intro", 4, "#4A90D9"),
                ("Verse 1", 8, "#6B7B6B"),
                ("Chorus", 8, "#D94A4A"),
                ("Verse 2", 8, "#6B7B6B"),
                ("Chorus", 8, "#D94A4A"),
                ("Bridge", 8, "#9B59B6"),
                ("Final Chorus", 8, "#D94A4A"),
                ("Outro", 4, "#4A90D9"),
            ],
            tags: ["ballad"]
        ),
        ProjectTemplate(
            name: "EDM Drop",
            description: "Build-up and drop structure",
            icon: "waveform.path.ecg",
            bpm: 128,
            keyRoot: "A",
            keyMode: .minor,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("Intro", 8, "#4A90D9"),
                ("Build Up", 8, "#D9A04A"),
                ("Drop", 16, "#D94A4A"),
                ("Break", 8, "#6B7B6B"),
                ("Build Up 2", 8, "#D9A04A"),
                ("Drop 2", 16, "#D94A4A"),
                ("Outro", 8, "#4A90D9"),
            ],
            tags: ["edm", "electronic"]
        ),
        ProjectTemplate(
            name: "Latin Rhythm",
            description: "Son/Salsa influenced structure",
            icon: "music.note.list",
            bpm: 180,
            keyRoot: "C",
            keyMode: .minor,
            timeTop: 4,
            timeBottom: 4,
            sections: [
                ("Intro", 8, "#4A90D9"),
                ("Verse (Cuerpo)", 16, "#6B7B6B"),
                ("Coro (Chorus)", 8, "#D94A4A"),
                ("Montuno", 16, "#9B59B6"),
                ("Mambo", 8, "#D9A04A"),
                ("Coro Final", 8, "#D94A4A"),
            ],
            tags: ["latin", "salsa"]
        ),
        ProjectTemplate(
            name: "Blank Canvas",
            description: "Start from scratch",
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
