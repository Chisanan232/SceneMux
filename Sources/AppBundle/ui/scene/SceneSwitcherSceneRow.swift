import SwiftUI

/// One Scene's row in the switcher: which task, where it is in its life, and how big it is.
///
/// Three signals for one fact, on purpose. The badge carries the state as a shape, the fill carries it as
/// weight, and the trailing text says it in words — `active`, `6 windows`, `empty`, `restoring…`. Any one of
/// them can be lost to a display setting or a compressed screenshot without the row becoming ambiguous.
///
/// The number on the right is the key that enters this Scene, shown only while it is a key that exists: nine
/// numbers, however many Scenes the user has.
struct SceneSwitcherSceneRow: View {
    let row: SceneCore.SceneShellSceneRow
    let isSelected: Bool
    let hotkeyLabel: String?

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.accentColor.opacity(row.showsAccentBar ? 0.9 : 0))
                .frame(width: 2, height: 18)
                .clipShape(Capsule())
            SceneStateBadge(badge: row.badge)
            Text(row.title)
                .font(.system(size: 13, weight: isSelected || row.isActive ? .semibold : .regular))
                .foregroundStyle(Color.white.opacity(titleOpacity))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(row.trailing)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
            if let hotkeyLabel {
                Text(hotkeyLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(GlassToken.fillFaint))
                    }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background {
            RoundedRectangle(cornerRadius: RadiusToken.row, style: .continuous)
                .fill(Color.white.opacity(isSelected ? GlassToken.fillActive : fillOpacity))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var titleOpacity: Double {
        switch row.titleEmphasis {
            case .primary: GlassToken.textPrimary
            case .secondary: GlassToken.textSecondary
        }
    }

    private var fillOpacity: Double {
        switch row.fill {
            case .active: GlassToken.fillActive
            case .resting: GlassToken.fillResting
            case .faint: GlassToken.fillFaint
        }
    }
}
