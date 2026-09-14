import Foundation

extension SceneCore {
    /// The bytes of a Scene state file: `{ "version": 1, "scenes": [...] }`, and nothing else.
    ///
    /// Kept apart from the store that reads and writes files so that every format decision — the version
    /// probe, what is refused, what is quarantined — is testable from a `Data` literal, with no directory to
    /// create and no disk to leave dirty. The store's job is then only *where* the bytes live.
    enum SceneStateFormat {
        /// The envelope as written. `Scene` encodes itself; this only stamps the version onto it.
        private struct Envelope: Encodable {
            let version: Int
            let scenes: [Scene]
        }

        /// The bytes to write for these Scenes, stamped with the version this build writes.
        static func encoded(_ scenes: [Scene]) throws -> Data {
            try JSONEncoder.winMuxDefault.encode(Envelope(version: SceneStateSchema.current, scenes: scenes))
        }
    }
}
