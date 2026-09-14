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

        /// Just the version field, read on its own.
        private struct VersionProbe: Decodable {
            let version: Int
        }

        /// The envelope as read: the Scenes in their permissive form, and no version — the version has
        /// already been checked by the time this decodes, and checking it twice invites the two checks to
        /// disagree.
        private struct PersistedEnvelope: Decodable {
            let scenes: [PersistedScene]
        }

        /// The bytes to write for these Scenes, stamped with the version this build writes.
        static func encoded(_ scenes: [Scene]) throws -> Data {
            try JSONEncoder.winMuxDefault.encode(Envelope(version: SceneStateSchema.current, scenes: scenes))
        }

        /// The version these bytes claim, read before anything else in them.
        ///
        /// Probing the version separately is what lets a future build say "this file is version 3 and I read
        /// 1 to 2" instead of reporting a type mismatch inside a field that did not exist when it was
        /// written. Decoding the whole envelope first and inspecting the version afterwards cannot do that:
        /// the decode has already failed by then, for the wrong reason.
        static func version(of data: Data) throws -> Int {
            try JSONDecoder().decode(VersionProbe.self, from: data).version
        }

        /// What these bytes mean, as an outcome rather than a thrown error.
        ///
        /// `path` is only ever used to write the diagnostic — the bytes have already been read — so the whole
        /// format is exercisable without touching a disk.
        static func read(_ data: Data, from path: String) -> SceneStateLoad {
            let claimedVersion: Int
            do {
                claimedVersion = try version(of: data)
            } catch {
                return .refused(refusal(.malformed(at: SceneStateCodingPath.of(error)), path))
            }
            guard SceneStateSchema.canRead(claimedVersion) else {
                let reason = SceneStateRefusal.Reason
                    .unsupportedVersion(found: claimedVersion, readable: SceneStateSchema.readable)
                return .refused(refusal(reason, path))
            }

            let persisted: [PersistedScene]
            do {
                persisted = try JSONDecoder().decode(PersistedEnvelope.self, from: data).scenes
            } catch {
                return .refused(refusal(.malformed(at: SceneStateCodingPath.of(error)), path))
            }

            var scenes: [Scene] = []
            var quarantined: [SceneStateQuarantine] = []
            for entry in persisted {
                let resolved: (scene: Scene, quarantined: [SceneStateQuarantine])
                do {
                    resolved = try entry.resolved()
                } catch let error as SceneCoreError {
                    return .refused(refusal(.impossibleScene("\(error)"), path))
                } catch {
                    return .refused(refusal(.malformed(at: SceneStateCodingPath.of(error)), path))
                }
                scenes.append(resolved.scene)
                quarantined += resolved.quarantined
            }
            return .loaded(scenes: scenes, quarantined: quarantined)
        }

        private static func refusal(_ r: SceneStateRefusal.Reason, _ path: String) -> SceneStateRefusal {
            SceneStateRefusal(reason: r, path: path, preservedAt: nil)
        }
    }
}
