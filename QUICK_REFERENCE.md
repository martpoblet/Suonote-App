# 🚀 Guía Rápida de Navegación - Suonote

## 📍 ¿Dónde Está Cada Cosa?

### 🎯 TABS PRINCIPALES (LAS MÁS IMPORTANTES)

#### ⭐ **ProjectDetailView.swift** - VISTA PRINCIPAL CON TABS
**Ubicación:** `/Suonote/Views/ProjectDetailView.swift`

**QUÉ ES:**
La vista que contiene las 3 tabs principales (Compose, Lyrics, Record)

**CÓDIGO CLAVE:**
```swift
// Línea 33-42: Switch que muestra cada tab
switch selectedTab {
    case 0: ComposeTabView(project: project)    // 🎼 TAB COMPOSE
    case 1: LyricsTabView(project: project)     // 📝 TAB LYRICS
    case 2: RecordingsTabView(project: project) // 🎙️ TAB RECORD
}

// Línea 161-167: Definición de las tabs
private var tabs: [(title: String, icon: String)] {
    [
        ("Compose", "music.note.list"),      // Tab 0
        ("Lyrics", "text.quote"),             // Tab 1
        ("Record", "waveform.circle.fill")    // Tab 2
    ]
}
```

---

### 🎼 TAB 1: COMPOSE

#### **ComposeTabView.swift**
**Ubicación:** `/Suonote/Views/ComposeTabView.swift`

**COMPONENTES PRINCIPALES:**

1. **Top Controls Bar** (línea ~83)
   - Botón exportar
   - Selector de tonalidad
   - Indicador de BPM

2. **Arrangement Timeline** (línea ~252)
   - Lista de secciones en orden
   - Tarjetas arrastrables
   - Botón "Add Section"

3. **Section Editor** (línea ~392)
   - Chord Grid (cuadrícula de acordes)
   - Botón de grabación
   - Información de la sección

**VISTAS RELACIONADAS:**

**ChordPaletteSheet** (línea ~900)
- Modal para agregar/editar acordes
- Secciones: Preview, Suggestions, Root, Quality, Extensions, Duration

**ChordGridView** (línea ~485)
- Cuadrícula que muestra acordes por compás
- Botones "+" para agregar acordes
- Indicador de beats usados

**SectionCreatorView** (línea ~690)
- Modal para crear nueva sección
- Campos: nombre, número de compases, plantilla

---

### 📝 TAB 2: LYRICS

#### **LyricsTabView.swift**
**Ubicación:** `/Suonote/Views/LyricsTabView.swift`

**FUNCIONALIDAD:**
- Editor de texto para letras
- Organizado por secciones
- Auto-guardado

---

### 🎙️ TAB 3: RECORD

#### **RecordingsTabView.swift**
**Ubicación:** `/Suonote/Views/RecordingsTabView.swift`

**COMPONENTES:**
1. Lista de grabaciones
2. Controles de grabación
3. Filtros por tipo/sección
4. Vinculación a secciones

**VISTAS RELACIONADAS:**

**RecordingDetailView.swift**
- Detalles de una grabación
- Waveform visual
- Controles de reproducción

**ActiveRecordingView.swift**
- Vista durante la grabación activa
- Contador de tiempo
- Botones de control

---

## 🗂️ OTRAS VISTAS IMPORTANTES

### Pantalla Inicial

**ProjectsListView.swift** (línea ~1)
- Lista de todos los proyectos
- Filtros por estado
- Búsqueda
- Botón "New Project"

**CreateProjectView.swift**
- Modal para crear proyecto nuevo
- Campos: título, BPM, tonalidad, compás

---

## 📊 MODELOS DE DATOS

### **Project.swift** - Proyecto Principal
```swift
class Project {
    var title: String
    var bpm: Int
    var timeTop: Int      // Numerador del compás (4 en 4/4)
    var timeBottom: Int   // Denominador del compás (4 en 4/4)
    var keyRoot: String   // C, D, E, F, G, A, B
    var keyMode: KeyMode  // .major o .minor
    var status: ProjectStatus
    var arrangementItems: [ArrangementItem]
    var recordings: [Recording]
}
```

### **SectionTemplate.swift** - Sección Musical
```swift
class SectionTemplate {
    var name: String           // "Verse 1", "Chorus", etc.
    var type: SectionType      // .verse, .chorus, .bridge, etc.
    var bars: Int              // Número de compases
    var lyrics: String         // Letra
    var chordEvents: [ChordEvent]  // Acordes
}
```

### **ChordEvent.swift** - Acorde en el Tiempo
```swift
class ChordEvent {
    var barIndex: Int          // Compás (0, 1, 2...)
    var beatOffset: Double     // Beat dentro del compás (0.0, 0.5, 1.0...)
    var duration: Double       // Duración (0.5, 1.0, 2.0, 4.0 beats)
    var root: String           // C, D, E, etc.
    var quality: ChordQuality  // Major, Minor, etc.
    var extensions: [String]   // 7, 9, sus4, etc.
    var display: String        // "Cmaj7", "Dm", etc.
}
```

### **Recording.swift** - Grabación de Audio
```swift
class Recording {
    var fileName: String
    var duration: TimeInterval
    var recordingType: RecordingType  // .voice, .guitar, .bass, etc.
    var linkedSectionId: UUID?
    var tempo: Int
}
```

---

## ⚙️ SERVICIOS

### **AudioRecordingManager.swift**
**Ubicación:** `/Suonote/Services/AudioRecordingManager.swift`

**MÉTODOS PRINCIPALES:**
```swift
func startRecording()
func stopRecording() -> URL
func playRecording(url: URL)
func pausePlayback()
func deleteRecording(url: URL)
```

### **ChordSuggestionEngine.swift**
**Ubicación:** `/Suonote/Services/ChordSuggestionEngine.swift`

**MÉTODOS PRINCIPALES:**
```swift
static func suggestNextChord(after: ChordEvent?, inKey: String, mode: KeyMode)
static func diatonicChords(forKey: String, mode: KeyMode)
static func popularProgressions(forKey: String, mode: KeyMode)
```

---

## 🔍 BÚSQUEDA RÁPIDA

### Para encontrar...

**Las tabs principales:**
→ `ProjectDetailView.swift` línea 33-42

**El tab bar personalizado:**
→ `ProjectDetailView.swift` línea 112-159

**La cuadrícula de acordes:**
→ `ComposeTabView.swift` línea 485+ (`ChordGridView`)

**El modal de agregar acordes:**
→ `ComposeTabView.swift` línea 900+ (`ChordPaletteSheet`)

**El timeline de secciones:**
→ `ComposeTabView.swift` línea 252+ (`arrangementTimeline`)

**Los controles de grabación:**
→ `RecordingsTabView.swift` (todo el archivo)

**El editor de letras:**
→ `LyricsTabView.swift` (todo el archivo)

---

## 🎨 COMPONENTES REUTILIZABLES

### **ChordDiagramView.swift**
Diagrama visual de acordes para guitarra

### **ChordPaletteView.swift**
Selector de acordes (OBSOLETO - usar ChordPaletteSheet)

### **KeyPickerView.swift**
Modal para cambiar la tonalidad del proyecto

### **ExportView.swift**
Modal para exportar el proyecto

### **AudioEffectsSheet.swift**
Modal para aplicar efectos a grabaciones

---

## 📱 FLUJO DE NAVEGACIÓN

```
App Launch
    ↓
SuonoteApp.swift
    ↓
ProjectsListView (Lista de proyectos)
    ↓
ProjectDetailView (VISTA PRINCIPAL)
    ↓
┌──────────────┬──────────────┬──────────────┐
│   COMPOSE    │   LYRICS     │   RECORD     │
│              │              │              │
│ Secciones    │ Editor de    │ Grabaciones  │
│ Acordes      │ texto        │ Audio        │
│ Timeline     │              │ Playback     │
└──────────────┴──────────────┴──────────────┘
```

---

## 💡 TIPS DE DESARROLLO

### Para agregar una nueva tab:
1. Ir a `ProjectDetailView.swift`
2. Modificar `tabs` (línea ~161)
3. Agregar case en el switch (línea ~33)

### Para modificar el chord grid:
1. Ir a `ComposeTabView.swift`
2. Buscar `ChordGridView` (línea ~485)
3. Métodos importantes:
   - `slotsForBar()` - genera slots de acordes
   - `beatsUsedInBar()` - calcula beats usados
   - `widthForDuration()` - calcula ancho visual

### Para agregar sugerencias de acordes:
1. Ir a `ChordSuggestionEngine.swift`
2. Modificar métodos estáticos
3. Probar en `ChordPaletteSheet`

---

## 🐛 DEBUGGING

### Ver el estado de un proyecto:
```swift
print("Project: \(project.title)")
print("BPM: \(project.bpm)")
print("Sections: \(project.arrangementItems.count)")
```

### Ver acordes de una sección:
```swift
section.chordEvents.forEach { chord in
    print("Bar \(chord.barIndex), Beat \(chord.beatOffset): \(chord.display)")
}
```

### Ver grabaciones:
```swift
project.recordings.forEach { rec in
    print("\(rec.recordingType.rawValue): \(rec.duration)s")
}
```

---

## 📚 RECURSOS ADICIONALES

- **ARCHITECTURE.md** - Documentación completa de la arquitectura
- **Comentarios en código** - Cada archivo tiene comentarios // MARK:
- **Xcode** - Usa cmd+shift+O para buscar símbolos

