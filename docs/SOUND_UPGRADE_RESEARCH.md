# Suonote — Research: reemplazo de Arachno y upgrade de sonido

Objetivo: pasar de `Arachno_Lite.sf2` (63 MB, licencia no-comercial → 🔴 ver AUDIT A-01) a un
sonido de calidad "producción", con presupuesto de hasta ~700 MB de app.

---

## 1. Restricciones técnicas del stack actual

El playback usa `AVAudioUnitSampler` (AUSampler de Apple). Esto define qué banco sirve:

1. **Formatos:** solo SF2 / DLS / EXS24 / aupreset. **No soporta SF3** (SF2 comprimido con
   Vorbis). Cualquier banco elegido debe conseguirse o convertirse a SF2 sin comprimir.
2. **Memoria:** `loadSoundBankInstrument` carga *un preset por sampler*, no el banco entero.
   Un SF2 de 500 MB no significa 500 MB de RAM: cada pista carga solo sus samples. Presets
   muy multilayer (pianos de 8 velocity layers) suben el tiempo de carga → precargar en
   background al abrir Studio.
3. **Compatibilidad SF2 parcial:** AUSampler ignora buena parte de los *modulators* SF2
   (LFOs de vibrato, rutas de filtro complejas). Bancos que dependen de programación
   avanzada de modulators (p. ej. **GeneralUser GS**, diseñado para FluidSynth) pierden
   carácter bajo AUSampler. Bancos principalmente *sample-based* portan mejor.
4. App Store: límite 4 GB por app; ya no hay límite duro de descarga celular pero >200 MB
   muestra aviso. 700 MB instalado es viable; ver §4 para estrategia de distribución.

---

## 2. Candidatos evaluados

| Banco | Tamaño SF2 | Licencia | Calidad bajo AUSampler | Veredicto |
|---|---|---|---|---|
| **MuseScore General HQ** | ~479 MB | **MIT** | ★★★★☆ — sample-based, pianos/cuerdas/vientos muy superiores a Arachno Lite | ✅ **Recomendado como banco base** |
| MuseScore General (estándar) | ~208 MB | MIT | ★★★½ | Buen plan B si 479 MB resulta excesivo |
| FluidR3 GM | ~141 MB | MIT | ★★★ — base de la que deriva MuseScore General; superado por éste | ❌ obsoleto frente a MS General |
| GeneralUser GS 2.x | ~30 MB | Propia, muy permisiva (uso comercial OK) | ★★½ en AUSampler (depende de modulators que AUSampler no implementa; brilla en FluidSynth) | ⚠️ Solo como fallback compacto |
| Arachno (full) | ~148 MB | **No comercial** | — | ❌ descartado por licencia |
| Timbres of Heaven | ~390 MB | Ambigua (samples de origen mixto) | — | ❌ mismo problema legal que Arachno |
| SGM-V2.01 | ~240 MB | Ambigua | — | ❌ ídem |

### Refuerzos puntuales (segunda fase, dentro del presupuesto restante ~200 MB)
Instrumentos "héroe" donde un GM bank siempre queda corto:
- **Piano**: Salamander Grand C5 (CC-BY 3.0, conversiones SF2 de ~150-250 MB según
  velocity layers). Es el piano libre de referencia.
- **Drums**: kits sampleados dedicados (hay kits CC0 en musical-artifacts.com); los kits GM
  son el punto más débil percibido de cualquier soundfont.
- **Orquestal**: VSCO2 Community Edition / VCSL (CC0) si Strings/Brass piden más realismo.

Estrategia: el banco base cubre todo el GM; los refuerzos se cargan **por variante**
(`InstrumentVariant` ya distingue variantes → basta con que `SoundFontManager` resuelva
URL + program por variante en lugar de un único archivo global).

---

## 3. Recomendación

**Fase 1 (core):** MuseScore General HQ (MIT) como único banco. ~479 MB.
- Licencia limpia y verificable (mantenida por S. Christian Collins para MuseScore).
- Sample-based → se comporta bien bajo AUSampler.
- Cubre los 128 programas GM + percusión, así que **todo el mapeo GM existente
  (`InstrumentVariant.midiProgram`, banco de percusión, canal 9) sigue funcionando sin
  tocar el modelo**.

**Fase 2 (héroes):** Salamander piano + drum kits dedicados según presupuesto restante.

**Fase 3 (opcional, si la fidelidad lo pide):** evaluar motor **FluidSynth** (LGPL 2.1,
integrable en iOS como framework dinámico) que implementa SF2 completo y soporta SF3
comprimido (bajaría el peso a ~⅓). Es un cambio de motor, no de contenido: el banco MIT
elegido sirve igual. No lo recomiendo para la primera entrega — AUSampler + MS General HQ
ya es un salto enorme y no añade dependencias.

---

## 4. Distribución del peso

Opciones, en orden de recomendación:

1. **On-Demand Resources (ODR):** banco base etiquetado como *Initial Install Asset* (se
   descarga con la app pero no cuenta para el límite de descarga del binario) y los packs
   "héroe" como ODR bajo demanda. Pega perfecto con el modelo de variantes.
2. Descarga en primer arranque (URLSession background + hosting propio): más control, más
   mantenimiento. Solo si ODR molesta con CloudKit/review.
3. Todo embebido en el bundle: lo más simple; 700 MB de descarga inicial. Aceptable según
   tu criterio, pero ODR da lo mismo con mejor primera impresión.

**Cuidado:** el SF2 no debe entrar a "Copy Bundle Resources" con compresión de asset; va
como recurso plano (como hoy). Verificar que App Thinning no lo duplique por slice.

---

## 5. Cambios de código necesarios

1. **`SoundFontManager`**
   - Reemplazar `arachnoLiteFilePath` por una tabla `variant → (archivo, banco, program)`.
   - Soportar múltiples archivos SF2 (base + héroes) con fallback al base.
   - API de precarga asíncrona (warm-up de presets al entrar a Studio).
2. **`StudioPlaybackEngine.loadInstrument`** — sin cambios estructurales: ya resuelve URL +
   program + bancos melodic/percussion con fallbacks. Solo se beneficia de la tabla nueva.
3. **`ChordPreviewPlayer`** — elegir el preset de preview del banco nuevo (el EP de MS
   General HQ o el piano héroe) + fixes del audit (A-06).
4. **`StudioGenerator`** — aprovechar velocity layers reales: ampliar rangos de velocidad
   por estilo (hoy los acordes usan velocidades planas por estilo), acentos métricos en
   drums, y revisar `defaultNaturalness` para que el humanizado se note con samples
   dinámicos.
5. **Master bus por estilo** (ver plan de Studio): EQ + glue compressor + limiter con
   presets por `StudioStyle` para que el resultado suene "mezclado".
6. **Créditos:** actualizar `THIRD_PARTY_NOTICES.md` y `SoundFontCreditsView` (MIT de
   MuseScore General requiere aviso de copyright; CC-BY de Salamander requiere atribución).
7. **Tests (T-01):** test que cargue cada `InstrumentVariant` contra el banco real y falle
   si un program no existe.

## 6. Matriz de validación de sonido (manual, antes de mergear)

Por cada instrumento de `StudioInstrument` × sus variantes:
- [ ] carga sin fallback al banco del sistema (log limpio)
- [ ] afinación y octava correctas con `instrumentRange`
- [ ] sustain/release naturales con notas largas (pads, strings)
- [ ] drums: cada lane del `DrumPitchMap` suena (36/38/42/46/39/37/45/47/50/51/49/56)
- [ ] sin clicks al solapar notas (voice stealing)
- [ ] tiempo de carga del preset < 1 s en dispositivo más viejo soportado
