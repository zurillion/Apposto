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
                .overlay(alignment: .bottom) { intelBadge }

            if showLabel {
                VStack(spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .truncationMode(.tail)

                    if settings.showOriginalName, let original = app.originalName {
                        Text(original)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
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
                .strokeBorder(settings.theme.color, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { inside in
            hovering = inside
            if inside {
                model.hoveredAppID = app.id
            } else if model.hoveredAppID == app.id {
                model.hoveredAppID = nil
            }
        }
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
        if isSelected { return settings.theme.color.opacity(0.22) }
        if hovering { return Color.primary.opacity(0.12) }
        return Color.clear
    }

    @ViewBuilder
    private var tagIndicator: some View {
        if settings.showTagIndicator && hasTags {
            let dot = min(max(iconSize * 0.18, 8), 16)
            Circle()
                .fill(settings.theme.color)
                .frame(width: dot, height: dot)
                .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                .offset(x: -2, y: 2)
        }
    }

    @ViewBuilder
    private var intelBadge: some View {
        if settings.showIntelBadge && app.isIntelOnly {
            Text("Intel")
                .font(.system(size: min(max(iconSize * 0.16, 8), 11), weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                .offset(y: -4)
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
