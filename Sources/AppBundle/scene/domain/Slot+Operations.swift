import Foundation

extension SceneCore.Slot {
    /// This Slot composed a different way.
    ///
    /// Composition is the part of a Slot a person changes casually — two terminals side by side this minute,
    /// tabbed the next — and it is intent, not geometry: what the engine makes of it is read back at the seam
    /// and may differ (`SceneLayoutReport`). Identity, role, label and order are untouched, so the windows
    /// already attached here stay attached and the Slot keeps its place among its siblings.
    func composed(as composition: SceneCore.SlotComposition) -> Self {
        SceneCore.Slot(id: id, role: role, label: label, composition: composition, order: order)
    }
}
