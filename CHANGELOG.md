# Changelog - Suonote

## [2026-01-02] - Mejoras de UX

### ✅ Implementado

#### 1. Swipe Actions en Listado de Ideas
- **Funcionalidad:** Deslizar items hacia la izquierda para mostrar acciones
- **Acciones disponibles:**
  - 🗑️ **Delete** - Elimina el proyecto permanentemente
  - 📦 **Archive/Unarchive** - Archiva o desarchiiva el proyecto
- **UX:** Swipe actions nativas de iOS con colores apropiados

#### 2. Cambio de Status del Proyecto
- **Funcionalidad:** Modal para cambiar el estado del proyecto
- **Acceso:** Tap en el badge de status en la barra de navegación
- **Estados disponibles:**
  - 💡 Idea - Just an idea, needs work
  - 🔨 In Progress - Actively working on it
  - ✨ Polished - Almost there, refining details
  - ✅ Finished - Complete and ready
  - 📦 Archived - Put on hold or completed
- **UX:** Modal con descripción de cada estado, diseño consistente

#### 3. Modal de Acordes Mejorado
- **Diseño:** Ahora usa el mismo estilo que el modal de New Section
- **Mejoras:**
  - Layout más limpio y organizado
  - Botones de +/- para duración (similar a BPM)
  - Mejor agrupación visual de secciones
  - Preview del acorde más grande y destacado
- **Consistencia:** Mismo background gradient y estilos

#### 4. Sistema de Tabs Mejorado
- **Cambio:** Reemplazado TabView por switch/case con animaciones
- **Beneficios:**
  - Navegación más fluida sin lag
  - Mejor control de transiciones
  - Custom tab bar con matched geometry effect
  - Reducción de bugs de swipe accidental
- **UX:** Transiciones suaves con fade effect

### 🏗️ Cambios Técnicos

**Archivos modificados:**
- `ProjectsListView.swift` - Added swipe actions, delete/archive functions
- `ProjectDetailView.swift` - Added status picker, improved tab system
- `ComposeTabView.swift` - Redesigned ChordPaletteSheet modal

**Mejoras de código:**
- Animaciones con spring damping para feel natural
- Uso de @Environment(\.modelContext) para persistencia
- Componentes reutilizables (StatusPickerSheet)
- Código más mantenible y organizado

### 🎨 Diseño

- Colores consistentes según estado del proyecto
- Iconos SF Symbols apropiados para cada acción
- Feedback visual inmediato en todas las interacciones
- Dark mode optimizado en todos los modals

---

## Próximos Pasos

Ver `FEATURE_PROPOSALS.md` para lista completa de features propuestos.

**Build Status:** ✅ BUILD SUCCEEDED (1 warning minor)
