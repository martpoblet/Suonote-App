# 🎤 Permiso de Micrófono - IMPORTANTE

## ⚠️ La app crashea al grabar porque falta el permiso

### Solución: Agregar en Xcode

**Pasos:**

1. **Abre el proyecto en Xcode**
2. **Click en "Suonote"** (el proyecto, parte superior izquierda)
3. **Select Target "Suonote"**
4. **Tab "Info"**
5. **Busca o agrega:** `Custom iOS Target Properties`
6. **Click en el "+"** para agregar nueva entrada
7. **Escribe:** `Privacy - Microphone Usage Description`
   - O busca: `NSMicrophoneUsageDescription`
8. **Value:** `Suonote needs access to your microphone to record audio takes for your song ideas`
9. **Cmd + S** (guardar)
10. **Clean Build Folder** (Shift + Cmd + K)
11. **Cmd + R** (Run)

### Verificar que funcionó:

Cuando toques el botón de grabar, deberías ver:
- Un diálogo pidiendo permiso
- NO debería crashear
- Si dices "Allow" → grabación funciona

---

## Alternativa: Modificar el proyecto manualmente

Si no puedes hacerlo en Xcode UI, puedes editar:

**Archivo:** `Suonote.xcodeproj/project.pbxproj`

Busca la sección con `INFOPLIST_KEY_` y agrega:

```
INFOPLIST_KEY_NSMicrophoneUsageDescription = "Suonote needs access to your microphone to record audio takes for your song ideas";
```

Pero es MÁS FÁCIL hacerlo desde Xcode UI.

---

## 🎯 Una vez agregado:

La app funcionará perfectamente y podrás:
- ✅ Grabar audio
- ✅ Ver waveforms
- ✅ Reproducir takes
- ✅ Eliminar grabaciones

**Esto es REQUERIDO por Apple** - sin esto la app crashea inmediatamente al intentar acceder al micrófono.
