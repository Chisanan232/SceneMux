import Foundation

extension SceneCore {
    /// A window, named in a form that survives a restart.
    ///
    /// Deliberately not a `CGWindowID` and not an engine `Window`: a live window identity is meaningless
    /// after the owning application quits, and persisting one would let stale state address a window that
    /// is not the one it meant. A `WindowRef` records *intent* — this application's *n*-th window — and is
    /// resolved against the windows that actually exist at the moment it is used.
    ///
    /// It carries no title, no frame, no monitor and no process id. That is invariant I11, and it is the
    /// reason Scene state can be written to disk without recording what is on someone's screen.
    struct WindowRef: Hashable, Sendable, Codable, CustomStringConvertible {
        /// The owning application's bundle id, e.g. `com.apple.Terminal`.
        let bundleId: String
        /// Which of that application's windows this is, in the app's own window order. Zero-based.
        let ordinalWithinApp: Int

        var description: String { "\(bundleId)#\(ordinalWithinApp)" }

        init(bundleId: String, ordinalWithinApp: Int) throws {
            let trimmedBundleId = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBundleId.isEmpty {
                throw SceneCoreError.emptyBundleId
            }
            if ordinalWithinApp < 0 {
                throw SceneCoreError.negativeWindowOrdinal(ordinalWithinApp)
            }
            self.bundleId = trimmedBundleId
            self.ordinalWithinApp = ordinalWithinApp
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                bundleId: container.decode(String.self, forKey: .bundleId),
                ordinalWithinApp: container.decode(Int.self, forKey: .ordinalWithinApp),
            )
        }
    }
}
