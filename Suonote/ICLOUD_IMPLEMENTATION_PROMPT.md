# Prompt — Implementar iCloud/CloudKit en Suonote

Contexto:
- Proyecto iOS SwiftUI + SwiftData.
- Quiero sincronización nativa con iCloud usando CloudKit.
- El proyecto ya tiene `Project`, `SectionTemplate`, `StudioTrack`, etc.

Objetivo:
1) Habilitar iCloud/CloudKit para SwiftData.
2) Mostrar estado de sync en UI (nube: guardando / guardado / error).
3) Preparar la base para colaboración (CloudKit Sharing) pero sin implementarla todavía.

Tareas específicas:
- Configurar `ModelContainer` con CloudKit en `SuonoteApp.swift`.
- Crear un `SyncStatusIndicator` reutilizable (icono + color) basado en cambios pendientes del `ModelContext`.
- Mostrar ese indicador junto al título del proyecto (por ejemplo en `ProjectDetailView` / header).
- Evitar usar gradientes; mantener estilo flat.

Notas:
- iCloud + CloudKit ya están habilitados en Apple Developer y en Xcode (Signing & Capabilities).
- Usar el contenedor default salvo que se indique otro explícito.
- Bundle ID: MartinCode.Suonote

Entrega:
- Código funcionando
- Indicador de estado visible
- Sin cambios visuales agresivos
