import Foundation

extension SceneCore {
    /// How a window row learns which application to name.
    ///
    /// A function rather than a lookup the row does itself, because resolving a bundle id to a name is the
    /// desktop's business and this layer has no desktop. The shell passes the real resolver; a test passes a
    /// dictionary, which is what makes the wording below assertable without a Mac.
    typealias ApplicationNaming = @Sendable (String) -> String?

    /// One window's row in a Scene surface: which application, and what the window is *for*.
    ///
    /// It carries no window title — not as a field, not as a fallback, not for sorting. That is invariant I11
    /// held one layer further out than the model: a row that could show a title would eventually show one in a
    /// screenshot attached to a ticket. An application name and its Semantic Home say everything the user
    /// needs, and neither is private.
    ///
    /// The mounted case is spelled out three ways — a glyph, a suffix and a dashed edge — because the one
    /// thing the Phase 1 UI has to prove is that borrowing a window does not change what it is for, and a
    /// distinction carried by opacity alone does not survive greyscale, reduced transparency or a compressed
    /// screenshot.
    struct SceneShellWindowRow: Equatable, Sendable, Identifiable {
        /// The window this row is about. Identity, not display: nothing here is shown to the user.
        let windowRef: WindowRef
        /// The application's name, or its bundle id when the desktop cannot name it.
        let applicationName: String
        /// What the window is for, as the Home rules say — never as its current Scene implies.
        let home: SemanticHome
        /// Whether this window was borrowed into the Scene rather than being part of it.
        let isMounted: Bool

        var id: WindowRef { windowRef }

        /// `Communication`, or `Communication · mounted` for a borrowed window.
        ///
        /// The Home category always comes first and is always present, because it is the thing borrowing must
        /// not change and therefore the thing the row exists to state.
        var trailing: String {
            isMounted ? "\(home.displayName) · mounted" : home.displayName
        }

        /// The borrow glyph, beside the application icon, or nothing.
        var borrowGlyph: String? { isMounted ? "◐" : nil }

        /// A dashed leading edge says "on loan" without any text at all.
        var hasDashedLeadingEdge: Bool { isMounted }

        /// What hovering or focusing a mounted row reveals: in plain words, that this is reversible.
        ///
        /// Only for a mounted row. A window the Scene owns has nothing to reverse, and inventing a sentence
        /// for it would make the borrowed case less noticeable rather than more.
        var reversibility: String? {
            guard isMounted else { return nil }
            return "Borrowed into this Scene. Goes back to \(home.displayName) when the Scene closes."
        }

        /// `"LINE, Communication, mounted"` — the same three facts the row shows, in the same order.
        var accessibilityLabel: String {
            ([applicationName, home.displayName] + (isMounted ? ["mounted"] : [])).joined(separator: ", ")
        }

        init(attachment: Attachment, naming: ApplicationNaming) {
            windowRef = attachment.windowRef
            applicationName = naming(attachment.windowRef.bundleId) ?? attachment.windowRef.bundleId
            home = attachment.homeAtAttachTime
            isMounted = attachment.isMount
        }
    }
}

extension SceneCore.SemanticHome {
    /// The Home category as a person reads it: `Communication`, not `communication`.
    ///
    /// Capitalised here rather than in the domain, because a domain `description` is what diagnostics and
    /// state files are written with and those should not change with a UI decision.
    var displayName: String {
        description.prefix(1).uppercased() + description.dropFirst()
    }
}
