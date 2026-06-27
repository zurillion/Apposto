import SwiftUI
import AppKit

/// Singola cella: icona dell'app più nome opzionale.
///
/// Interazioni:
/// - clic semplice → avvia l'app;
/// - Shift/⌘ + clic → seleziona/deseleziona (per assegnare tag in blocco);
/// - clic destro (o Ctrl + clic) → apre l'editor dei tag.
struct AppIconView: View {
    @ObservedObject var app: AppItem
    let iconSize: Double
    let showLabel: Bool

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var tagStore: TagStore
    @EnvironmentObject var settings: LauncherSettings

    @State private var hovering = false

    private var isSelected: Bool { model.selectedAppIDs.contains(app.id) }
    private var hasTags: Bool { !tagStore.canonicalTags(for: app.id).isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            iconView
                .frame(width: iconSize, height: iconSize)
                .overlay(alignment: .topTrailing) { tagIndicator }

            if showLabel {
                Text(app.name)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .frame(maxWidth: iconSize + 24)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { hovering = $0 }
        .onTapGesture { handleLeftClick() }
        .overlay(RightClickCatcher { model.openTagEditor(anchor: app) })
        .help(app.name)
        .onAppear(perform: loadIconIfNeeded)
        .popover(isPresented: popoverBinding, arrowEdge: .bottom) {
            TagEditorView(appIDs: model.tagEditorTargetIDs, anchorName: app.name)
                .environmentObject(tagStore)
        }
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor.opacity(0.22) }
        if hovering { return Color.primary.opacity(0.12) }
        return Color.clear
    }

    @ViewBuilder
    private var tagIndicator: some View {
        if settings.showTagIndicator && hasTags {
            let dot = min(max(iconSize * 0.18, 8), 16)
            Circle()
                .fill(Color.accentColor)
                .frame(width: dot, height: dot)
                .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                .offset(x: -2, y: 2)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: iconSize * 0.2)
                .fill(Color.primary.opacity(0.08))
        }
    }

    private var popoverBinding: Binding<Bool> {
        Binding(
            get: { model.tagEditorAnchorID == app.id },
            set: { if !$0 { model.closeTagEditor() } }
        )
    }

    private func handleLeftClick() {
        let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.shift) {
            model.shiftSelect(app.id)
        } else if mods.contains(.command) {
            model.commandSelect(app.id)
        } else if mods.contains(.control) {
            model.openTagEditor(anchor: app)
        } else {
            // Clic semplice: annulla la selezione e avvia l'app.
            model.clearSelection()
            model.launch(app)
        }
    }

    private func loadIconIfNeeded() {
        guard app.icon == nil else { return }
        IconLoader.shared.icon(for: app.url) { [weak app] image in
            app?.icon = image
        }
    }
}
