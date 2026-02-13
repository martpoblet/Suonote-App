# 🎵 Suonote — Análisis Integral y Roadmap de Mejoras

> Revisión exhaustiva desde la perspectiva de un iOS Senior Engineer y experto en teoría musical.
> Fecha: Febrero 2026

---

## Tabla de Contenidos

1. [Estado Actual — Resumen Ejecutivo](#1-estado-actual--resumen-ejecutivo)
2. [Bugs Críticos a Resolver Ya](#2-bugs-críticos-a-resolver-ya)
3. [Mejoras de Arquitectura e Ingeniería](#3-mejoras-de-arquitectura-e-ingeniería)
4. [Mejoras de UI/UX](#4-mejoras-de-uiux)
5. [Nuevas Funciones — Teoría Musical](#5-nuevas-funciones--teoría-musical)
6. [Nuevas Funciones — Audio y Producción](#6-nuevas-funciones--audio-y-producción)
7. [Nuevas Funciones — Productividad y Flujo](#7-nuevas-funciones--productividad-y-flujo)
8. [Escalabilidad y Futuro](#8-escalabilidad-y-futuro)
9. [Priorización Sugerida](#9-priorización-sugerida)

---

## 1. Estado Actual — Resumen Ejecutivo

### Lo que ya funciona bien ✅
- **Motor de sugerencias de acordes** muy sólido: dominantes secundarios, intercambio modal, sustituciones de tritono, acorde napolitano, tercera de Picardía, mediantes cromáticas
- **Sistema de arreglo** bien pensado: secciones reutilizables con orden flexible
- **Studio Generator** impresionante: 2,600+ líneas con voicings específicos por instrumento/variante, 85+ variantes MIDI GM, 13 presets de batería, humanización
- **Drum Editor** completo: secuenciador por pasos con 12 lanes, 3 capas de velocidad, copiar/pegar compases
- **Diseño visual** coherente con DesignSystem centralizado y tipografía con fuentes custom
- **CloudKit sync** integrado para sincronización entre dispositivos

### Puntuación por área

| Área | Estado | Nota |
|------|--------|------|
| Modelos de datos | Funcional con deuda técnica | ⭐⭐⭐ |
| Motor de audio | Funcional, no escalable | ⭐⭐⭐ |
| Teoría musical | Buena base, gaps importantes | ⭐⭐⭐ |
| UI/UX | Sólida, falta polish | ⭐⭐⭐ |
| Accesibilidad | Casi inexistente | ⭐ |
| Tests | No existen | ⭐ |
| Performance | Aceptable, riesgos en escala | ⭐⭐ |

---

## 2. Bugs Críticos a Resolver Ya

### 🔴 B-01: Tonalidades con bemoles no funcionan
El `ChordSuggestionEngine` usa una escala cromática solo con sostenidos (`["C", "C#", "D", "D#", ...]`). Cualquier proyecto en Bb, Eb, Ab, Db o Gb **silenciosamente devuelve arrays vacíos** en las sugerencias. Esto afecta a ~5 de las 12 tonalidades más comunes en música popular.

**Impacto:** Las sugerencias inteligentes (feature principal) están rotas para casi la mitad de las tonalidades.

### 🔴 B-02: Exportación MIDI exporta notas individuales, no acordes
`ExportView` solo escribe la **nota raíz** de cada acorde (`getMIDINote` retorna un solo número MIDI). Al importar en un DAW, el usuario obtiene una línea monofónica en vez de acordes reales.

**Impacto:** La exportación MIDI es prácticamente inútil para su propósito principal.

### 🔴 B-03: Niveles de audio en grabación son simulados
`ActiveRecordingView` muestra barras de nivel con `Float.random(in: 0.2...1.0)` en vez de datos reales del micrófono. El usuario no puede saber si está grabando audio real o si hay clipping.

### 🔴 B-04: Waveform en RecordingDetail es estática/aleatoria
`RecordingDetailView` genera la forma de onda con `CGFloat.random(in: 20...80)` — datos aleatorios que no representan el audio real.

### 🔴 B-05: `deleteRecording` no persiste en SwiftData
En `RecordingsTabView`, borrar una grabación solo la quita del array en memoria pero no llama `modelContext.delete()` — la grabación reaparece al reabrir la app.

### 🔴 B-06: Migración de datos elimina todo silenciosamente
En `SuonoteApp.swift`, si la migración de SwiftData falla, se **borra toda la base de datos** sin avisar al usuario. Esto puede causar pérdida total de proyectos.

### 🟡 B-07: `ChordEvent.display` se vuelve obsoleto
El campo `display` se calcula solo en `init()`. Si después se cambia `root`, `quality` o `extensions`, el display queda desactualizado mostrando el acorde anterior.

### 🟡 B-08: Cálculo de acordes "In Key" incorrecto en ChordPaletteView
El cálculo para tonalidades menores usa índices incorrectos, mostrando acordes que no son diatónicos.

### 🟡 B-09: Play/Pause en grabaciones usa `onTapGesture` en vez de `Button`
En `RecordingsTabView`, el botón de reproducción no es accesible para VoiceOver ni responde a accesibilidad del sistema.

---

## 3. Mejoras de Arquitectura e Ingeniería

### 🏗️ A-01: Descomponer vistas monolíticas
**ComposeTabView.swift (3,600 líneas)** y **StudioTabView.swift (2,753 líneas)** son god-views. Cada uno debería dividirse en ~10-15 archivos:

```
Views/Compose/
├── ComposeTabView.swift          (vista principal)
├── ArrangementTimeline.swift     (timeline horizontal)
├── SectionEditorView.swift       (editor de sección)
├── BarRow.swift                  (fila de compás)
├── ChordGridView.swift           (grilla de acordes)
├── ChordPaletteSheet.swift       (paleta de acordes)
├── SectionCreatorView.swift      (crear sección)
├── SmartSuggestionsModal.swift   (sugerencias)
└── SwipeActionRow.swift          (componente reutilizable)

Views/Studio/
├── StudioTabView.swift           (vista principal)
├── StudioTrackList.swift         (lista de pistas)
├── StudioTrackRow.swift          (fila de pista)
├── StudioTrackEditor.swift       (editor full-screen)
├── StudioNoteEditor.swift        (editor de notas)
├── StudioTimeline.swift          (timeline/scrubber)
├── StudioStylePicker.swift       (selector de estilo)
└── StudioEmptyState.swift        (estado vacío)
```

### 🏗️ A-02: Extraer lógica de negocio de `Project`
`Project` es un god-object con 34+ propiedades almacenadas. Los métodos `applyTimeSignatureChange()` y `applyKeyChange()` deberían vivir en un service:

```swift
// Antes: lógica en el modelo
project.applyKeyChange(from: oldKey, to: newKey)

// Después: service dedicado
ProjectMutationService.applyKeyChange(project, from: oldKey, to: newKey, context: modelContext)
```

### 🏗️ A-03: Consolidar `statusIcon`/`statusColor`
Estas funciones están duplicadas en **4 archivos** diferentes. Deben ser extensiones de `ProjectStatus`:

```swift
extension ProjectStatus {
    var icon: String { ... }
    var color: Color { ... }  // Actualmente retorna String, debería retornar Color
}
```

### 🏗️ A-04: Reducir de 3-4 AVAudioEngines a 1-2
La app crea engines independientes para: MetronomeClickPlayer, StudioPlaybackEngine, ChordPreviewPlayer y AudioEffectsProcessor. Cada uno consume un thread de CoreAudio. En dispositivos con recursos limitados esto causa glitches. Consolidar a:
- **1 engine principal** (playback + preview + metronomo)
- **1 engine de procesamiento** (efectos offline)

### 🏗️ A-05: Eliminar duplicación `studioLast*`
El `Project` tiene 9 campos `studioLast*` que duplican campos del proyecto. Reemplazar por:

```swift
struct StudioSnapshot: Codable {
    let chordIds: [UUID]
    let bpm: Int
    let timeTop: Int
    let timeBottom: Int
    let keyRoot: String
    let keyMode: String
    let signature: String
}
// Almacenar como Data en un solo campo
var studioSnapshotData: Data?
```

### 🏗️ A-06: Implementar rebuild incremental del sequencer
Actualmente `rebuildSequence()` destruye y recrea **todo** el grafo de audio para cualquier cambio. Implementar updates granulares:
- Cambio de notas → solo reescribir el `AVMusicTrack` afectado
- Cambio de mix (volumen/pan) → ya funciona sin rebuild ✅
- Agregar/quitar pista → solo attach/detach ese nodo

### 🏗️ A-07: Mover `StudioGenerator` fuera del main thread
Los 2,600 líneas de generación se ejecutan `@MainActor` sincrónicamente. Para proyectos complejos (200+ compases, 10 pistas) esto bloquea la UI. Mover a:

```swift
Task.detached(priority: .userInitiated) {
    let notes = StudioGenerator.generateNotes(...)
    await MainActor.run { applyNotes(notes) }
}
```

### 🏗️ A-08: Cachear computed properties costosas
Propiedades que se recalculan en cada render y deberían cachearse con `@State` o memoización:
- `filteredProjects` en ProjectsListView
- `allTags` en ProjectsListView
- `recordingsBySectionId` en ComposeTabView
- `projectStudioSignature` en StudioTabView
- `sectionsById` en RecordingsTabView
- `uniqueSections` en LyricsTabView y RecordingsTabView

### 🏗️ A-09: Agregar tests
No existe ningún test. Priorizar:
1. **Unit tests**: ChordSuggestionEngine, MusicTheoryUtils, StudioGenerator (lógica pura)
2. **Snapshot tests**: DesignSystem components
3. **Integration tests**: SwiftData model relationships

### 🏗️ A-10: Validación de datos en modelos
- `bpm`: clamped 20–300
- `keyRoot`: validar contra escala cromática (incluyendo bemoles)
- `timeTop`/`timeBottom`: validar combinaciones válidas
- `ChordEvent.beatOffset`: validar rango 0..<timeTop
- `Recording.fileName`: verificar existencia del archivo

---

## 4. Mejoras de UI/UX

### 🎨 U-01: Accesibilidad (Crítico para App Store)
La app tiene gaps severos de accesibilidad que podrían causar rechazo en revisión:

- **VoiceOver**: Ningún chord pill, swipe action, o note block tiene `accessibilityLabel`
- **Dynamic Type**: Toda la tipografía usa tamaños fijos (no `.relativeTo:`)
- **Color Blind**: Los indicadores de sección solo usan color sin texto alternativo
- **Motor**: `HorizontalPanGesture` no tiene alternativa accesible; botones play usan `onTapGesture`

### 🎨 U-02: Dark Mode
La app fuerza light mode (`overrideUserInterfaceStyle = .light`). Implementar dark mode:
- El `DesignSystem` ya tiene la estructura — solo faltan los valores alternativos
- Las sombras están definidas pero en `.clear` — activarlas para dark mode daría profundidad

### 🎨 U-03: Undo/Redo
No existe undo/redo en ninguna parte de la app. Implementar con `UndoManager`:
- Edición de acordes (cambio, borrado, movimiento)
- Edición de arreglo (reordenar, eliminar secciones)
- Edición de notas en Studio
- Edición de drum patterns

### 🎨 U-04: Onboarding
No existe flujo de primera vez. Implementar:
- Tour guiado de las 3 tabs
- Proyecto de ejemplo pre-cargado
- Tips contextuales en features nuevas (sugerencias inteligentes, studio)

### 🎨 U-05: Tap Tempo
Para setear BPM de forma natural. Detectar el intervalo entre taps y calcular BPM. Común en todas las apps de música y notablemente ausente.

### 🎨 U-06: Waveform real
Reemplazar las waveforms aleatorias con extracción real de datos de audio:

```swift
func extractWaveform(from url: URL, samples: Int) -> [Float] {
    let file = try AVAudioFile(forReading: url)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, 
                                   frameCapacity: AVAudioFrameCount(file.length))
    try file.read(into: buffer)
    // Downsample to `samples` points
    ...
}
```

### 🎨 U-07: Metering real durante grabación
Reemplazar niveles simulados con datos del AVAudioRecorder:

```swift
recorder.isMeteringEnabled = true
recorder.updateMeters()
let level = recorder.averagePower(forChannel: 0)
```

### 🎨 U-08: Preview de audio al seleccionar acordes
Ni `ChordPaletteView` ni `EnhancedChordPaletteSheet` reproducen el acorde al seleccionarlo. El `ChordPreviewPlayer` ya existe pero no está conectado a las paletas.

### 🎨 U-09: Feedback visual del beat
Durante playback, agregar:
- Indicador visual de beat actual (LED/dot pulsante)
- Highlight del acorde que está sonando
- Scroll automático del timeline al compás actual

### 🎨 U-10: iPad optimization
Sin layout adaptativo para iPad. Oportunidades:
- Split view: timeline + editor side-by-side
- Teclado piano más grande
- Drum editor con más columnas visibles

---

## 5. Nuevas Funciones — Teoría Musical

### 🎵 M-01: Modos y escalas extendidas
`KeyMode` solo tiene Major/Minor. Agregar al menos:

| Categoría | Escalas |
|-----------|---------|
| **Modos eclesiásticos** | Dórico, Frigio, Lidio, Mixolidio, Eólico, Locrio |
| **Minor variants** | Armónica menor, Melódica menor |
| **Pentatónicas** | Mayor, Menor, Blues |
| **Especiales** | Whole-tone, Diminished (octatónica), Bebop |

`MusicTheoryUtils.swift` ya define 13 `ScaleType` pero `KeyMode` en el modelo solo usa 2. Conectarlos.

**Impacto:** Permite componer en Dorian (jazz, funk), Mixolydian (blues, rock), Phrygian (flamenco, metal), etc.

### 🎵 M-02: Cambios de tonalidad por sección
Actualmente la tonalidad es global al proyecto. Muchas canciones modulan entre secciones (ej: subir medio tono en el último coro). Agregar `keyRoot` y `keyMode` opcionales a `SectionTemplate`:

```swift
// Si nil, hereda del Project
var sectionKeyRoot: String?
var sectionKeyMode: KeyMode?
```

**Impacto:** Habilita modulaciones, que son una de las herramientas compositivas más poderosas.

### 🎵 M-03: Cambios de tempo por sección
Mismo concepto: BPM opcional por sección para bridges más lentos, half-time feels, etc.

```swift
var sectionBpm: Int?  // Si nil, hereda del Project
```

### 🎵 M-04: Análisis funcional con números romanos
El `ChordSuggestionEngine` ya calcula roman numerals internamente. Exponerlos en la UI:
- Mostrar "I", "IV", "V7", "vi" debajo de cada acorde en la grilla
- Marcar acordes no-diatónicos con `*` o color diferente
- Detectar progresiones conocidas automáticamente ("¡Esto es un I-V-vi-IV!")

### 🎵 M-05: Detección automática de tonalidad
Dado un set de acordes, inferir la tonalidad más probable:

```swift
func detectKey(from chords: [ChordEvent]) -> (root: String, mode: KeyMode, confidence: Double)
```

Útil cuando el usuario empieza escribiendo acordes sin definir la key.

### 🎵 M-06: Cifrado Nashville / Números
Sistema numérico alternativo al cifrado tradicional. Muy usado en Nashville para leer charts rápidamente en cualquier tonalidad:
- `1 5 6m 4` en vez de `C G Am F`
- Permite transponer instantáneamente

### 🎵 M-07: Calidades de acordes extendidas
Faltan acordes muy usados:

| Tipo | Acordes faltantes |
|------|-------------------|
| **Sextas** | 6, m6 |
| **Onceavas** | 11, m11, maj11 |
| **Treceavas** | 13, m13, maj13 |
| **Alterados** | 7#9, 7b9, 7#11, 7alt |
| **Add** | add9, add11 |
| **Combinados** | 7sus4 |
| **Power** | 5 (power chord) |

### 🎵 M-08: Círculo de quintas interactivo
Visualización del ciclo de quintas como herramienta de composición:
- Tocar una nota para seleccionarla como raíz
- Resaltar acordes diatónicos de la tonalidad actual
- Mostrar relaciones (relativo mayor/menor, dominante, subdominante)
- Arrastrar para transponer toda la progresión

### 🎵 M-09: Sugerencias basadas en género
El `ChordSuggestionEngine` no considera el género. Las expectativas armónicas son muy diferentes:
- **Pop**: I-V-vi-IV, pocos acordes, mucha repetición
- **Jazz**: ii-V-I, extensiones (7, 9, 13), sustituciones cromáticas
- **Blues**: I7-IV7-V7, blue notes
- **Bossa Nova**: Movimiento cromático, acordes m7-dom7
- **Rock**: Power chords, mixolidio, riffs en lugar de progresiones
- **Classical**: Movimiento de voces, cadencias auténticas/plagales

### 🎵 M-10: Voice leading inteligente
Actualmente los voicings del `StudioGenerator` son buenos pero estáticos por instrumento. Implementar voice leading real:
- Minimizar movimiento entre acordes consecutivos
- Mantener notas comunes en la misma voz
- Evitar saltos paralelos de quintas/octavas
- Considerar rango del instrumento

---

## 6. Nuevas Funciones — Audio y Producción

### 🔊 P-01: Exportación de audio (Mixdown/Bounce)
No existe forma de exportar el audio del Studio. Implementar render offline:

```swift
func bounce(project: Project) -> URL {
    let engine = AVAudioEngine()
    // Setup identical node graph
    // Enable offline rendering
    engine.enableManualRenderingMode(.offline, ...)
    // Render all beats to buffer
    // Write to WAV/M4A file
}
```

**Impacto:** Sin esto, el Studio es una herramienta de previsualización sin output utilizable.

### 🔊 P-02: Efectos por pista en Studio
`AudioEffectsProcessor` existe con reverb/delay/EQ/compression pero **no está conectado** al `StudioPlaybackEngine`. Cada pista del Studio debería tener su propia cadena de efectos.

### 🔊 P-03: Exportación MIDI completa
Arreglar la exportación para escribir **todos los voicings** (no solo la raíz) y agregar:
- Pista de batería
- Pista de bajo
- Velocity correcta por nota
- Tempo track con metadatos

### 🔊 P-04: Importación MIDI
Importar archivos .mid para:
- Crear proyecto desde MIDI existente
- Importar drum patterns
- Importar progresiones de acordes

### 🔊 P-05: Grabación con overdub
Actualmente la grabación no reproduce pistas existentes. Implementar:
- Playback del Studio mientras se graba
- Mezcla de monitoreo (audio existente + input del mic)
- Compensación de latencia

### 🔊 P-06: Loop/Cycle playback
No existe modo loop. Esencial para:
- Practicar sobre una sección
- Grabar múltiples takes sobre un loop
- Componer iterativamente

### 🔊 P-07: Grabación estéreo
Solo se graba mono (1 canal). Para instrumentos estéreo (piano, guitarra stereo mic), agregar opción de grabación estéreo.

### 🔊 P-08: Punch-in / Punch-out
Grabar solo un rango específico de compases, reemplazando una sección de una toma existente. Workflow estándar de estudio.

### 🔊 P-09: Metering y clipping
Agregar medidores de nivel real:
- VU/Peak meter durante grabación
- Indicador de clipping (rojo cuando se satura)
- Level meters por pista en Studio

### 🔊 P-10: Exportación PDF de chord charts
Generar lead sheets profesionales en PDF:
- Nombre de la canción, tonalidad, tempo
- Compases con acordes
- Letras alineadas con secciones
- Formato estándar de Nashville/fake book

---

## 7. Nuevas Funciones — Productividad y Flujo

### 📱 F-01: Búsqueda global
El search actual solo busca por título de proyecto. Expandir a:
- Buscar por progresión de acordes ("proyectos con Am - F - C - G")
- Buscar dentro de letras
- Buscar por tag
- Buscar por tonalidad o BPM

### 📱 F-02: Templates de proyecto
Crear proyectos desde plantillas predefinidas:
- "Pop Song" (Intro-Verse-Chorus-Verse-Chorus-Bridge-Chorus-Outro, 120bpm, 4/4)
- "Blues 12-Bar" (12 compases I-IV-V, 90bpm, 4/4)
- "Jazz Standard" (AABA, 140bpm, 4/4)
- Templates del usuario (guardar un proyecto como template)

### 📱 F-03: Duplicar secciones con variación
Al duplicar una sección, ofrecer:
- Copia exacta
- Transponer +/- N semitonos
- Variación rítmica (el mismo acorde con diferente patrón)
- "Similar but different" (sugerir sustituciones diatónicas)

### 📱 F-04: Comparar versiones
Historial de cambios para poder comparar el estado actual con versiones anteriores. Útil para A/B testing de arreglos.

### 📱 F-05: Colaboración
Compartir un proyecto con otro usuario para:
- Co-escritura de letras en tiempo real
- Enviar progresión para feedback
- Compartir el proyecto completo (export/import)

### 📱 F-06: Widget de iOS
- Quick capture: grabar una idea de voz desde el home screen
- Mostrar el último proyecto editado
- Acceso rápido a un metrónomo

### 📱 F-07: Shortcuts / Siri
- "Hey Siri, graba una idea en Suonote"
- Shortcuts para crear proyecto, empezar grabación

### 📱 F-09: Integración con AirDrop/Files
- Importar/exportar proyectos completos
- Arrastrar archivos de audio desde Files app
- AirDrop chord charts a otros músicos

### 📱 F-10: Estadísticas y insights
- "Tus tonalidades más usadas"
- "Progresiones que más repites"
- "Tempo promedio de tus canciones"
- Heatmap de actividad compositiva

---

## 8. Escalabilidad y Futuro

### 🚀 S-01: Arquitectura para múltiples SoundFonts
Un solo `Arachno_Lite.sf2` sirve todo. Para calidad profesional:
- Lazy loading de SoundFonts por instrumento
- Descarga bajo demanda de packs de sonido
- Gestión de almacenamiento (SF2 pueden pesar GB)

### 🚀 S-02: Plugin de Audio Unit (AUv3)
Permitir que usuarios usen sus propios instrumentos virtuales (AUv3) dentro del Studio. Esto abriría la puerta a sintetizadores, samplers profesionales, etc.

### 🚀 S-03: Modelo de AI para sugerencias
El `ChordSuggestionEngine` es rule-based. Entrenar un modelo de ML con:
- Progresiones de miles de canciones reales
- Sugerencias que mejoran con el uso del usuario
- "Completar esta progresión" tipo autocomplete

### 🚀 S-04: macOS Catalyst / Mac nativo
- El código es 100% SwiftUI → relativamente portable
- `Color.toHex()` usa `UIColor` → necesita `#if canImport` guards
- Keyboard shortcuts en Mac para productividad avanzada

### 🚀 S-05: Monetización features
- **Free tier**: Proyectos limitados, exportación básica
- **Pro**: Proyectos ilimitados, exportación MIDI/PDF, todos los estilos de Studio
- **Sound Packs**: SoundFonts premium descargables
- **Colaboración**: Feature de equipo

---

## 9. Priorización Sugerida

### Fase 1 — Fix & Polish (1-2 sprints)
*Corregir lo roto y pulir lo existente*

| # | Item | Tipo |
|---|------|------|
| 1 | B-01: Fix tonalidades con bemoles | Bug crítico |
| 2 | B-05: Fix deleteRecording SwiftData | Bug crítico |
| 3 | B-02: Fix exportación MIDI (acordes completos) | Bug crítico |
| 4 | B-07: Fix ChordEvent.display stale | Bug |
| 5 | U-06/U-07: Waveform y metering real | UX crítica |
| 6 | U-08: Preview de audio en paleta de acordes | UX |
| 7 | A-03: Consolidar statusIcon/statusColor | Refactor |
| 8 | A-10: Validación de datos en modelos | Calidad |

### Fase 2 — Core Features (2-3 sprints)
*Las funciones que más valor agregan*

| # | Item | Tipo |
|---|------|------|
| 1 | P-01: Exportación de audio (bounce) | Feature clave |
| 2 | M-01: Modos y escalas extendidas | Teoría musical |
| 3 | M-04: Números romanos en la grilla | Teoría musical |
| 4 | U-03: Undo/Redo | UX esencial |
| 5 | P-06: Loop playback | Audio |
| 6 | M-02: Cambios de tonalidad por sección | Teoría musical |
| 7 | U-05: Tap tempo | UX |
| 8 | P-10: Exportación PDF de chord charts | Productividad |

### Fase 3 — Architecture & Scale (2-3 sprints)
*Preparar la app para crecer*

| # | Item | Tipo |
|---|------|------|
| 1 | A-01: Descomponer vistas monolíticas | Refactor |
| 2 | A-07: StudioGenerator fuera del main thread | Performance |
| 3 | A-04: Consolidar AVAudioEngines | Performance |
| 4 | A-06: Rebuild incremental del sequencer | Performance |
| 5 | A-09: Tests unitarios para lógica musical | Calidad |
| 6 | U-01: Accesibilidad básica | Compliance |

### Fase 4 — Pro Features (3-4 sprints)
*Diferenciadores y monetización*

| # | Item | Tipo |
|---|------|------|
| 1 | M-08: Círculo de quintas interactivo | Feature estrella |
| 2 | M-09: Sugerencias por género | Diferenciador |
| 3 | P-05: Grabación con overdub | Pro audio |
| 4 | P-02: Efectos por pista en Studio | Pro audio |
| 5 | F-02: Templates de proyecto | Productividad |
| 6 | M-05: Detección automática de tonalidad | IA musical |
| 7 | P-04: Importación MIDI | Interoperabilidad |
| 8 | U-02: Dark Mode | UX |

### Fase 5 — Ecosystem (futuro)
*Expandir la plataforma*

| # | Item | Tipo |
|---|------|------|
| 1 | F-05: Colaboración | Social |
| 2 | S-02: Soporte AUv3 | Pro |
| 3 | S-03: AI para sugerencias | IA |
| 4 | S-04: macOS | Plataforma |
| 5 | F-06/F-07: Widget, Siri | Ecosystem |

---

> **Nota final**: Suonote tiene una base técnica sólida, especialmente el motor de sugerencias armónicas y el generador de Studio. Las prioridades claras son: (1) arreglar los bugs que rompen funcionalidad core, (2) agregar las features de audio que hacen al Studio utilizable como output (bounce, loop), y (3) expandir la teoría musical para cubrir más estilos compositivos. Con estas mejoras, la app puede posicionarse como la herramienta de songwriting más completa en iOS.
