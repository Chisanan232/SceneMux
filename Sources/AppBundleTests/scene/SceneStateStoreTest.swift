@testable import AppBundle
import Foundation
import XCTest

final class SceneStateStoreTest: XCTestCase {
    /// A directory of this test's own, removed when it finishes.
    ///
    /// Nothing here may go near the real state file. A test that read it would be flaky on the machine of
    /// whoever is actually using SceneMux, and a test that wrote it would take their Scenes away.
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SceneMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }
}
