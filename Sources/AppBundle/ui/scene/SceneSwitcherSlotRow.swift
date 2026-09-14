import SwiftUI

/// One Slot's row, under the Scene it belongs to: which role, what is in it, and how those share the region.
///
/// An empty Slot is a row like any other, dimmed and marked `empty`, never hidden. That is what makes a Slot a
/// plan — *the terminal goes here* — rather than a leftover of something that happened to land somewhere.
///
/// The composition chip is the only control on the row, and it is a button because clicking it is the pointer
/// path the design gives for composing: single → split ⬍ → split ⬌ → tabs. There is no size field, no
/// proportion and no monitor picker here, because a Slot has no geometry to offer.
struct SceneSwitcherSlotRow: View {
    let row: SceneCore.SceneShellSlotRow
    let onCompose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: row.glyph)
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
            Text(row.title)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(row.isEmpty ? GlassToken.textTertiary : GlassToken.textSecondary))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(countText)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
            Button(action: onCompose) {
                Text(row.compositionChip ?? "single")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(GlassToken.fillFaint))
                    }
            }
            .buttonStyle(.plain)
            .help("Compose: single, split ⬍, split ⬌, tabs")
        }
        .padding(.leading, 24)
        .padding(.trailing, 8)
        .frame(height: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    /// `empty`, `1 window`, or `2 windows` — the chip says the rest, so it is not repeated here.
    private var countText: String {
        guard !row.isEmpty else { return "empty" }
        return row.windows.count == 1 ? "1 window" : "\(row.windows.count) windows"
    }
}
