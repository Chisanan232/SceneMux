import SwiftUI

/// One window's row, under the Slot it is in: which application, and what the window is *for*.
///
/// It shows no window title. Not as a fallback, not on hover, not in the accessibility label — `AGENTS.md`
/// forbids logging window contents, and a sidebar full of window titles in a screenshot attached to a ticket
/// is a leak of the user's work. The application's name and its Semantic Home say everything needed, and
/// neither is private.
///
/// A borrowed window is marked three ways — a dashed leading edge, a `◐` glyph and the `· mounted` suffix —
/// because the one thing this UI has to prove is that borrowing a window does not change what it is for, and a
/// distinction carried by opacity alone does not survive greyscale.
struct SceneSwitcherWindowRow: View {
    let row: SceneCore.SceneShellWindowRow

    var body: some View {
        HStack(spacing: 6) {
            if let icon = appIconImage(bundleIdentifier: row.windowRef.bundleId, bundlePath: nil) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 10))
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
            }
            if let borrowGlyph = row.borrowGlyph {
                Text(borrowGlyph)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
            }
            Text(row.applicationName)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(row.trailing)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
        }
        .padding(.leading, 44)
        .padding(.trailing, 8)
        .frame(height: 20)
        .overlay(alignment: .leading) {
            if row.hasDashedLeadingEdge {
                Path { path in
                    path.addLines([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 14)])
                }
                .stroke(
                    Color.white.opacity(GlassToken.textQuaternary),
                    style: StrokeStyle(lineWidth: StrokeToken.emphasis, dash: [2, 2]),
                )
                .frame(width: StrokeToken.emphasis, height: 14)
                .padding(.leading, 36)
            }
        }
        .contentShape(Rectangle())
        .help(row.reversibility ?? "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}
