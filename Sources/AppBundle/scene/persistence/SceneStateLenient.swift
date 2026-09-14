import Foundation

extension SceneCore {
    /// One element of a persisted array that records its own failure instead of failing the whole array.
    ///
    /// `[Attachment]` decoded directly is all-or-nothing: one unreadable entry loses every other window in
    /// the Scene. Wrapping the element in a type whose initialiser never throws keeps the array decode going
    /// and hands the caller a hole it can report — which is the attachment-level tolerance the architecture
    /// document requires, and the same bargain `Ownership.init(from:)` already makes.
    ///
    /// It is deliberately not applied to a whole `Scene`. A Scene that does not decode is a file this build
    /// does not understand, and invariant I9 says that yields zero Scenes rather than a partial read.
    struct SceneStateLenient<Value: Decodable>: Decodable {
        /// The decoded element, or `nil` when this entry could not be read.
        let value: Value?
        /// Where the decode gave up, in field names and indices only. `nil` when it succeeded, and also when
        /// the failure was not a `DecodingError` and so points at nothing.
        let codingPath: String?

        init(from decoder: any Decoder) throws {
            do {
                value = try Value(from: decoder)
                codingPath = nil
            } catch {
                value = nil
                codingPath = SceneStateCodingPath.of(error)
            }
        }
    }
}
