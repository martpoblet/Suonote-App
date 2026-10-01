# Suonote — Design Language v2 ("ink on paper, with a teal pulse")

Source of truth: `Suonote/Utils/DesignSystem.swift`, `Suonote/Utils/FontExtensions.swift`,
`Suonote/Utils/GlassComponents.swift`, `Suonote/Views/StudioModalStyle.swift`.

## Idea
Suonote is a songwriter's notebook. Screens should feel like a beautifully set page in a
music journal — warm paper, near-black ink, hairline rules, generous margins — with the
brand teal (#00CCBE, the logo's waves) marking only what is *alive*: what's playing, what's
selected, the primary action. Calm, confident, editorial. Not a dashboard, not a toy.

## Typography — two voices
| Voice | Font | Used for |
|---|---|---|
| Meaning | **Erode** (serif) | screen titles, card titles, section names, chord symbols, key/BPM/meter figures, big counters, empty-state titles, editorial *italics* |
| Mechanics | **Manrope** (sans) | buttons, labels, list metadata, captions, inputs, tab labels, helper text |

Rules
- Erode never below 15 pt. Manrope never for a screen title.
- Use tokens only: `DesignSystem.Typography.*`. Never `.font(.system(...))` for text
  (SF Symbols sizing via `.font(.system(size:weight:))` on `Image` is fine).
- Don't chain `.fontWeight()` / `.bold()` / `.italic()` on brand fonts — pick the token
  with the right weight (variable fonts: weights resolve to named instances).
- Key tokens: `largeTitle` (screen title), `title`/`title2`/`title3`, `headline` (card titles),
  `chord`/`chordSmall` (chord symbols), `numeric` (BPM etc.), `italic`/`italicSmall`/`italicLarge`
  (editorial subtitles), `subheadline` (UI labels, Manrope semibold), `body`, `callout`,
  `caption`, `caption2`, `eyebrow` (+ `.eyebrow()` modifier: uppercase tracked group labels),
  `button`/`buttonSmall`, `timecode` (monospaced digits counters).
- Pattern for a screen header: eyebrow (e.g. "STUDIO") → Erode title → Erode italic line.
  Use `ScreenHeader`.
- Pattern for a group: `SectionHeader(title: "Arrangement", detail: "6 sections")`.

## Color
- Paper: `background` (screen), `surface` (cards), `surfaceSecondary` (wells, inactive),
  `border` (hairlines). Ink: `textPrimary/Secondary/Tertiary`.
- Teal: `primary` for fills, `primaryDark` for teal text/icons on paper, `brand` for logo waves
  / meters, `primaryLight` for soft selected backgrounds. `onPrimary` for text on teal fills.
- `accent` terracotta = the second voice (recording, highlights, sparingly).
  `record` for record buttons.
- Section colors (sage, ocean, sky, …) color-code song sections — use them as small dots,
  thin left rules, tinted fills at ≤15% opacity — never as large saturated backgrounds.
- Selected state = ink fill + paper text (`SelectableChip`), or teal for "on/playing".
- Dark mode is first-class: every color is a light/dark pair. Never hardcode `.white`/`.black`
  for text/background (except on top of colored artwork).

## Surfaces & layout
- Screen gutter 20 (`Spacing.gutter`). Vertical rhythm 8/12/16/24/32.
- Cards: `.cardStyle()` (paper, hairline, radius 18, whisper shadow). Wells: `.wellStyle()`.
- Prefer lists of rows separated by `Hairline()` inside one card over stacks of many boxed cards.
- Liquid Glass only on floating controls (tab bar, transport, FAB, toolbars). Never glass on
  content cards; never glass on glass.
- Corner radii: chips capsule, cards 18, small controls 12.

## Buttons
- Primary floating / sheet CTA: `PrimaryButton` (glassProminent teal).
- Primary inside content: `.buttonStyle(InkButtonStyle())` (ink capsule).
- Secondary inside content: `.buttonStyle(OutlineButtonStyle())`.
- Toolbar/secondary floating: `.buttonStyle(.glass)`.
- Filters/options: `SelectableChip`.

## Modals
- Every sheet: `.studioModalStyle()` (paper background, grabber, radius 28) + sensible
  `.presentationDetents`.
- Body built with `SheetScaffold(title:subtitle:primaryTitle:primaryAction:)` — Erode title,
  italic subtitle, glass close button, pinned primary CTA. No custom "Cancel/Done" bars
  unless editing requires it (then use the toolbar with `NavigationStack`).
- Destructive confirmations: `.confirmationDialog` / `.alert`, short copy.

## Motion & feedback
- Springs from `DesignSystem.Animations`. Haptics via `HapticFeedback` on meaningful actions
  (play, record, generate, add). Respect Reduce Motion for decorative loops.
- `BrandWavesMark(animated:)` for loading/empty/splash moments.

## Copy
- Short, warm, musician's vocabulary. Sentence case for buttons ("Add section").
  Italic Erode lines can be poetic but brief ("Every song starts as a sketch.").
