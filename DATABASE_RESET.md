# Database Reset Instructions

## Si encuentras el error de migración SIGABRT

El error ocurre cuando hay datos antiguos en SwiftData que no tienen el campo `recordingType`.

### Solución Rápida:

**En el simulador:**
1. Device → Erase All Content and Settings
2. O elimina la app y vuelve a instalar

**En dispositivo real:**
1. Elimina la app
2. Reinstala desde Xcode

### Solución Programática (Ya implementada):

El `SuonoteApp.swift` ya tiene manejo de errores que:
1. Detecta fallas de migración
2. Elimina la base de datos antigua automáticamente
3. Crea una nueva

### Detalles Técnicos:

El campo `recordingType` ahora usa un patrón especial para SwiftData:
```swift
// Stored as String (compatible con SwiftData)
private var _recordingType: String?

// Accessed as enum (type-safe)
var recordingType: RecordingType {
    get { RecordingType(rawValue: _recordingType ?? "") ?? .voice }
    set { _recordingType = newValue.rawValue }
}
```

Esto permite:
- ✅ Valores default (.voice)
- ✅ Compatibilidad hacia atrás
- ✅ No crashes en datos existentes
- ✅ Type safety en código

### Testing:

1. Run app (debería funcionar)
2. Si falla, revisar logs para "Migration failed"
3. Debería auto-recuperar eliminando DB antigua

### Notas:

- Los datos antiguos se perderán (es esperado en desarrollo)
- En producción, necesitarías una migración real
- Para beta/producción, considera usar `ModelConfiguration` con versioning
