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

    func testAnAttachmentToASlotTheSceneNoLongerHasCostsOnlyThatAttachment() throws {
        let slot = SceneCoreFixtures.slot()
        let windowRef = try SceneCoreFixtures.windowRef()
        let scene = try SceneCoreFixtures.scene(
            slots: [slot],
            attachments: [SceneCoreFixtures.attachment(windowRef: windowRef, slotId: slot.id)],
        )
        let file = try fileWithTamperedScene(scene) { json in
            var attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
            attachments[0]["slotId"] = "a-slot-a-later-build-removed"
            json["attachments"] = attachments
        }

        let read = SceneCore.SceneStateFormat.read(file, from: path)

        // The Scene and its Slots survive. Losing the whole Scene over one stale entry would throw away the
        // layout and the ownership record of every other window in it.
        XCTAssertEqual(read.scenes.map(\.slots), [[slot]])
        XCTAssertEqual(read.scenes.map(\.attachments), [[]])
        guard case .loaded(_, let quarantined) = read else { return XCTFail("Expected a read: \(read)") }
        XCTAssertEqual(quarantined.map(\.windowRef), [windowRef])
        XCTAssertEqual(
            quarantined.map(\.reason),
            [.unknownSlot(SceneCore.SlotId("a-slot-a-later-build-removed"))],
        )
    }

    func testOneWindowAttachedTwiceKeepsItsFirstAttachmentAndOnlyItsFirst() throws {
        let slot = SceneCoreFixtures.slot()
        let windowRef = try SceneCoreFixtures.windowRef()
        let attachment = SceneCoreFixtures.attachment(windowRef: windowRef, slotId: slot.id)
        let scene = try SceneCoreFixtures.scene(slots: [slot], attachments: [attachment])
        let file = try fileWithTamperedScene(scene) { json in
            let attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
            json["attachments"] = attachments + attachments
        }

        let read = SceneCore.SceneStateFormat.read(file, from: path)

        // Invariant I4 allows one attachment per window. The first one recorded is the one kept, so which
        // window SceneMux may move does not depend on the order a corrupt file happens to list them in.
        XCTAssertEqual(read.scenes.map(\.attachments), [[attachment]])
        guard case .loaded(_, let quarantined) = read else { return XCTFail("Expected a read: \(read)") }
        XCTAssertEqual(quarantined.map(\.reason), [.alreadyAttached])
        XCTAssertEqual(quarantined.map(\.windowRef), [windowRef])
    }

    func testAnAttachmentLeftInAnEndedSceneIsNotReadAsPermissionToMoveThatWindow() throws {
        let slot = SceneCoreFixtures.slot()
        let scene = try SceneCoreFixtures.scene(
            slots: [slot],
            attachments: [
                SceneCoreFixtures.attachment(
                    windowRef: try SceneCoreFixtures.windowRef(),
                    slotId: slot.id,
                    ownership: .borrowed,
                ),
            ],
        )
        let file = try fileWithTamperedScene(scene) { json in
            json["state"] = ["ended": [String: Any]()]
        }

        let read = SceneCore.SceneStateFormat.read(file, from: path)

        // An `ended` Scene is a record of a finished task. A borrowed attachment surviving into one would be
        // standing permission to move somebody's window home again, days later, for a task that is over.
        XCTAssertEqual(read.scenes.map(\.state), [.ended])
        XCTAssertEqual(read.scenes.map(\.attachments), [[]])
        guard case .loaded(_, let quarantined) = read else { return XCTFail("Expected a read: \(read)") }
        XCTAssertEqual(quarantined.map(\.reason), [.sceneHasEnded])
    }

    func testAnUnreadableAttachmentIsSetAsideByPathWithoutQuotingWhatWasInIt() throws {
        let slot = SceneCoreFixtures.slot()
        let readable = SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(),
            slotId: slot.id,
        )
        let scene = try SceneCoreFixtures.scene(slots: [slot], attachments: [readable])
        let file = try fileWithTamperedScene(scene) { json in
            let attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
            var broken = try XCTUnwrap(attachments.first)
            broken["slotId"] = 12
            broken["windowRef"] = ["bundleId": "com.example.private-diary", "ordinalWithinApp": 0]
            json["attachments"] = [broken] + attachments
        }

        let read = SceneCore.SceneStateFormat.read(file, from: path)

        XCTAssertEqual(read.scenes.map(\.attachments), [[readable]])
        guard case .loaded(_, let quarantined) = read else { return XCTFail("Expected a read: \(read)") }
        XCTAssertEqual(quarantined.map(\.windowRef), [nil])
        XCTAssertEqual(quarantined.map(\.reason), [.unreadable(at: "scenes[0].attachments[0].slotId")])

        // The diagnostic is the one thing here meant to be read aloud, screenshotted and pasted into an
        // issue. It says *where* the file stopped making sense and never what was written there.
        let diagnostic = try XCTUnwrap(read.diagnostics.first)
        XCTAssertFalse(diagnostic.contains("com.example.private-diary"), diagnostic)
    }
}
