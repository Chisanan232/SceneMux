import SwiftUI

/// What closing a Scene will do, grouped by ownership, waiting to be confirmed.
///
/// It shows the model's actual reasoning rather than a generic warning, because ownership is what decides the
/// outcome: a user who can read that two windows go home, four stay put and one is none of SceneMux's business
/// can predict what the button does. *This cannot be undone* teaches them nothing and gets clicked through.
///
/// It is drawn inside the switcher panel rather than as an application-modal sheet. SceneMux must never block
/// the user's other applications to ask itself a question — and the windows being discussed belong to those
/// applications.
struct SceneSwitcherCloseConfirmation: View {
    let summary: SceneCore.SceneShellCloseSummary
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(GlassToken.textPrimary))
            if summary.groups.isEmpty {
                Text("Nothing is in it, so nothing moves.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
            }
            ForEach(summary.groups) { group in
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.headline)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
                    Text(group.windows.map(\.applicationName).joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
                        .lineLimit(2)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                Button(summary.cancelTitle, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(summary.confirmTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
