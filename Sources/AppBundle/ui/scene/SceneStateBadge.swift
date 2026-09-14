import SwiftUI

/// A Scene's lifecycle state, as a shape.
///
/// Shape rather than colour, and shape rather than opacity: the four states have to be told apart by someone
/// using reduced contrast, in greyscale, and in a screenshot attached to a ticket. The row says the same thing
/// twice more — in its fill and in its trailing text — but this is the part that survives all three.
///
/// The one distinction it exists to protect is `defined, with windows` against `defined, empty`: a filled ring
/// with a hole is "work parked here", an outline is "nothing here", and confusing the two is exactly the
/// mistake that would make leaving a Scene look like losing it.
struct SceneStateBadge: View {
    let badge: SceneCore.SceneShellSceneRow.Badge

    private let diameter: CGFloat = 9

    var body: some View {
        ZStack {
            switch badge {
                case .filled:
                    Circle().fill(Color.white.opacity(GlassToken.textPrimary))
                case .halfFilled:
                    Circle()
                        .fill(Color.white.opacity(GlassToken.textPrimary))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: diameter / 2)
                        }
                    Circle().stroke(Color.white.opacity(GlassToken.textSecondary), lineWidth: StrokeToken.control)
                case .outline:
                    Circle().stroke(Color.white.opacity(GlassToken.textTertiary), lineWidth: StrokeToken.control)
                case .restoring:
                    Circle().fill(Color.white.opacity(GlassToken.textSecondary))
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.white.opacity(GlassToken.textPrimary), lineWidth: StrokeToken.emphasis)
                        .frame(width: diameter + 4, height: diameter + 4)
            }
        }
        .frame(width: diameter, height: diameter)
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
