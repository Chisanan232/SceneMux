import Foundation

extension SceneCore {
    /// The version of the on-disk Scene state format, and which versions this build can read.
    ///
    /// The version is written into every state file and read back *before* anything else, which is what
    /// makes the format changeable at all: a build that meets a number it does not know refuses the file
    /// with that number in the diagnostic, instead of failing somewhere inside a field it has never heard
    /// of and reporting a decode error nobody can act on.
    ///
    /// The migration seam is `oldestReadable`. Introducing version 2 means writing `current = 2`, leaving
    /// `oldestReadable` at 1, and reading the older shape into the new one at the point where the envelope
    /// decodes its Scenes — the one place that already knows which version it is holding. Until there is a
    /// version 2 there is deliberately no migration code here: an empty migration step with no caller is a
    /// thing that rots.
    enum SceneStateSchema {
        /// The version this build writes.
        static let current = 1
        /// The oldest version this build can read.
        static let oldestReadable = 1

        /// Whether this build can read a state file written with this version.
        static func canRead(_ version: Int) -> Bool {
            (oldestReadable ... current).contains(version)
        }
    }
}
