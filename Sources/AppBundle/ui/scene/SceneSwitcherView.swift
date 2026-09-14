import SwiftUI

let sceneSwitcherWidth: CGFloat = 460
let sceneSwitcherMaxHeight: CGFloat = 460

/// The Scene switcher: the whole of Scene Core in one panel, in three levels — Scene, Slot, window.
///
/// It is the keyboard surface. Typing narrows, `↑`/`↓` move, `⏎` enters, `F2` renames, `⌘⌫` asks to close, and
/// Esc backs out one step at a time. Every one of those is also a pointer path — rows are clickable, the
/// composition chip is a button, the role chips add a Slot — because a design where the mouse is a lesser
/// citizen is not a macOS design.
///
/// Only the selected Scene is expanded. A list that showed every Slot of every Scene would be a wall of rows
/// at exactly the moment the user is trying to find one task among several.
struct SceneSwitcherView: View {
    @ObservedObject var model: SceneSwitcherModel
    @ObservedObject var runtime: SceneCore.SceneRuntime
    /// How a change that can reach the engine is run — the panel's refresh session, and a plain call in a
    /// preview. The pointer paths need it for the same reason the keys do: it is the session that moves the
    /// windows.
    var perform: (@escaping @MainActor () -> Void) -> Void = { body in body() }
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            if case .confirmingClose(_, let summary) = model.mode {
                SceneSwitcherCloseConfirmation(
                    summary: summary,
                    onCancel: model.cancelEditing,
                    onConfirm: { perform { model.confirmClose() } },
                )
            } else {
                field
                separator
                list
                separator
                footer
            }
        }
        .frame(width: sceneSwitcherWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GlassSurface(
                shape: RoundedRectangle(cornerRadius: RadiusToken.panel, style: .continuous),
                style: config.workspaceSidebar.chromeStyle,
                solidColor: config.workspaceSidebar.resolvedSolidChromeColor,
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: RadiusToken.panel, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        HStack {
            Text("SCENES")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
            Spacer()
            Text(runtime.snapshot.menuBarTitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(GlassToken.separatorOpacity))
            .frame(height: StrokeToken.hairline)
    }

    /// One field, and what it is for depends on the mode: finding a task, or naming one.
    @ViewBuilder
    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: model.mode.isEditingText ? "pencil" : "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
            if model.mode.isEditingText {
                TextField("Name this task…", text: $model.nameField)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textPrimary))
                    .focused($fieldFocused)
                    .onSubmit(model.commitName)
            } else {
                TextField("Search scenes…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textPrimary))
                    .focused($fieldFocused)
            }
            if model.mode == .creating {
                ForEach(SceneCore.SlotTemplate.allCases, id: \.self) { template in
                    chip(
                        template.rawValue.capitalized,
                        isOn: model.template == template,
                        action: { model.template = template },
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if model.results.isEmpty {
                    emptyState
                }
                ForEach(Array(model.results.enumerated()), id: \.element.id) { index, row in
                    SceneSwitcherSceneRow(
                        row: row,
                        isSelected: index == model.selection,
                        hotkeyLabel: row.index <= 9 ? "⌃⌥\(row.index)" : nil,
                    )
                    .onTapGesture(count: 2) { model.select(at: index); model.beginRename() }
                    .onTapGesture {
                        model.select(at: index)
                        perform { _ = model.enter(row.id) }
                    }
                    // The pointer path for the two ways out of a Scene. `Close Scene…` opens the
                    // confirmation like every other close path; nothing here moves a window by itself.
                    .contextMenu {
                        Button("Rename…") { model.select(at: index); model.beginRename() }
                        if row.isActive {
                            Button("Leave Scene") { perform { _ = model.leave() } }
                        }
                        Button("Close Scene…") { model.select(at: index); model.beginClose(row.id) }
                    }
                    if index == model.selection {
                        expansion(of: row)
                    }
                }
            }
            .padding(6)
        }
        .frame(maxHeight: sceneSwitcherMaxHeight - 120)
    }

    /// The selected Scene's Slots, its windows, and — when it is on screen and holds nothing — the invitation.
    @ViewBuilder
    private func expansion(of row: SceneCore.SceneShellSceneRow) -> some View {
        ForEach(row.slots) { slot in
            SceneSwitcherSlotRow(row: slot, onCompose: { perform { model.cycleComposition(of: slot.id) } })
                .contextMenu {
                    Button("Remove slot") { perform { model.removeSlot(slot.id) } }
                }
            ForEach(slot.windows) { window in
                SceneSwitcherWindowRow(row: window)
            }
        }
        if let invitation = row.invitation {
            Text(invitation)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(GlassToken.textTertiary))
                .padding(.leading, 24)
                .padding(.vertical, 4)
        }
        if row.isActive {
            HStack(spacing: 4) {
                Text("Add slot")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
                ForEach(SceneCore.SlotRole.allCases, id: \.self) { role in
                    chip(role.rawValue, isOn: false, action: { perform { model.addSlot(role: role) } })
                }
            }
            .padding(.leading, 24)
            .padding(.vertical, 4)
        }
    }

    /// First run says one sentence and the key that starts a task; unreadable state says so instead.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let firstRun = runtime.snapshot.firstRunMessage {
                Text(firstRun)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
            } else if runtime.snapshot.scenes.isEmpty {
                ForEach(runtime.snapshot.diagnostics, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
                }
            } else {
                Text("No scene matches “\(model.query)”. ⏎ names a new one.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: model.beginCreate) {
                Text("+ New Scene")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
            }
            .buttonStyle(.plain)
            Text("⌃⌥N")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.white.opacity(GlassToken.textQuaternary))
            Spacer()
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(GlassToken.textSecondary))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(isOn ? GlassToken.textPrimary : GlassToken.textTertiary))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(isOn ? GlassToken.fillActive : GlassToken.fillFaint))
                }
        }
        .buttonStyle(.plain)
    }
}
