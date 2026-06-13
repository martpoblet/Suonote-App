# Suonote — Plan de rediseño: Liquid Glass (iOS 26) + nueva experiencia Studio

El target principal ya compila contra iOS 26.2 → todas las APIs de Liquid Glass están
disponibles sin checks de disponibilidad.

Principio rector (guía de Apple): **el glass es para la capa de navegación y controles
flotantes, no para el contenido**. El contenido (cards de secciones, lyrics, grids de
acordes) permanece sólido y legible; lo que flota sobre él (tab bar, transport, toolbars,
FABs, paletas) es glass. Abusar de glass en contenido degrada legibilidad y rendimiento.

---

## Fase 0 — Fundación (prerrequisitos)

1. **Colores semánticos + dark mode** (AUDIT U-03). Liquid Glass se adapta al fondo; con
   hex fijos light-only no luce. Migrar `DesignSystem.Colors` a asset catalog con variantes
   light/dark. Mantener identidad: teal `#00CCBE` como `accentColor`, paleta de secciones
   ajustada en luminancia para dark.
2. **Dynamic Type** (U-04): `Font.custom("Erode", size: 42, relativeTo: .largeTitle)` etc.
3. **Limpiar DesignSystem** (U-05): borrar `Shadows` muertas, fusionar `CardView`/`GlassCard`,
   renombrar `glassStyle()` → `cardStyle()` para liberar el término "glass" al efecto real.
4. **Partir monolitos** (U-01) a medida que se rediseña cada pantalla — no como big-bang.

---

## Fase 1 — Estructura de navegación nativa

### 1.1 ProjectDetailView: TabView nativo
Reemplazar la tab bar custom por:

```swift
TabView(selection: $selectedTab) {
    Tab("Compose", systemImage: "music.note.list", value: .compose) { ComposeTabView(project: project) }
    Tab("Studio",  systemImage: "slider.horizontal.3", value: .studio) { StudioTabView(project: project) }
    Tab("Lyrics",  systemImage: "text.alignleft", value: .lyrics) { LyricsTabView(project: project) }
    Tab("Record",  systemImage: "mic.fill", value: .record) { RecordingsTabView(project: project) }
}
.tabBarMinimizeBehavior(.onScrollDown)
.tabViewBottomAccessory { MiniTransportView() }
```

- La tab bar se vuelve glass flotante gratis, se minimiza al scrollear (más lienzo para
  componer) y elimina `DesignSystem.Layout.projectTabBar*` y todos los insets manuales.
- **`tabViewBottomAccessory` es la joya para Suonote:** un mini-transport persistente
  (play/pause, posición, nombre de sección actual) visible desde *cualquier* tab. Escuchás
  tu arreglo mientras escribís lyrics — hoy eso es imposible. Se expande a transport
  completo con `.tabViewBottomAccessoryPlacement` / tap → sheet.

### 1.2 Toolbars y navegación
- `NavigationStack` ya existe en todas las pantallas; al quitar fondos custom, los toolbars
  adoptan glass automático con scroll-edge effect.
- Agrupar acciones con `ToolbarSpacer(.fixed)` para que los items compartan una sola
  cápsula de glass donde tenga sentido (p. ej. undo/redo juntos, export aparte).
- `scrollEdgeEffectStyle(.soft, for: .top)` en listas largas (Projects, Recordings).

### 1.3 ProjectsListView
- Header del proyecto con `backgroundExtensionEffect()` si hay artwork/color de proyecto.
- Search nativo (`.searchable`) que en iOS 26 se ancla abajo en glass — reemplaza cualquier
  search bar custom.
- Swipe actions y context menus se mantienen; las cards de proyecto quedan sólidas
  (contenido), con material sutil solo en chips de estado.

---

## Fase 2 — Vocabulario Liquid Glass de Suonote

Componentes nuevos en `DesignSystem`:

| Componente | API | Uso |
|---|---|---|
| `FloatingGlassBar` | `.glassEffect(.regular, in: .capsule)` | transport de Studio, barra de acciones de Compose |
| `GlassFAB` | `GlassEffectContainer` + `.glassEffectID` | botón "+" que **morfea** en el menú Add Track / Add Section |
| CTAs | `.buttonStyle(.glassProminent)` (tint teal) | acciones primarias (Generate, Save) |
| Botones secundarios | `.buttonStyle(.glass)` | acciones de toolbar/sheet |
| Chips interactivos | `.glassEffect(.regular.tint(sectionColor).interactive())` | paleta de acordes, chips de sección |
| Sliders/knobs FX | controles nativos sobre fondo glass | AudioEffectsSheet, mixer |

Reglas:
- Glass solo sobre contenido que scrollea por debajo; nunca glass-sobre-glass.
- Agrupar elementos glass cercanos en un único `GlassEffectContainer` (mejor rendering y
  permite morphing entre estados con `glassEffectID`).
- `.glassEffect(.clear)` reservado a overlays sobre contenido rico (p. ej. waveforms).
- Accesibilidad (Reduce Transparency / Increase Contrast) la maneja el sistema — razón
  extra para no fabricar glass falso con opacidades.

---

## Fase 3 — Studio: la experiencia "wow"

Objetivo: que abrir Studio se sienta como entrar a una sala de producción, manteniendo la
simpleza (una decisión por vista).

### 3.1 Layout
```
┌─────────────────────────────────────┐
│  Timeline de secciones (colores)    │ ← contenido sólido, scrubbing con haptics
│  ── playhead animado ──             │ ← TimelineView(.animation), no Timer (AUDIT A-03)
├─────────────────────────────────────┤
│  Track cards (scroll vertical)      │ ← cards sólidas; meters por pista
│   [🎹 Piano   ▁▃▅▃  M S vol pan]    │
│   [🥁 Drums   ▂▆▂▆  M S vol pan]    │
│   [🎙 Take 3  ~waveform~ ]          │ ← waveform real para pistas de audio
├─────────────────────────────────────┤
│ ( ▶︎  ‖  ⟲ loop   1.2.3   ✚ )       │ ← FloatingGlassBar (transport)
└──────── tab bar glass minimizable ──┘
```

- **Transport flotante en glass** anclado abajo (encima de la tab bar minimizada), con
  contador bar.beat grande, loop toggle y el FAB "+" integrado.
- **FAB que morfea:** tap en "+" → la cápsula se expande (glassEffectID) en el picker de
  tipo de pista (Instrumento / Drums / Audio) sin presentar un sheet. Un tap menos,
  sensación de fluidez total.
- **Playhead:** `TimelineView(.animation)` interpolando la posición del sequencer →
  movimiento a frame-rate, sin saltos.
- **Meters por pista:** instalar un tap en cada mixer node y dibujar niveles RMS (ya existe
  `AudioLevelMeter` para recording — reutilizar). El Studio "respira" al reproducir.
- **Waveforms** para pistas de audio (render offline de `AVAudioFile` a picos, cacheado).

### 3.2 Flujo de generación (momento estrella)
- Pantalla de estilos rediseñada: cards por estilo con **preview sonoro de 2 compases**
  (el generador ya puede producirlos; reproducir con el banco nuevo).
- Al generar: las pistas aparecen en cascada con `spring` + las notas se "pintan" en la
  card (matched animation), haptic de éxito. Es teatro barato y memorable.
- Sliders de regeneración (intensity/complexity/naturalness) con preview en vivo sobre la
  sección en loop: activás loop de 1 sección, movés el slider, escuchás el cambio.

### 3.3 Editores
- Piano roll y drum editor pasan a fullScreenCover con toolbar glass propia, pinch-to-zoom
  horizontal, y velocidad editable arrastrando verticalmente sobre la nota (gesto único,
  menos modos).
- Drum editor: pads con `.glassEffect(.regular.tint(laneColor).interactive())` — feedback
  visual líquido al tocar + haptic por step.

### 3.4 Sonido percibido (cierra con SOUND_UPGRADE_RESEARCH.md)
- Master bus por estilo (EQ + glue + limiter) — presets `StudioStyle.masteringPreset`.
- Velocidades y humanización recalibradas para velocity layers reales.
- Count-in implementado de verdad (AUDIT A-04) usando el click del metrónomo.

---

## Fase 4 — Resto de pantallas (orden sugerido)

1. **Compose:** paleta de acordes como barra glass flotante; chips de acorde interactivos
   con tint del color de sección; sugerencias de próximos acordes en una fila glass sobre
   el grid.
2. **Record:** botón de grabación prominente (`.glassProminent` rojo), nivel de entrada
   alrededor del botón, count-in visual sincronizado.
3. **Lyrics:** modo focus ya existe — añadir fondo `backgroundExtensionEffect` con el color
   de sección y toolbar glass mínima.
4. **Onboarding/Splash:** rehacer con el nuevo lenguaje (glass + spring animations) — es la
   primera impresión del rediseño.

---

## Orden de ejecución propuesto

| Sprint | Entregable |
|---|---|
| 1 | Fase 0 completa (colores semánticos, dark mode, Dynamic Type, limpieza) |
| 2 | Fase 1 (TabView nativo + mini-transport accessory + toolbars) |
| 3 | Banco de sonido nuevo (Fase 1 del research) + fixes de audio del audit (A-02/03/04/05) |
| 4 | Studio rediseñado (Fase 3) |
| 5 | Compose/Record/Lyrics + onboarding (Fase 4) + packs héroe de sonido |

Cada sprint deja la app shippeable. El rediseño y el upgrade de sonido convergen en el
sprint 4: Studio nuevo **con** sonido nuevo es el momento de marketing del release.
