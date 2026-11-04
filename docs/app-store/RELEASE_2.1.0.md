# Suonote 2.1.0 (27) — paquete de lanzamiento

Todo lo necesario para subir 2.1.0 a App Store Connect. Los textos están listos para
copiar y pegar; los límites son los de App Store Connect y se comprobaron al escribirlos.

> **Antes de nada:** el commit anterior (`aae0549`) **no compilaba** (CI en rojo: faltaba
> `import os` en `SaveHelper.swift` y otros 4 archivos). Está corregido en esta rama, pero
> las correcciones del audit se escribieron sin compilador. No subas build hasta que el
> checklist de la sección 1 esté en verde.

---

## 1. Checklist previo al archive

- [ ] CI en verde sobre esta rama (o `Cmd+B` y `Cmd+U` en Xcode 26.x).
- [ ] Añadir `MS_Basic.sf2` a `Suonote/SoundFonts/MuseScore/` (está en `.gitignore`; sin él
      el Archive sale **sin sonido en Studio**). Ver `Suonote/SoundFonts/MuseScore/README.md`.
- [ ] Probar en **dispositivo real** los puntos 🧪 de `docs/AUDIT_2026-11.md`:
      grabación con interrupción (llamada/auriculares), pantalla encendida, audio en
      background, VoiceOver en piano roll, arranque con store dañado.
- [ ] Probar actualización **desde 2.0.1 con datos reales** (no instalación limpia): abrir
      canciones existentes, duplicar, borrar, sync con otro dispositivo.
- [ ] Probar importar un `.suonote` desde Archivos y desde AirDrop/Mensajes.
- [ ] Versión `2.1.0`, build `27` (app **y** widget: ya están alineados en el proyecto).
- [ ] Rellenar `ReviewPrompt.appStoreID` (ver sección 5) y volver a correr los tests.
- [ ] Product ▸ Archive ▸ Validate App ▸ Distribute (TestFlight primero).

---

## 2. Qué hay de nuevo (App Store ▸ "Novedades de esta versión")

Máx. 4000 caracteres. Sin jerga técnica; solo cambios que el usuario nota.

### English (U.S.)

```
Suonote 2.1 is about trust: your songs, your timing, your sound.

NEW
• Share songs as .suonote files and open them on another device (AirDrop, Files, Messages).
• "Listen to an example song" on first launch, so you hear what Suonote does in seconds.
• Undo after regenerating a part in Studio.
• Spanish syllable counter in Lyrics, alongside English.
• Quick links: suonote://new starts a song and suonote://record records on your latest one (great for Shortcuts).
• Audio keeps playing with the screen locked, and the screen stays on while you record.

FIXED
• Pentatonic and blues keys no longer crash the chord suggestions.
• Flat keys now show the right note names (Bb, Eb… instead of A#, D#).
• Transposing updates every chord and the section key.
• MIDI export: chords and bass no longer drift late.
• Deleting a song now also removes its takes and audio files.
• Changing the tempo no longer erases your piano roll edits.
• Count-in only plays when you press play, not on every seek or loop.
• Pausing no longer jumps back.
• Takes are saved if a call or route change interrupts a recording.
• Duplicating a song keeps its audio tracks working.
• Takes recorded on another device now say "Audio not available on this device".
• Better contrast and full VoiceOver support in the piano roll and drum grid.

Enjoying Suonote? A rating helps other songwriters find it.
```

### Español (España / Latinoamérica)

```
Suonote 2.1 trata de confianza: tus canciones, tu tiempo, tu sonido.

NUEVO
• Comparte canciones como archivos .suonote y ábrelas en otro dispositivo (AirDrop, Archivos, Mensajes).
• "Escuchar una canción de ejemplo" al primer arranque, para oír qué hace Suonote en segundos.
• Deshacer después de regenerar una parte en Studio.
• Contador de sílabas en español en Letras, además del inglés.
• Enlaces rápidos: suonote://new empieza una canción y suonote://record graba sobre la última (ideal para Atajos).
• El audio sigue sonando con la pantalla bloqueada y la pantalla no se apaga mientras grabas.

ARREGLADO
• Las escalas pentatónicas y blues ya no cierran la app al pedir sugerencias de acordes.
• Las tonalidades con bemoles muestran los nombres correctos (Sib, Mib… en lugar de La#, Re#).
• Transponer actualiza todos los acordes y la tonalidad de la sección.
• Exportación MIDI: acordes y bajo ya no se desplazan tarde.
• Borrar una canción también elimina sus tomas y archivos de audio.
• Cambiar el tempo ya no borra tus ediciones del piano roll.
• La cuenta atrás solo suena al pulsar play, no en cada salto o vuelta del bucle.
• Al pausar ya no retrocede.
• Las tomas se guardan si una llamada o un cambio de salida interrumpe la grabación.
• Duplicar una canción mantiene sus pistas de audio funcionando.
• Las tomas grabadas en otro dispositivo indican "Audio no disponible en este dispositivo".
• Mejor contraste y VoiceOver completo en el piano roll y la rejilla de batería.

¿Te gusta Suonote? Una valoración ayuda a otros compositores a encontrarlo.
```

---

## 3. Textos de la ficha (marketing)

Límites: subtítulo 30 · texto promocional 170 · palabras clave 100 (separadas por comas,
sin espacios; no repitas palabras del nombre ni del subtítulo).

| Campo | English | Español |
|---|---|---|
| **Subtítulo** | `Songwriting, chords & lyrics` | `Compón: acordes, letras y voz` |
| **Texto promocional** (se cambia sin nueva versión) | `Capture a song idea in seconds: chords, lyrics, takes and a quick band in one project. New in 2.1: share .suonote files and undo in Studio.` | `Captura una idea en segundos: acordes, letras, tomas y una banda rápida en un proyecto. Novedad 2.1: comparte archivos .suonote y deshaz en Studio.` |
| **Palabras clave** | `songwriter,chord,progression,lyrics,recorder,demo,midi,composer,melody,notebook,band,music theory` | `compositor,canciones,acordes,progresiones,letras,grabadora,demo,midi,melodía,cuaderno,teoría musical` |

Notas:
- Revisa en App Store Connect qué palabras clave ya tienes y cuáles rankean; estas son
  una propuesta, no sustituyen datos reales (Search Ads ▸ Popularidad / App Analytics).
- El **texto promocional** se puede cambiar en cualquier momento sin nueva versión.
  El subtítulo, las palabras clave y las novedades solo cambian con una versión nueva.

---

## 4. Notas para App Review

Pegar en "Notas de revisión". Anticipan las tres preguntas que suele hacer el revisor.

```
Suonote is a songwriting workspace (chords, lyrics, recordings, quick backing tracks).
No account or login is required and there are no in-app purchases.

• Microphone: used only to record the user's own takes inside a song (Record tab).
• Background audio (UIBackgroundModes: audio): lets playback of a song and an
  in-progress recording continue when the screen locks or the user switches apps.
• Document type: Suonote can open and share its own ".suonote" song files
  (UTI com.suonote.project) via the share sheet and the Files app.
• iCloud/CloudKit: song structure, chords, lyrics and take metadata sync through the
  user's private iCloud database. Audio files stay on the device where they were recorded.
• Quick test: on first launch tap "Listen to an example song" to load a demo song, then
  open the Studio tab and press play.
```

> `UIBackgroundModes: audio` y el tipo de documento `.suonote` son **nuevos en 2.1.0**.
> Es la parte más probable de generar una pregunta del revisor; las notas de arriba la
> contestan de antemano.

Privacidad: sin cambios. `PrivacyInfo.xcprivacy` sigue declarando que no se recogen datos
ni hay tracking, así que las "Etiquetas de privacidad" de App Store Connect no cambian.

---

## 5. Opciones de marketing de App Store Connect que encajan con Suonote

Esto **no** se hace desde el repo: se configura en App Store Connect. Ordenado por
esfuerzo/retorno para una app indie de música sin compras dentro de la app.

1. **Páginas de producto personalizadas (Custom Product Pages)** — esfuerzo medio, retorno alto.
   Una URL distinta por audiencia, cada una con sus propias capturas/texto promocional.
   Ideas: *cantautores* (letras + acordes), *guitarristas* (grabar tomas + diagramas),
   *productores de bedroom* (Studio + export MIDI), *hispanohablantes* (contador de
   sílabas en español). Úsalas en Apple Search Ads y en enlaces de redes/bio.
2. **Optimización de página de producto (Product Page Optimization)** — esfuerzo bajo.
   A/B test **gratis** de icono, capturas y texto promocional (hasta 3 variantes).
   Prueba primero el orden de capturas: arrancar por el piano roll vs. por la pantalla de acordes.
   Solo se aplica a la versión ya publicada, así que se lanza *después* de que 2.1.0 salga.
3. **Eventos en la app (In-App Events)** — esfuerzo bajo. Salen en la ficha y en búsqueda.
   Para una app sin contenido estacional sirven retos: *"Escribe una canción en 7 días"*,
   *"Cover challenge"*. Cada evento necesita imagen/vídeo y fechas, y pasa por revisión,
   así que créalo con margen.
4. **Texto promocional** — esfuerzo mínimo. Cámbialo cuando quieras sin nueva versión (sección 3).
5. **Lanzamiento por fases (Phased Release)** — 7 días de rollout gradual. Recomendado para
   2.1.0: tocó audio, datos y arranque; si algo falla, lo ves antes de que llegue a todos.
6. **Valoraciones** — la tarjeta "Enjoying Suonote?" ya está en la app, pero **no abre la
   pantalla de reseñas de la App Store** hasta rellenar `ReviewPrompt.appStoreID`
   (el número de `apps.apple.com/app/id<NÚMERO>`). Mientras sea `nil` usa el diálogo del
   sistema, que Apple limita a pocas veces al año.
7. **Códigos de oferta / ofertas promocionales** — no aplican: la app no tiene compras
   dentro de la app (no hay StoreKit). Si algún día añades Pro/suscripción, entonces sí.

> Dime cuáles de las "opciones nuevas" viste en App Store Connect y las integro aquí.
> No tengo acceso a tu cuenta de Apple, así que no puedo ver cuáles son las nuevas.

---

## 6. Capturas de pantalla

- Hay 8 capturas 2.0 en `docs/app-store/screenshots-2.0/`. Siguen siendo válidas.
- Para 2.1.0 vale la pena **cambiar 1 o 2** para mostrar lo nuevo: el estado de "canción de
  ejemplo" y el piano roll con las acciones de accesibilidad. El proyecto trae
  `ScreenshotSeeder` (solo DEBUG) y el deep link
  `suonote://project/<goldenHourID>/<compose|studio|lyrics|record>` para fotografiar cada
  pestaña sin tocar la app.
- Las capturas de una Custom Product Page se envían y revisan aparte de la versión de la app,
  así que puedes probar variantes sin esperar a otro build.
