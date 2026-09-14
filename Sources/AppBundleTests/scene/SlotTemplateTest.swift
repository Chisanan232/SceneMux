@testable import AppBundle
import Foundation
import XCTest

final class SlotTemplateTest: XCTestCase {
    /// The development template is the golden journey's own shape, in the order it is laid out in, and every
    /// Slot it makes is distinct — two Scenes from one template must not share a `SlotId`.
    func testTheDevelopmentTemplateLaysOutTheJourneysRolesWithFreshIdentities() {
        let slots = SceneCore.SlotTemplate.development.slots()

        XCTAssertEqual(slots.map(\.role), [.terminal, .editor, .preview, .observability])
        XCTAssertEqual(slots.map(\.order), [0, 1, 2, 3])
        XCTAssertEqual(slots.map(\.composition), Array(repeating: .single, count: 4))
        XCTAssertEqual(Set(slots.map(\.id)).count, 4)
        XCTAssertNotEqual(slots.map(\.id), SceneCore.SlotTemplate.development.slots().map(\.id))
    }

    func testTheEmptyTemplateCreatesNoSlots() {
        XCTAssertEqual(SceneCore.SlotTemplate.empty.slots(), [])
    }
}
