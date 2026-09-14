import Foundation

extension SceneCore {
    /// Where in a state file a decode gave up, expressed as field names and indices only.
    ///
    /// `scenes[2].attachments[1].slotId` tells a person which part of their file to look at. The rest of a
    /// `DecodingError` — its `debugDescription` — quotes the *values* it choked on, and Scene state values
    /// include application bundle ids. `AGENTS.md` treats window and application metadata as sensitive, and
    /// a diagnostic is the one thing here that is meant to be shown and copied around, so this deliberately
    /// keeps the keys and drops everything else.
    enum SceneStateCodingPath {
        /// The dotted path a `DecodingError` points at, or `nil` when the error is not one.
        static func of(_ error: any Error) -> String? {
            guard let context = context(of: error) else { return nil }
            return context.codingPath.isEmpty ? nil : describe(context.codingPath)
        }

        private static func context(of error: any Error) -> DecodingError.Context? {
            switch error as? DecodingError {
                case .typeMismatch(_, let context): context
                case .valueNotFound(_, let context): context
                case .keyNotFound(_, let context): context
                case .dataCorrupted(let context): context
                default: nil
            }
        }

        private static func describe(_ codingPath: [any CodingKey]) -> String {
            codingPath.reduce(into: "") { path, key in
                if let index = key.intValue {
                    path += "[\(index)]"
                } else {
                    path += path.isEmpty ? key.stringValue : ".\(key.stringValue)"
                }
            }
        }
    }
}
