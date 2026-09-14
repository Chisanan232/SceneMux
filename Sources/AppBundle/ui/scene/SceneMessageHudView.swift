import SwiftUI

/// One line about what SceneMux just did to someone's windows.
///
/// Small, one message at a time, and in the user's vocabulary: *what happened to which windows*. The details
/// disclosure exists for exactly one case — state that could not be read — because a file path in a
/// two-and-a-half-second toast is unreadable in the other sense of the word.
///
/// There is deliberately no progress bar and no spinner. A Scene that is restoring says `restoring…` in its
/// own row; a modal progress window over another application's window being moved would block the user out of
/// the very thing being moved.
struct SceneMessageHudView: View {
    let message: SceneCore.SceneShellMessage
    let onDismiss: () -> Void
    @State private var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: message.showsDetails ? "exclamationmark.triangle" : "rectangle.3.group")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
                Text(message.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textPrimary))
                    .lineLimit(2)
                if message.showsDetails {
                    Button(showsDetails ? "Hide details" : "Show details") { showsDetails.toggle() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
                }
            }
            if showsDetails, let details = message.details {
                Text(details)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GlassSurface(
                shape: RoundedRectangle(cornerRadius: RadiusToken.section, style: .continuous),
                style: config.workspaceSidebar.chromeStyle,
                solidColor: config.workspaceSidebar.resolvedSolidChromeColor,
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.section, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.text)
    }
}
