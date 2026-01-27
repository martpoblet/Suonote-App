# Suonote — iCloud/CloudKit Setup Guide (SwiftData)

Este documento resume los pasos completos para habilitar **iCloud + CloudKit** para sincronizar proyectos en Suonote usando **SwiftData**.

## 1) Apple Developer (web)
1. Entrá a **Certificates, Identifiers & Profiles**.
2. Andá a **Identifiers → App IDs** y seleccioná tu App ID (o creá uno).
3. En **Capabilities**, habilitá **iCloud**.
4. Dentro de iCloud, activá **CloudKit** y guardá.
5. (Opcional) Creá un **CloudKit Container** dedicado si querés un nombre explícito; si no, usá el default.

## 2) Xcode — Signing & Capabilities
1. Seleccioná el target `Suonote`.
2. Tab **Signing & Capabilities**.
3. Click en **+ Capability** → agregá **iCloud**.
4. Marcá **CloudKit**.
5. Seleccioná el container (default o custom).

## 3) Info.plist / Entitlements
- Xcode suele agregar automáticamente el `iCloud` entitlement.
- Verificá que el `.entitlements` incluya:
  - `com.apple.developer.icloud-services` → `CloudKit`
  - `com.apple.developer.icloud-container-identifiers` → tu contenedor

## 4) SwiftData — Habilitar CloudKit
En `SuonoteApp.swift`, el `ModelContainer` debe configurarse con `ModelConfiguration` + `CloudKit`.

Ejemplo conceptual (a implementar):
```swift
let config = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitContainerIdentifier: "iCloud.com.tu.bundle"
)
```
> Nota: El API exacto depende de la versión de SwiftData. Se ajustará al momento de implementar.

## 5) Probar sincronización
1. Ejecutá la app en 2 dispositivos con **el mismo Apple ID**.
2. Creá un proyecto en el primero.
3. Confirmá que aparece en el segundo luego de un tiempo.

## 6) Estados de sync (UI)
Podemos mostrar un ícono de nube junto al nombre del proyecto:
- **Nube con check** si no hay cambios pendientes.
- **Nube con flecha** si hay cambios locales sin subir.
- **Nube tachada** si falla la sincronización.

Esto se hace observando cambios locales pendientes en el `ModelContext`.

## 7) Colaboración (CloudKit Sharing)
Esto requiere:
- Crear un `CKShare` para el proyecto.
- UI para compartir (ActivityViewController).
- Manejo de permisos (read-only / read-write).

Lo haremos en una segunda fase luego de que sync básico esté estable.

---

Checklist rápido
- [ ] Apple Developer: iCloud + CloudKit activado
- [ ] Xcode: Capability iCloud agregado
- [ ] Entitlements correctos
- [ ] SwiftData con CloudKit config
- [ ] Probado en 2 dispositivos

