# 🔧 Troubleshooting: Project Creation Issue

## Cambios Aplicados para Fix

### 1. ✅ ModelContainer Mejorado
**Archivo:** `SuonoteApp.swift`

**Antes:**
```swift
.modelContainer(for: [Project.self, ...])
```

**Ahora:**
```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([...])
    let modelConfiguration = ModelConfiguration(
        schema: schema, 
        isStoredInMemoryOnly: false  // ← Explícitamente false
    )
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
}()
```

**Por qué:** 
- Configuración explícita del container
- `isStoredInMemoryOnly: false` asegura persistencia
- Shared container entre vistas
- Debug print al crear

---

### 2. ✅ CreateProject Mejorado
**Archivo:** `CreateProjectView.swift`

**Cambios:**
```swift
private func createProject() {
    let project = Project(...)
    
    // Force update timestamp
    project.updatedAt = Date()  // ← Nuevo
    
    modelContext.insert(project)
    
    // Save with error logging
    do {
        try modelContext.save()
        print("✅ Project saved: \(project.title)")  // ← Debug
    } catch {
        print("❌ Error: \(error)")  // ← Debug
    }
    
    dismiss()
}
```

---

### 3. ✅ Debug Indicators
**Archivo:** `ProjectsListView.swift`

**Agregado:**
- Debug message en la UI
- `onChange(of: allProjects.count)` para detectar cambios
- Mensaje temporal que desaparece en 3 segundos

**Verás en pantalla:**
```
Total projects: 0
→ Después de crear:
Projects updated: 0 → 1
```

---

## 🧪 Pasos para Probar

### 1. Clean Build Folder
En Xcode:
```
Product → Clean Build Folder (Shift + Cmd + K)
```

### 2. Borrar App del Simulador
```
1. Detener la app si está corriendo
2. En el simulador: long press en el icono
3. Delete App
4. Confirmar
```

### 3. Build & Run
```
Cmd + R
```

### 4. Crear Proyecto
```
1. Tap FAB (+)
2. Ingresar título (ej: "Test 1")
3. Tap Create
4. Deberías ver: "Projects updated: 0 → 1"
5. El proyecto debe aparecer en la lista
```

---

## 🔍 Debug en Console

Abre la **Console** en Xcode (Cmd + Shift + Y) y busca:

**Si funciona verás:**
```
✅ ModelContainer created successfully
✅ Project saved: Test 1
```

**Si falla verás:**
```
❌ Error saving project: [error details]
```

---

## 🐛 Posibles Problemas

### Problema 1: SwiftData Cache
**Síntoma:** Proyectos no aparecen incluso después de guardar

**Solución:**
```bash
# En Terminal:
xcrun simctl --set testing delete all
```

Luego reinstala la app.

---

### Problema 2: Simulator Storage
**Síntoma:** Error al guardar

**Solución:**
```
Simulador → Device → Erase All Content and Settings
```

---

### Problema 3: ModelContainer Duplicado
**Síntoma:** Warnings en console sobre multiple containers

**Solución:** Ya está arreglado con `sharedModelContainer`

---

## 📊 Verificación Manual

### Check 1: Ver datos en el simulador
```
# En Terminal:
xcrun simctl get_app_container booted com.yourcompany.Suonote data

# Ver archivos:
ls -la [path del comando anterior]/Library/Application Support/default.store
```

### Check 2: SwiftData Schema
Si ves errores de migration, puede ser que el modelo cambió.

**Fix:**
```swift
// En SuonoteApp.swift, cambiar a:
ModelConfiguration(
    schema: schema, 
    isStoredInMemoryOnly: false,
    allowsSave: true  // ← Agregar
)
```

---

## ✅ Checklist de Verificación

Antes de reportar que no funciona, verifica:

- [ ] Clean Build Folder ejecutado
- [ ] App eliminada del simulador
- [ ] Simulador reiniciado
- [ ] Build succeeded sin warnings
- [ ] Console abierta y visible
- [ ] Debug message aparece en UI
- [ ] Checked console logs
- [ ] Probado con título simple (ej: "Test")
- [ ] Probado crear 2-3 proyectos

---

## 🆘 Si Aún No Funciona

### Opción A: Reset Total
```bash
# 1. Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Suonote-*

# 2. Reset simulador
xcrun simctl erase all

# 3. Rebuild
cd /Users/martinpoblet/Documents/Xcode/Suonote
xcodebuild -scheme Suonote clean build
```

### Opción B: Verificar Model
Puede haber un problema con el modelo. Compartir:
1. Screenshot de la console cuando creas un proyecto
2. Screenshot de la app después de crear
3. Cualquier warning en el build

---

## 📝 Logs Importantes

**Console logs a buscar:**
```
✅ = Todo bien
❌ = Error
⚠️ = Warning que puede causar problemas
```

**Específicamente:**
- `ModelContainer created`
- `Project saved: [nombre]`
- Cualquier línea con `SwiftData` o `CoreData`
- Stack traces de errores

---

## 🎯 Expected Behavior

**Después del fix:**

1. Abres la app → ves "Total projects: 0"
2. Tap FAB → modal se abre
3. Ingresas "Mi Canción"
4. Tap Create → modal se cierra
5. **INMEDIATAMENTE** ves:
   - Debug message: "Projects updated: 0 → 1"
   - Card del proyecto en la lista
   - Gradient header con "Idea" status
   - Título "Mi Canción"

**Si NO pasa:**
Algo está mal con SwiftData persistence.

---

## 💡 Quick Test

Para probar rápidamente, agrega este botón temporal:

```swift
// En ProjectsListView, dentro del body:
Button("Test Add") {
    let test = Project(title: "Quick Test \(Date().timeIntervalSince1970)")
    modelContext.insert(test)
    try? modelContext.save()
}
```

Si este botón funciona pero el modal no:
→ Problema con el dismiss() o el contexto del modal

Si este botón tampoco funciona:
→ Problema con SwiftData setup general

---

**Build Status:** ✅ SUCCEEDED  
**Next Step:** Run in simulator y revisar Console
