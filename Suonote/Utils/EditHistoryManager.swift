import SwiftUI
import Observation

/// Lightweight undo/redo manager for chord and section edits (U-03)
@Observable
class EditHistoryManager {
    struct Snapshot: Identifiable {
        let id = UUID()
        let label: String
        let undo: () -> Void
        let redo: () -> Void
    }
    
    private(set) var canUndo: Bool = false
    private(set) var canRedo: Bool = false
    private(set) var undoLabel: String = ""
    private(set) var redoLabel: String = ""
    
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private let maxHistory = 50
    
    /// Register an undoable action
    func register(label: String, undo: @escaping () -> Void, redo: @escaping () -> Void) {
        undoStack.append(Snapshot(label: label, undo: undo, redo: redo))
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        updateState()
    }
    
    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        snapshot.undo()
        redoStack.append(snapshot)
        updateState()
    }
    
    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        snapshot.redo()
        undoStack.append(snapshot)
        updateState()
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }
    
    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoLabel = undoStack.last?.label ?? ""
        redoLabel = redoStack.last?.label ?? ""
    }
}
