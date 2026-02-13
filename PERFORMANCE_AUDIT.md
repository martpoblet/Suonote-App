# Suonote — Performance Audit

> Revisión exhaustiva de CPU, RAM y eficiencia general de la app.  
> Fecha: Febrero 2025 | Rol: iOS Engineer — Performance Specialist

---

## Resumen Ejecutivo

Se identificaron **32 issues de performance** categorizados en 4 niveles de severidad:

| Severidad | Cantidad | Impacto |
|-----------|----------|---------|
| 🔴 CRITICAL | 5 | Leaks de memoria, CPU constante innecesaria |
| 🟠 HIGH | 10 | Consumo RAM elevado, redraws excesivos |
| 🟡 MEDIUM | 12 | Overhead acumulativo, optimizaciones importantes |
| 🟢 LOW | 5 | Mejoras menores |

---

## 🔴 CRITICAL — Arreglar Inmediatamente

### 1. Timer Retain Cycle en StudioPlaybackEngine
**Archivo:** `StudioPlaybackEngine.swift` ~L623  
**Problema:** `Timer.scheduledTimer(target: self, selector:...)` crea una referencia fuerte a `self`. Mientras el timer corre, el engine nunca se libera de memoria.  
**Fix:**
```swift
// ANTES (leak)
playheadTimer = Timer.scheduledTimer(target: self, selector: #selector(handlePlayheadTick), ...)

// DESPUÉS (safe)
playheadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
    self?.handlePlayheadTick()
}
```

### 2. Timer Tick Rate excesivo (50ms → 100ms)
**Archivo:** `StudioPlaybackEngine.swift` ~L623  
**Problema:** El timer de playhead corre cada 50ms (20fps). Para una barra de progreso, 100ms (10fps) es más que suficiente y reduce un 50% la carga del timer.  
**Fix:** Cambiar `timeInterval: 0.05` → `timeInterval: 0.1`

### 3. Timers sin cleanup en ActiveRecordingView
**Archivo:** `ActiveRecordingView.swift` ~L14-15  
**Problema:** `beatTimer` y `timeTimer` no se invalidan si la vista se cierra mientras graba. Los timers siguen corriendo en background consumiendo CPU.  
**Fix:** Agregar `.onDisappear { cleanup() }` y validar que `cleanup()` siempre invalida ambos timers.

### 4. ForEach con UUIDs regenerados cada render
**Archivo:** `StudioTabView.swift` ~L888  
**Problema:** `StudioTimelineSegment` tiene `id = UUID()` creado en init. Como se genera en una computed property, cada render crea nuevos UUIDs → SwiftUI destruye y recrea TODAS las celdas del timeline.  
**Fix:** Usar IDs determinísticos basados en posición:
```swift
struct StudioTimelineSegment: Identifiable {
    let id: String  // "section_0_bar_3" en vez de UUID()
    ...
}
```

### 5. `projectStudioSignature` recalculado en cada render
**Archivo:** `StudioTabView.swift` ~L652-686  
**Problema:** Computed property de 35 líneas con sorts, maps y joins que se ejecuta en CADA re-render del body para detectar cambios. Es O(n²) con los chords.  
**Fix:** Memoizar con `@State` y recalcular solo en `.onChange` de las propiedades específicas.

---

## 🟠 HIGH — Arreglar Pronto

### 6. Sequencer recreation sin cleanup
**Archivo:** `StudioPlaybackEngine.swift` ~L143  
**Problema:** `AVAudioSequencer(audioEngine: engine)` se re-crea en `rebuildSequenceIncremental` sin hacer nil al anterior ni llamar `sequencer.stop()`. El sequencer viejo puede quedar en memoria.  
**Fix:**
```swift
sequencer?.stop()
sequencer = nil
sequencer = AVAudioSequencer(audioEngine: engine)
```

### 7. AVAudioEngine recreation sin reset
**Archivo:** `StudioPlaybackEngine.swift` ~L96  
**Problema:** `engine = AVAudioEngine()` reasigna sin `engine.reset()` previo. Los nodos del engine anterior pueden no liberarse.  
**Fix:** Llamar `engine.stop(); engine.reset()` antes de reasignar.

### 8. Solo flag recalculado por cada track
**Archivo:** `StudioPlaybackEngine.swift` ~L837  
**Problema:** `trackMixState.values.contains { $0.isSolo }` se evalúa en cada iteración del loop de tracks al aplicar mix state.  
**Fix:** Cachear una vez antes del loop:
```swift
let hasSoloTrack = trackMixState.values.contains { $0.isSolo }
for (trackId, state) in trackMixState { ... }
```

### 9. `recordingsBySectionId()` en body de ComposeTabView
**Archivo:** `ComposeTabView.swift` ~L58  
**Problema:** Se llama dentro del body, recalculando el diccionario de recordings en CADA render de la vista.  
**Fix:** Mover a `@State` private var y actualizar en `.onAppear` / `.onChange`.

### 10. Sliders sin debounce disparan audio engine
**Archivo:** `StudioTabView.swift` ~L1285, 1889, 1911  
**Problema:** `.onChange(of: volume)` llama `updateTrackMix()` en CADA frame del slider (~60fps). El audio engine procesa 60 cambios por segundo innecesariamente.  
**Fix:** Agregar debounce de ~100ms:
```swift
.onChange(of: track.volume) { _, _ in
    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
        onMixChange()
    }
}
```

### 11. O(n²) en filtro de notas por chord ranges
**Archivo:** `StudioGenerator.swift` ~L285  
**Problema:** `notes.filter { newChordRanges.contains { ... } }` es O(notas × ranges). Con 500 notas y 50 ranges = 25,000 comparaciones.  
**Fix:** Ordenar ranges y usar binary search, o convertir a IntervalTree.

### 12. 15+ `Array(Set(...)).sorted()` en drum generation
**Archivo:** `StudioGenerator.swift` ~L1119-1198  
**Problema:** Crea Sets temporales, los convierte a Array y los ordena repetidamente. Cada uno es O(n log n).  
**Fix:** Usar `OrderedSet` o acumular en array y deduplicar una sola vez al final.

### 13. Sets recreados dentro de loops por bar
**Archivo:** `StudioGenerator.swift` ~L1431, 1460  
**Problema:** `Set(snareSteps)` y `Set(openHatSteps)` se crean en CADA iteración del bar loop.  
**Fix:** Crear los Sets una vez antes del loop.

### 14. SwiftData sin @Index en queries frecuentes
**Archivo:** `Recording.swift`, `SectionTemplate.swift`  
**Problema:** `linkedSectionId` se usa para filtrar recordings por sección pero no tiene `@Index`. SwiftData hace full scan.  
**Fix:**
```swift
@Attribute(.spotlight) var linkedSectionId: UUID?
// O en el schema:
@Index(\Recording.linkedSectionId)
```

### 15. Computed property setters en Project iteran todas las relaciones
**Archivo:** `Project.swift` ~L74-112  
**Problema:** Los setters de `sectionTemplates`, `arrangementItems`, `recordings`, `studioTracks` iteran TODOS los items para setear `projectStore`.  
**Fix:** Solo setear `projectStore` en items nuevos, no en todos.

---

## 🟡 MEDIUM — Mejoras Importantes

### 16. `diatonicQualityMap()` llamado 3 veces redundantemente
**Archivo:** `StudioGenerator.swift` ~L83, 158, 306  
**Fix:** Computar una vez y pasar como parámetro.

### 17. Triple sort en `dedupeAndClampNotes()`
**Archivo:** `StudioGenerator.swift` ~L974-1010  
**Fix:** Ordenar una sola vez al final.

### 18. `fitPitches()` crea arrays nuevos en while loop
**Archivo:** `StudioGenerator.swift` ~L1949-1958  
**Fix:** Modificar in-place sumando/restando 12 en vez de `.map { $0 + 12 }`.

### 19. `SoundFontManager` lookups no cacheados
**Archivo:** `StudioGenerator.swift` ~L1091, 1251  
**Fix:** Cachear `drumPitchMap` y `resolvedVariant` fuera del loop.

### 20. 14 @State variables en StudioTabView
**Archivo:** `StudioTabView.swift` ~L10-23  
**Problema:** Muchas variables `@State` causan redraws en cascada.  
**Fix:** Consolidar en un `StudioViewState` struct o ViewModel.

### 21. `uniqueSections` recalculado cada render en LyricsTabView
**Archivo:** `LyricsTabView.swift` ~L9-17  
**Fix:** Memoizar en `@State` y actualizar en `.onChange`.

### 22. `sortedItems` recalculado en body de ComposeTabView
**Archivo:** `ComposeTabView.swift` ~L60  
**Fix:** Mover a computed property cacheada o `@State`.

### 23. NotificationCenter observer sin removeObserver
**Archivo:** `AudioSessionManager.swift`  
**Fix:** Agregar `deinit { NotificationCenter.default.removeObserver(self) }`.

### 24. Logo image sin cache
**Archivo:** `AppLogoView.swift`  
**Problema:** `UIImage(contentsOfFile:)` se llama en cada render.  
**Fix:** Cachear en `@State` con `.onAppear`.

### 25. Notes re-sorted en cada rebuild
**Archivo:** `StudioPlaybackEngine.swift` ~L565  
**Problema:** `notes.sorted { $0.startBeat < $1.startBeat }` en `addNotes()` — ya deberían llegar ordenadas del generator.  
**Fix:** Garantizar orden en el generator y eliminar sort redundante.

### 26. `applyMixState()` y `updateTrackEffects()` duplican lógica
**Archivo:** `StudioPlaybackEngine.swift` ~L221-271  
**Fix:** Unificar en una sola función.

### 27. `.onChange(of: project.updatedAt)` trigger demasiado amplio
**Archivo:** `ProjectDetailView.swift` ~L130  
**Fix:** Usar watchers específicos por propiedad.

---

## 🟢 LOW — Mejoras Menores

### 28. EQ bands accedidas múltiples veces
**Archivo:** `StudioPlaybackEngine.swift` ~L401  
**Fix:** `let bands = eq.bands` una vez.

### 29. String `.contains()` secuencial en section names
**Archivo:** `StudioGenerator.swift` ~L33-51  
**Fix:** Usar switch/case o dictionary lookup.

### 30. ForEach con `id: \.self` en pickers
**Archivo:** `ActiveRecordingView.swift` ~L342, 349  
**Fix:** Usar Identifiable conformance.

### 31. Closures inline en view builders causan identity instability
**Archivo:** `StudioTabView.swift` ~L131-135  
**Fix:** Extraer a funciones estáticas o usar `.id()` explícito.

### 32. Reduce allocation innecesaria para conteo de bars
**Archivo:** `StudioPlaybackEngine.swift` ~L814  
**Fix:** Usar loop simple en vez de `.reduce(0, +)`.

---

## Plan de Implementación Recomendado

### Fase 1 — Quick Wins (máximo impacto, mínimo riesgo)
- [ ] Fix timer retain cycle (#1)
- [ ] Reducir tick rate a 100ms (#2)
- [ ] Fix timer cleanup en recording (#3)
- [ ] IDs determinísticos en timeline segments (#4)
- [ ] Cachear `projectStudioSignature` (#5)
- [ ] Cachear `hasSoloTrack` flag (#8)

### Fase 2 — Memory & Audio Engine
- [ ] Sequencer cleanup antes de recrear (#6)
- [ ] Engine reset antes de recrear (#7)
- [ ] Debounce en sliders de volume/pan (#10)
- [ ] Unificar applyMixState/updateTrackEffects (#26)

### Fase 3 — Generator Optimization
- [ ] Eliminar O(n²) en chord range filter (#11)
- [ ] Reducir Set/Sort redundantes en drums (#12, #13)
- [ ] Cachear diatonicQualityMap (#16)
- [ ] Cachear SoundFontManager lookups (#19)
- [ ] Single sort en dedupeAndClampNotes (#17)

### Fase 4 — SwiftUI View Optimization
- [ ] Mover recordingsBySectionId fuera del body (#9)
- [ ] Consolidar @State en StudioTabView (#20)
- [ ] Memoizar uniqueSections (#21)
- [ ] Agregar @Index en SwiftData models (#14)
- [ ] Optimizar Project relationship setters (#15)

---

## Impacto Estimado

| Métrica | Antes (estimado) | Después |
|---------|-------------------|---------|
| Timer CPU overhead | ~20fps constante | ~10fps (−50%) |
| Memory leaks en playback | Timer + engine acumulados | Zero leaks |
| Drum generation CPU | O(n² × bars) | O(n log n × bars) |
| SwiftUI redraws/sec en Studio | ~60 (slider drag) | ~10 (debounced) |
| Timeline re-render | Full destroy/recreate | Incremental diff |
| SwiftData queries | Full table scan | Indexed lookup |
