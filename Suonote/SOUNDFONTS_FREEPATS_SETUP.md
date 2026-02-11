# Suonote - Arachno Lite Setup

Este proyecto ahora usa un solo SoundFont:

- Archivo esperado: `SoundFonts/Arachno/Arachno_Lite.sf2`

## Condicion de permiso (resumen)

Segun la respuesta de Maxime Abbey:

- Se permite distribuir una version lite si solo quitas instrumentos/samples que no usas.
- No se deben alterar los instrumentos que si conservas (sin resamplear, sin bajar de 48 kHz, sin quitar capas internas).
- Debe haber credito correcto en app y App Store.
- Debes avisarle cuando la app salga para que pueda promocionarla en Arachnosoft.

## Como construir el Arachno Lite

Herramienta sugerida: Polyphone.

1. Abre el SF2 original de Arachno.
2. Haz una copia de trabajo (no modifiques el original).
3. Elimina solo presets/instrumentos que no necesitas.
4. Mantiene intactos los presets que conservas (sin editar samples/layers).
5. Exporta como `Arachno_Lite.sf2`.
6. Verifica tamano final (< 50 MB).

## Presets GM recomendados (configuracion actual del proyecto)

- Drums: bank 128 program 0 (Studio), bank 128 program 24 (Electronic), bank 128 program 25 (TR-808/909)
- Piano: bank 0 program 0 (Grand), bank 0 program 1 (Bright), bank 0 program 4 (Electric)
- Synth: bank 0 program 87 (Lead), bank 0 program 89 (Pad Warm)
- Guitar: bank 0 program 24 (Nylon), bank 0 program 25 (Steel), bank 0 program 27 (Clean Electric), bank 0 program 29 (Overdrive)
- Bass: bank 0 program 33 (Finger), bank 0 program 38 (Synth Bass)
- Strings: bank 0 program 48 (String Ensemble), bank 0 program 50 (Synth Strings 1), bank 0 program 51 (Synth Strings 2)
- Brass: bank 0 program 62 (Synth Brass 1), bank 0 program 63 (Synth Brass 2)
- Woodwinds: bank 0 program 71 (Clarinet), bank 0 program 66 (Tenor Sax), bank 0 program 73 (Flute)
- Organ: bank 0 program 16 (Drawbar), bank 0 program 19 (Church)
- Mallets: bank 0 program 13 (Xylophone), bank 0 program 14 (Tubular Bells)

Total: 26 presets.

## Estrategia para llegar a < 50 MB

1. Fase A: deja exactamente los 20 presets de arriba.
2. Fase B: limpia instrumentos/samples no usados.
3. Si aun supera 50 MB, reduce en este orden (manteniendo 2 por familia hasta donde se pueda):
   - Quitar `Strings 2` (51) y dejar solo `Strings 1` (50).
   - Quitar `Brass 2` (63) y dejar solo `Brass 1` (62).
   - Quitar `Pad Warm` (89) y dejar solo `Lead` (87).
   - Quitar `Tubular Bells` (14) y dejar solo `Xylophone` (13).
4. Reexportar y medir tamano en cada iteracion.

## Credito obligatorio sugerido

Texto in-app:

`Arachno SoundFont (Lite subset) by Maxime Abbey (Arachnosoft). Used with permission.`

Texto para App Store (descripcion):

`Includes a Lite subset of Arachno SoundFont by Maxime Abbey (Arachnosoft), used with permission.`

URL oficial:

`https://www.arachnosoft.com/main/soundfont.php`
