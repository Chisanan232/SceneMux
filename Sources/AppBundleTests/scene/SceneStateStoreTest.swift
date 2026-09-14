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

    func testAFirstRunIsNotTheSameAnswerAsAFileThatCouldNotBeRead() throws {
        let url = try temporaryDirectory().appending(path: "scene-state.json")

        let load = SceneCore.SceneStateStore(url: url).load()

        // Nothing to apologise for on a first run, and nothing to show the user. This is the case that must
        // never be confused with a refusal: the next save is entitled to write over nothing.
        XCTAssertEqual(load, .noStateFile(path: url.path))
        XCTAssertEqual(load.diagnostics, [])
    }

    func testScenesComeBackFromDiskExactlyAsTheyWereSaved() throws {
        let slot = SceneCoreFixtures.slot()
        let scene = try SceneCoreFixtures.scene(
            slots: [slot],
            attachments: [
                SceneCoreFixtures.attachment(
                    windowRef: try SceneCoreFixtures.windowRef(),
                    slotId: slot.id,
                ),
            ],
        )
        let store = SceneCore.SceneStateStore(url: try temporaryDirectory().appending(path: "state.json"))

        try store.save([scene])

        XCTAssertEqual(store.load(), .loaded(scenes: [scene], quarantined: []))
    }

    func testSavingIntoADirectoryThatIsNotThereYetCreatesIt() throws {
        let directory = try temporaryDirectory().appending(path: "SceneMux", directoryHint: .isDirectory)
        let store = SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json"))

        try store.save([try SceneCoreFixtures.scene()])

        // The real directory is created on demand too — an install that has never saved Scene state does not
        // have one, and the first attach must not be the thing that fails.
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path))
    }

    func testAFileThisBuildCannotReadIsCopiedAsideBeforeASaveCanReplaceIt() throws {
        let url = try temporaryDirectory().appending(path: "scene-state.json")
        let refusedBytes = Data(#"{ "version": 1, "scenes": "not an array of Scenes" }"#.utf8)
        try refusedBytes.write(to: url)
        let store = SceneCore.SceneStateStore(url: url)

        let load = store.load()
        try store.save([])

        // The save is entitled to replace the file — SceneMux has to be usable again. What it must not do is
        // be the moment the state stopped existing, so the refused bytes are kept where a person can get at
        // them, and the refusal says where.
        guard case .refused(let refusal) = load else { return XCTFail("Expected a refusal: \(load)") }
        let preservedAt = try XCTUnwrap(refusal.preservedAt)
        XCTAssertEqual(
            URL(filePath: preservedAt).lastPathComponent,
            SceneCore.SceneStateStore.preservedFilename,
        )
        XCTAssertEqual(try Data(contentsOf: URL(filePath: preservedAt)), refusedBytes)
        XCTAssertTrue(refusal.diagnostic.contains(preservedAt), refusal.diagnostic)
        XCTAssertNotEqual(try Data(contentsOf: url), refusedBytes)
    }

    func testSavingOverAndOverLeavesOneStateFileAndNoDebris() throws {
        let directory = try temporaryDirectory()
        let store = SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json"))

        for _ in 0 ..< 5 {
            try store.save([try SceneCoreFixtures.scene()])
        }

        // An atomic write works through a temporary file, and Scene state is saved every time a window is
        // attached. A leak here would quietly fill somebody's Application Support directory for months.
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: directory.path),
            ["scene-state.json"],
        )
    }
}
