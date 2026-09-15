import Foundation

extension SceneCore {
    /// How a window was arranged on its own surface: laid out with its neighbours, or floating above them.
    ///
    /// Recorded beside `Attachment.originSurface`, for the same reason and at the same moment. A Scene
    /// arranges the windows it holds, so once a window is in one, asking how it is arranged answers the
    /// *Scene's* question rather than the window's — and by the time the Scene ends, what the window used to
    /// be is gone. So it is observed when the window is borrowed and replayed when it goes back.
    ///
    /// Two cases and no more. This is deliberately not a description of a layout: no orientation, no
    /// container, no frame, no place among siblings (invariant I11). Which of the two a window was is what a
    /// person notices the instant it comes back wrong; exactly where it sat among its neighbours is the
    /// engine's business, and after a Scene has been and gone it is not knowable anyway.
    ///
    /// The raw values are on-disk spellings. Changing one is a state format change.
    enum WindowArrangement: String, Hashable, Sendable, Codable {
        /// The engine laid it out: it shared the surface with the windows around it.
        case tiled
        /// It floated above the surface, at a size and a place of its own.
        case floating
    }
}
