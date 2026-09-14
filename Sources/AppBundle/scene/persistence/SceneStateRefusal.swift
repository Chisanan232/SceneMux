import Foundation

extension SceneCore {
    /// Why SceneMux started with no Scenes, in words a person can act on.
    ///
    /// A refusal is the whole-file outcome of invariant I9: unreadable or unrecognised state yields zero
    /// Scenes and zero window operations. It is a value rather than a thrown error because the caller is
    /// never allowed to *handle* it by guessing — the only thing to do with it is show it, and the UI is
    /// required to show it, or "SceneMux forgot my Scenes" is indistinguishable from "SceneMux is broken".
    struct SceneStateRefusal: Hashable, Sendable {
        enum Reason: Hashable, Sendable {
            /// The file is there but could not be read at all — permissions, a bad symlink, a full disk.
            case unreadable
            /// The bytes are not the JSON this format is made of.
            case malformed(at: String?)
            /// A version outside what this build can read. Almost always a newer SceneMux wrote it.
            case unsupportedVersion(found: Int, readable: ClosedRange<Int>)
            /// The JSON was fine and a Scene in it was not: no title, or two Slots claiming one identity.
            ///
            /// Carries the domain's reason as text rather than the `SceneCoreError` itself, so that a refusal
            /// stays a plain value that can be compared and stored. A quarantined *attachment* is the
            /// tolerant case; a Scene that cannot exist at all is not repairable by leaving something out.
            case impossibleScene(String)
        }

        let reason: Reason
        /// The state file this is about.
        let path: String
        /// Where the unreadable file was kept, when it was moved out of the way of the next save.
        let preservedAt: String?

        /// One line for the user, naming the file, the cause, and what SceneMux did about it.
        var diagnostic: String {
            "\(cause) SceneMux started with no Scenes and moved no windows.\(preservation)"
        }

        private var cause: String {
            switch reason {
                case .unreadable:
                    "Could not read the Scene state file at \(path)."
                case .malformed(let location):
                    location.map { "The Scene state file at \(path) is not readable JSON, at \($0)." }
                        ?? "The Scene state file at \(path) is not readable JSON."
                case .unsupportedVersion(let found, let readable):
                    "The Scene state file at \(path) is version \(found); this build of SceneMux reads "
                        + "\(readable.lowerBound) to \(readable.upperBound). A newer SceneMux most likely "
                        + "wrote it."
                case .impossibleScene(let reason):
                    "The Scene state file at \(path) describes a Scene SceneMux cannot use: \(reason)."
            }
        }

        /// The same refusal, naming where the refused file was kept.
        ///
        /// A separate step from making the refusal because the format knows *why* it refused and the store
        /// knows *whether the copy succeeded* — and a refusal that claimed to have preserved a file it did
        /// not would be the worst sentence in this whole path.
        func preserved(at path: String) -> SceneStateRefusal {
            SceneStateRefusal(reason: reason, path: self.path, preservedAt: path)
        }

        private var preservation: String {
            preservedAt.map { " The original was kept at \($0)." } ?? ""
        }
    }
}
