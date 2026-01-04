# 🎵 Suonote - Arquitectura de la Aplicación

## 📋 Índice
1. [Estructura General](#estructura-general)
2. [Flujo de Navegación](#flujo-de-navegación)
3. [Modelos de Datos](#modelos-de-datos)
4. [Vistas Principales](#vistas-principales)
5. [Servicios](#servicios)

---

## 🏗️ Estructura General

```
Suonote/
├── SuonoteApp.swift          # 🚀 Punto de entrada de la app
├── Models/                    # 📊 Modelos de datos (SwiftData)
│   ├── Project.swift         # Proyecto musical principal
│   ├── SectionTemplate.swift # Secciones (Verse, Chorus, etc)
│   ├── ChordEvent.swift      # Acordes en el tiempo
│   └── Recording.swift       # Grabaciones de audio
├── Views/                     # 🎨 Interfaces de usuario
│   ├── ProjectsListView.swift       # Lista de proyectos
│   ├── ProjectDetailView.swift      # ⭐ VISTA PRINCIPAL CON TABS
│   ├── ComposeTabView.swift         # Tab 1: Composición
│   ├── LyricsTabView.swift          # Tab 2: Letras
│   ├── RecordingsTabView.swift      # Tab 3: Grabaciones
│   └── ...                          # Otras vistas auxiliares
├── Services/                  # ⚙️ Lógica de negocio
│   ├── AudioRecordingManager.swift  # Manejo de grabaciones
│   └── ChordSuggestionEngine.swift  # Sugerencias de acordes
└── Utils/                     # 🔧 Utilidades
    └── ...
```

---

## 🔄 Flujo de Navegación

### 1️⃣ Inicio de la App
```
SuonoteApp.swift
    ↓
ProjectsListView (Lista de proyectos)
    ↓
ProjectDetailView (Vista principal del proyecto)
    ↓
┌─────────────┬─────────────┬─────────────┐
│  COMPOSE    │   LYRICS    │   RECORD    │  ← Tabs principales
└─────────────┴─────────────┴─────────────┘
```

### 2️⃣ Vista Principal (ProjectDetailView)

**UBICACIÓN:** `Views/ProjectDetailView.swift`

Esta es la vista MÁS IMPORTANTE que contiene las 3 tabs:

```swift
// Línea 33-42: Switch que muestra cada tab
switch selectedTab {
    case 0: ComposeTabView(project: project)    // 🎼 Compose
    case 1: LyricsTabView(project: project)     // 📝 Lyrics  
    case 2: RecordingsTabView(project: project) // 🎙️ Record
}
```

**Elementos de la vista:**
- **Header**: Título del proyecto + estado (Idea, In Progress, etc.)
- **Tab Bar**: 3 pestañas principales (Compose, Lyrics, Record)
- **Contenido**: Vista correspondiente a la tab seleccionada

---

## 📊 Modelos de Datos

### Project (Proyecto Principal)
```swift
@Model
class Project {
    var title: String              // Título del proyecto
    var bpm: Int                   // Tempo (beats per minute)
    var timeTop: Int               // Compás (numerador) ej: 4 en 4/4
    var timeBottom: Int            // Compás (denominador) ej: 4 en 4/4
    var keyRoot: String            // Tónica (C, D, E, etc.)
    var keyMode: KeyMode           // Modo (Major/Minor)
    var status: ProjectStatus      // Estado del proyecto
    var tags: [String]             // Etiquetas
    var arrangementItems: [ArrangementItem]  // Orden de secciones
    var recordings: [Recording]    // Grabaciones de audio
}
```

### SectionTemplate (Secciones musicales)
```swift
@Model
class SectionTemplate {
    var name: String               // Ej: "Verse 1", "Chorus"
    var type: SectionType          // verse, chorus, bridge, etc.
    var bars: Int                  // Número de compases
    var lyrics: String             // Letra de la sección
    var chordEvents: [ChordEvent]  // Acordes en la sección
}
```

### ChordEvent (Acordes en el tiempo)
```swift
@Model
class ChordEvent {
    var barIndex: Int              // En qué compás está (0-based)
    var beatOffset: Double         // En qué beat del compás (0.0 - 3.5)
    var duration: Double           // Duración en beats (0.5, 1.0, 2.0, 4.0)
    var root: String               // Raíz del acorde (C, D, E, etc.)
    var quality: ChordQuality      // Calidad (Major, Minor, etc.)
    var extensions: [String]       // Extensiones (7, 9, sus4, etc.)
    var display: String            // Nombre completo (ej: "Cmaj7")
}
```

### Recording (Grabaciones de audio)
```swift
@Model
class Recording {
    var fileName: String           // Nombre del archivo de audio
    var duration: TimeInterval     // Duración en segundos
    var recordingType: RecordingType  // voice, guitar, bass, etc.
    var linkedSectionId: UUID?     // Enlace opcional a una sección
    var tempo: Int                 // BPM al grabar
}
```

---

## 🎨 Vistas Principales

### 📱 1. ProjectsListView.swift
**Propósito:** Lista inicial de todos los proyectos

**Funcionalidad:**
- Muestra tarjetas de proyectos
- Filtrado por estado (Idea, In Progress, etc.)
- Búsqueda por texto
- Botón para crear nuevo proyecto
- Navegación a ProjectDetailView al tocar un proyecto

---

### ⭐ 2. ProjectDetailView.swift
**Propósito:** Vista principal que contiene las 3 tabs

**Estructura:**
```swift
VStack {
    customTabBar        // Tab bar personalizado
    
    // Contenido de la tab seleccionada
    switch selectedTab {
        case 0: ComposeTabView
        case 1: LyricsTabView  
        case 2: RecordingsTabView
    }
}
```

**Tabs definidas (línea 161-167):**
```swift
("Compose", "music.note.list")      // Tab 0
("Lyrics", "text.quote")            // Tab 1
("Record", "waveform.circle.fill")  // Tab 2
```

**Toolbar:**
- Título del proyecto (centro)
- Badge de estado (Idea, In Progress, etc.)
- Botón de edición (derecha) → Abre EditProjectSheet

---

### 🎼 3. ComposeTabView.swift
**Propósito:** Tab de composición - gestión de secciones y acordes

**Componentes principales:**

#### a) **Top Controls Bar**
- Botón de exportar
- Botón de key picker (tonalidad)
- Indicador de BPM y compás

#### b) **Arrangement Timeline**
- Lista de secciones en orden
- Tarjetas arrastrables para reordenar
- Botón "Add Section" para crear nuevas secciones

#### c) **Section Editor** (cuando se selecciona una sección)
- **Chord Grid**: Cuadrícula para agregar acordes
  - Organizado por compases (bars)
  - Cada compás dividido en beats
  - Botones "+" para agregar acordes
  
- **Recording Button**: Grabar audio para la sección

**Vistas auxiliares importantes:**

**ChordPaletteSheet:** Modal para agregar/editar acordes
```swift
struct ChordPaletteSheet: View {
    // Secciones:
    - Preview del acorde
    - 💡 Suggestions (Smart, In Key, Popular)
    - Root Note selector (C, D, E, etc.)
    - Quality selector (Major, Minor, etc.)
    - Extensions (7, 9, sus4, etc.)
    - Duration (0.5, 1.0, 2.0, 4.0 beats)
    - Botón "Add Chord"
}
```

**SectionCreatorView:** Modal para crear sección nueva
```swift
- Nombre de la sección
- Número de compases
- Plantillas predefinidas (Verse, Chorus, Bridge, etc.)
```

**ChordGridView:** Componente para mostrar acordes en compases
```swift
- Muestra todos los compases de una sección
- Cada compás muestra acordes existentes
- Espacios vacíos para agregar más acordes
- Indicador de beats usados/disponibles
```

---

### 📝 4. LyricsTabView.swift
**Propósito:** Tab de letras - escribir y editar letras por sección

**Funcionalidad:**
- Editor de texto para cada sección
- Sincronización automática con las secciones
- Vista previa de la letra completa
- Contador de sílabas/palabras (si está implementado)

---

### 🎙️ 5. RecordingsTabView.swift
**Propósito:** Tab de grabaciones - gestión de audio

**Componentes:**

#### a) **Lista de Grabaciones**
- Muestra todas las grabaciones del proyecto
- Agrupadas por tipo (Voice, Guitar, Bass, etc.)
- Indicador de duración
- Vínculo a sección (si está enlazada)

#### b) **Controles de Grabación**
- Botón de grabar nuevo
- Selección de tipo de instrumento
- Contador de tiempo en vivo
- Controles de reproducción

#### c) **Filtros**
- Por tipo de instrumento
- Por sección vinculada
- Por fecha

**RecordingDetailView:** Vista detallada de una grabación
```swift
- Waveform visual
- Controles de reproducción (play/pause)
- Edición de metadatos
- Opciones de exportar/compartir
- Efectos de audio (si están implementados)
```

---

## ⚙️ Servicios

### AudioRecordingManager.swift
**Propósito:** Gestión de grabaciones de audio

**Funcionalidades:**
```swift
@Observable class AudioRecordingManager {
    // Estados
    var isRecording: Bool
    var isPlaying: Bool
    var currentTime: TimeInterval
    
    // Métodos principales
    func startRecording()
    func stopRecording() -> URL
    func playRecording(url: URL)
    func pausePlayback()
    func deleteRecording(url: URL)
}
```

### ChordSuggestionEngine.swift
**Propósito:** Generar sugerencias inteligentes de acordes

**Funcionalidades:**
```swift
struct ChordSuggestionEngine {
    // Sugerencias basadas en contexto
    static func suggestNextChord(
        after lastChord: ChordEvent?,
        inKey: String,
        mode: KeyMode
    ) -> [ChordSuggestion]
    
    // Acordes diatónicos de la tonalidad
    static func diatonicChords(
        forKey: String,
        mode: KeyMode
    ) -> [ChordSuggestion]
    
    // Progresiones populares
    static func popularProgressions(
        forKey: String,
        mode: KeyMode
    ) -> [(name: String, progression: [ChordSuggestion])]
}
```

---

## 🎯 Flujo de Uso Típico

### Escenario 1: Crear una nueva canción
```
1. ProjectsListView → Tap "New Project"
2. CreateProjectView → Introducir datos básicos
3. ProjectDetailView → Se abre automáticamente
4. Tab "Compose" → Tap "Add Section"
5. SectionCreatorView → Crear "Verse 1"
6. ChordGridView → Tap "+" en beat 1
7. ChordPaletteSheet → Seleccionar C Major
8. ChordGridView → Acorde agregado ✅
```

### Escenario 2: Grabar una pista
```
1. ProjectDetailView → Tab "Record"
2. RecordingsTabView → Tap botón de grabar
3. Seleccionar tipo (Voice/Guitar/etc)
4. Grabar audio
5. Vincular a sección (opcional)
6. Reproducir y editar
```

### Escenario 3: Escribir letra
```
1. ProjectDetailView → Tab "Lyrics"
2. LyricsTabView → Seleccionar sección
3. Escribir letra en el editor
4. Auto-guardado ✅
```

---

## 🔑 Conceptos Clave

### ArrangementItem
Representa el orden de las secciones en la canción:
```swift
struct ArrangementItem {
    var id: UUID
    var sectionId: UUID    // Referencia a SectionTemplate
    var position: Int      // Orden en el arreglo
}
```

**Ejemplo de arreglo:**
```
[Intro, Verse 1, Chorus, Verse 2, Chorus, Bridge, Chorus, Outro]
```

### Beats y Compases
- **Bar (Compás):** Unidad rítmica principal (ej: un compás de 4/4)
- **Beat:** Subdivisión del compás (ej: en 4/4 hay 4 beats)
- **beatOffset:** Posición decimal dentro del compás
  - 0.0 = primer beat
  - 0.5 = medio beat
  - 1.0 = segundo beat
  - 3.5 = final del cuarto beat

### Duraciones de Acordes
```
0.5 beats = medio compás (en 4/4)
1.0 beats = un beat completo
2.0 beats = dos beats
4.0 beats = compás completo
```

---

## 📝 Notas de Optimización (Últimas mejoras)

### Performance Improvements:
1. ✅ **LazyVStack** en lugar de VStack para renderizado eficiente
2. ✅ **Caching** de cálculos costosos (sugerencias de acordes)
3. ✅ **IDs estables** para vistas en ForEach
4. ✅ **Computed properties** cacheadas para evitar recálculos

### Estructura de Datos:
- **SwiftData** para persistencia automática
- **@Observable** para gestión de estado moderna
- **Bindable** para vinculación de datos bidireccional

---

## 🚀 Próximos Pasos Sugeridos

1. Agregar comentarios inline en código
2. Crear tests unitarios
3. Documentar APIs de servicios
4. Agregar ejemplos de uso
5. Mejorar accesibilidad (VoiceOver)

