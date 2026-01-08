# 📚 Ejemplos de Uso - Nuevas Mejoras de Suonote

## 🎨 1. USANDO EL DESIGN SYSTEM

### Antes vs Después - Botones

#### ❌ ANTES (Código inconsistente):
```swift
Button {
    action()
} label: {
    HStack {
        Image(systemName: "plus.circle.fill")
        Text("Add Section")
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .background(
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    )
}
```

#### ✅ AHORA (Una línea, consistente):
```swift
PrimaryButton("Add Section", icon: "plus.circle.fill") {
    action()
}
```

---

### Cards y Contenedores

#### ✅ Glass Card Effect:
```swift
VStack {
    Text("Content")
    Text("More content")
}
.padding(DesignSystem.Spacing.lg)
.glassStyle()
```

#### ✅ Colored Card:
```swift
ChordInfoView()
    .padding(DesignSystem.Spacing.md)
    .cardStyle(color: DesignSystem.Colors.primary)
```

---

### Spacing Consistente

#### ❌ ANTES:
```swift
VStack(spacing: 16) {  // ¿Por qué 16?
    Text("Title")
        .padding(.bottom, 12)  // ¿Por qué 12?
    Text("Subtitle")
        .padding(.top, 8)      // ¿Por qué 8?
}
```

#### ✅ AHORA:
```swift
VStack(spacing: DesignSystem.Spacing.md) {
    Text("Title")
        .padding(.bottom, DesignSystem.Spacing.sm)
    Text("Subtitle")
        .padding(.top, DesignSystem.Spacing.xs)
}
```

---

### Animaciones Suaves

#### ✅ Botón con Press Animation:
```swift
Button("Play") { }
    .animatedPress()  // Automáticamente escala a 0.95 al presionar
```

#### ✅ Animación Consistente:
```swift
withAnimation(DesignSystem.Animations.smoothSpring) {
    isExpanded.toggle()
}
```

---

## 🎵 2. USANDO MÚSICA THEORY UTILS

### Análisis de Escalas

```swift
// Obtener todas las notas de una escala
let cMajorNotes = NoteUtils.scaleNotes(root: "C", scaleType: .major)
// ["C", "D", "E", "F", "G", "A", "B"]

let cMinorNotes = NoteUtils.scaleNotes(root: "C", scaleType: .naturalMinor)
// ["C", "D", "Eb", "F", "G", "Ab", "Bb"]

// Verificar si una nota está en la escala
let isInKey = NoteUtils.isInScale(note: "F#", root: "D", scaleType: .major)
// true (F# está en D major)
```

---

### Transposición y Cálculos

```swift
// Transponer una nota
let transposed = NoteUtils.transpose(note: "C", semitones: 7)
// "G" (quinta perfecta)

// Calcular intervalo entre notas
let interval = NoteUtils.intervalBetween(from: "C", to: "G")
// 7 (semitones)

// Obtener enarmónico
let enharmonic = NoteUtils.enharmonic(of: "C#")
// "Db"
```

---

### Análisis de Acordes

```swift
// Obtener las notas de un acorde
let notes = ChordUtils.getChordNotes(root: "C", quality: .major7)
// ["C", "E", "G", "B"]

// Ver si un acorde contiene una nota
let contains = ChordUtils.chordContains(
    root: "C", 
    quality: .major, 
    note: "E"
)
// true

// Encontrar notas comunes entre acordes
let common = ChordUtils.commonNotes(
    chord1Root: "C", chord1Quality: .major,
    chord2Root: "F", chord2Quality: .major
)
// ["C"] (nota compartida)

// Voice leading - cuán diferente son dos acordes
let distance = ChordUtils.voiceLeadingDistance(
    from: ("C", .major),
    to: ("Am", .minor)
)
// 1 (solo una nota diferente - voice leading suave)
```

---

### Ritmo y Tempo

```swift
// Convertir beats a notación
let notation = RhythmUtils.beatsToNotation(beats: 0.5)
// "8th note"

// Calcular duración en segundos
let duration = RhythmUtils.beatsToSeconds(beats: 4, bpm: 120)
// 2.0 segundos

// Cuantizar beats al subdivision más cercano
let quantized = RhythmUtils.quantize(beats: 1.37, subdivision: 0.25)
// 1.25 (redondeado a 1/4 beat)

// Descripción de tempo
let tempoDesc = TempoUtils.tempoDescription(for: 140)
// "Allegro (120-168)"
```

---

## 🎼 3. SUGERENCIAS DE ACORDES INTELIGENTES

### Contexto Básico

```swift
let engine = ChordSuggestionEngine.self

// Obtener acordes diatónicos
let diatonic = engine.diatonicChords(forKey: "C", mode: .major)
// [
//   ChordSuggestion(root: "C", quality: .major, reason: "I - Tonic"),
//   ChordSuggestion(root: "D", quality: .minor, reason: "ii - Supertonic"),
//   ChordSuggestion(root: "E", quality: .minor, reason: "iii - Mediant"),
//   ...
// ]
```

---

### Sugerencias Contextuales

```swift
// Sugerir siguiente acorde basado en contexto
let lastChord = ChordEvent(
    barIndex: 0, 
    beatOffset: 0, 
    duration: 1,
    root: "C", 
    quality: .major
)

let suggestions = engine.suggestNextChord(
    after: lastChord,
    inKey: "C",
    mode: .major
)

// Retorna:
// [
//   ChordSuggestion(root: "F", quality: .major, 
//                   reason: "IV - Subdominant movement", confidence: 0.95),
//   ChordSuggestion(root: "G", quality: .major,
//                   reason: "V - Dominant movement", confidence: 0.95),
//   ChordSuggestion(root: "A", quality: .minor,
//                   reason: "vi - Deceptive resolution", confidence: 0.85)
// ]
```

---

### Progresiones Populares

```swift
let progressions = engine.popularProgressions(forKey: "C", mode: .major)

// Retorna:
// [
//   ("I-V-vi-IV (Pop)", [C, G, Am, F]),
//   ("I-IV-V (Classic)", [C, F, G]),
//   ("vi-IV-I-V (Sensitive)", [Am, F, C, G]),
//   ...
// ]

// Uso en UI:
ForEach(progressions, id: \.name) { progression in
    Button(progression.name) {
        applyProgression(progression.progression)
    }
}
```

---

### Análisis de Progresión

```swift
// Analizar una progresión existente
let chords: [ChordEvent] = section.chordEvents

let analysis = engine.analyzeProgression(
    chords,
    inKey: "C",
    mode: .major
)

// Mostrar resultados
Text("Diatonic: \(analysis.diatonicPercentage, specifier: "%.0f")%")
Text("Roman Numerals: \(analysis.romanNumeralString)")
// "I - IV - V - I"

// UI feedback
if analysis.diatonicPercentage > 80 {
    Badge("In Key", color: .green)
} else {
    Badge("Chromatic", color: .orange)
}
```

---

## 🎯 4. EJEMPLO COMPLETO - Chord Selector View

```swift
import SwiftUI

struct ImprovedChordSelectorView: View {
    @State private var selectedRoot = "C"
    @State private var selectedQuality: ChordQuality = .major
    @State private var suggestions: [ChordSuggestion] = []
    
    let project: Project
    let lastChord: ChordEvent?
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header con glassmorphism
            headerSection
                .padding(DesignSystem.Spacing.md)
                .glassStyle()
            
            // Chord Preview
            chordPreview
                .padding(DesignSystem.Spacing.lg)
                .cardStyle(color: selectedQuality.color)
            
            // Smart Suggestions
            suggestionsSection
                .padding(DesignSystem.Spacing.md)
                .glassStyle()
            
            // Action Buttons
            actionButtons
        }
        .padding(DesignSystem.Spacing.xl)
        .onAppear(perform: loadSuggestions)
    }
    
    private var headerSection: some View {
        HStack {
            Text("Add Chord")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(.white)
            
            Spacer()
            
            Badge("\(project.keyRoot)\(project.keyMode == .minor ? "m" : "")",
                  color: DesignSystem.Colors.primary)
        }
    }
    
    private var chordPreview: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Chord Symbol
            Text(chordDisplay)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
            
            // Notes in chord
            let notes = ChordUtils.getChordNotes(
                root: selectedRoot,
                quality: selectedQuality
            )
            
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(notes, id: \.self) { note in
                    Badge(note, color: DesignSystem.Colors.accent)
                }
            }
            
            // Quality description
            Text(selectedQuality.displayName)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text("Smart Suggestions")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(.white)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(suggestions) { suggestion in
                        suggestionChip(suggestion)
                            .animatedPress()
                    }
                }
            }
        }
    }
    
    private func suggestionChip(_ suggestion: ChordSuggestion) -> some View {
        Button {
            withAnimation(DesignSystem.Animations.smoothSpring) {
                selectedRoot = suggestion.root
                selectedQuality = suggestion.quality
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text(suggestion.display)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundStyle(.white)
                
                Text(suggestion.reason)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Confidence indicator
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(Double(index) < suggestion.confidence * 5 ?
                                  DesignSystem.Colors.accent :
                                  DesignSystem.Colors.surface)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .glassStyle(cornerRadius: DesignSystem.CornerRadius.md)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            SecondaryButton("Cancel", icon: "xmark") {
                dismiss()
            }
            
            PrimaryButton("Add Chord", icon: "checkmark") {
                addChord()
            }
        }
    }
    
    private var chordDisplay: String {
        selectedRoot + selectedQuality.symbol
    }
    
    private func loadSuggestions() {
        suggestions = ChordSuggestionEngine.suggestNextChord(
            after: lastChord,
            inKey: project.keyRoot,
            mode: project.keyMode
        )
    }
    
    private func addChord() {
        // Implementation
    }
    
    @Environment(\.dismiss) private var dismiss
}

// Extension para color por chord quality
extension ChordQuality {
    var color: Color {
        switch category {
        case .triad: return DesignSystem.Colors.primary
        case .suspended: return DesignSystem.Colors.accent
        case .seventh: return DesignSystem.Colors.secondary
        case .extended: return DesignSystem.Colors.success
        }
    }
}
```

---

## 🎨 5. EMPTY STATES CON ESTILO

```swift
// Empty state elegante
if project.arrangementItems.isEmpty {
    EmptyStateView(
        icon: "music.note.list",
        title: "No Sections Yet",
        message: "Start composing by adding your first section",
        actionTitle: "Add Section"
    ) {
        showSectionCreator = true
    }
} else {
    // Content
}
```

---

## 📊 6. ANÁLISIS VISUAL DE PROGRESIÓN

```swift
struct ProgressionAnalysisCard: View {
    let analysis: ProgressionAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(DesignSystem.Colors.info)
                Text("Progression Analysis")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(.white)
            }
            
            // Stats
            HStack(spacing: DesignSystem.Spacing.lg) {
                statItem(
                    title: "Total Chords",
                    value: "\(analysis.totalChords)",
                    color: DesignSystem.Colors.primary
                )
                
                statItem(
                    title: "In Key",
                    value: "\(Int(analysis.diatonicPercentage))%",
                    color: analysis.diatonicPercentage > 80 ?
                           DesignSystem.Colors.success :
                           DesignSystem.Colors.warning
                )
            }
            
            // Roman numerals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(analysis.romanNumerals, id: \.self) { numeral in
                        Text(numeral)
                            .font(DesignSystem.Typography.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xxs)
                            .glassStyle(cornerRadius: DesignSystem.CornerRadius.sm)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: DesignSystem.Colors.info)
    }
    
    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

## 🎯 RESUMEN

Con estas mejoras, ahora puedes:

✅ **Escribir menos código** usando componentes reutilizables
✅ **Mantener consistencia** visual en toda la app
✅ **Agregar inteligencia musical** fácilmente
✅ **Crear UIs complejas** con menos esfuerzo
✅ **Animaciones suaves** sin configuración manual
✅ **Análisis musical profundo** con pocas líneas

Todo el código es **type-safe**, **bien documentado** y **fácil de mantener**! 🚀
