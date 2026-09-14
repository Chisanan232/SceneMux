@testable import AppBundle
import Foundation
import XCTest

final class SceneStateFormatTest: XCTestCase {
    private let path = "/tmp/scene-state.json"

    /// One Scene as JSON, so that a test can then write something into it that the domain would never have
    /// let it build. Every interesting corruption is state a *previous or later* build wrote, and it cannot be
    /// reached through `Scene`'s initialiser — that initialiser is exactly what refuses it.
    private func fileWithTamperedScene(
        _ scene: SceneCore.Scene,
        _ tamper: (inout [String: Any]) throws -> Void,
    ) throws -> Data {
        let encoded = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(scene))
        var json = try XCTUnwrap(encoded as? [String: Any])
        try tamper(&json)
        return try JSONSerialization.data(
            withJSONObject: ["version": SceneCore.SceneStateSchema.current, "scenes": [json]],
        )
    }

    func testASceneSurvivesBeingWrittenAndReadBack() throws {
        let slot = SceneCoreFixtures.slot()
        let attachment = SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(),
            slotId: slot.id,
        )
        let scene = try SceneCoreFixtures.scene(slots: [slot], attachments: [attachment])

        let written = try SceneCore.SceneStateFormat.encoded([scene])

        XCTAssertEqual(
            SceneCore.SceneStateFormat.read(written, from: path),
            .loaded(scenes: [scene], quarantined: []),
        )
    }

    func testTheFileIsAVersionAndTheScenesAndNothingElse() throws {
        let written = try SceneCore.SceneStateFormat.encoded([])

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: written) as? [String: Any])

        // The version has to be a sibling of the payload rather than inside it: a build that cannot read
        // this file still has to be able to read the number that says so.
        XCTAssertEqual(Set(json.keys), ["version", "scenes"])
        XCTAssertEqual(json["version"] as? Int, SceneCore.SceneStateSchema.current)
    }

    func testAFileFromANewerSceneMuxIsRefusedByItsVersionAndNotByItsFields() {
        let fromTheFuture = Data(#"{ "version": 99, "scenes": [{ "unheardOf": true }] }"#.utf8)

        let read = SceneCore.SceneStateFormat.read(fromTheFuture, from: path)

        // The refusal has to name the version, not a field. "scenes[0] is missing 'title'" would send
        // someone hunting for a corrupt file when what they have is a working file and an old build.
        guard case .refused(let refusal) = read else { return XCTFail("Expected a refusal: \(read)") }
        XCTAssertEqual(
            refusal.reason,
            .unsupportedVersion(found: 99, readable: SceneCore.SceneStateSchema.readable),
        )
        XCTAssertTrue(refusal.diagnostic.contains("is version 99"), refusal.diagnostic)
        XCTAssertEqual(read.scenes, [])
    }

    func testBytesThatAreNotJsonCostEverySceneAndSayOneThing() {
        let read = SceneCore.SceneStateFormat.read(Data("not a state file".utf8), from: path)

        // Invariant I9: zero Scenes, and — just as important — exactly one thing to tell the user, because
        // "SceneMux forgot my Scenes" with no explanation is indistinguishable from "SceneMux is broken".
        XCTAssertEqual(read, .refused(.init(reason: .malformed(at: nil), path: path, preservedAt: nil)))
        XCTAssertEqual(read.scenes, [])
        XCTAssertEqual(read.diagnostics.count, 1)
    }
}
