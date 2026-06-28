import SwiftUI
import AppKit

/// Larghezze condivise tra intestazione e righe della vista elenco.
private enum ListLayout {
    static let arch: CGFloat = 110
    static let version: CGFloat = 78
    static let date: CGFloat = 104
    static let size: CGFloat = 80
    static let update: CGFloat = 26
    static let hInset: CGFloat = 20
    static let rowHeight: CGFloat = 34
}

/// Vista a elenco: intestazione con colonne (le ordinabili sono cliccabili) e
/// righe scorrevoli. Alternativa alla griglia di icone.
struct AppListView: View {
    let apps: [AppItem]

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(apps) { app in
                        AppRowView(app: app)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            sortHeader("Nome", field: .name, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Architettura")
                .frame(width: ListLayout.arch, alignment: .leading)
            Text("Versione")
                .frame(width: ListLayout.version, alignment: .leading)
            sortHeader("Aggiunta", field: .dateAdded, alignment: .leading)
                .frame(width: ListLayout.date, alignment: .leading)
            sortHeader("Dimensione", field: .size, alignment: .trailing)
                .frame(width: ListLayout.size, alignment: .trailing)
            // Spaziatore allineato alla colonna del badge update (altezza
            // vincolata: altrimenti Color.clear si espande in verticale).
            Color.clear.frame(width: ListLayout.update, height: 1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, ListLayout.hInset)
        .padding(.vertical, 6)
    }

    private func sortHeader(_ title: String, field: SortField,
                            alignment: HorizontalAlignment) -> some View {
        Button {
            if settings.sortField == field {
                settings.sortAscending.toggle()
            } else {
                settings.sortField = field
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if settings.sortField == field {
                    Image(systemName: settings.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(settings.sortField == field ? settings.theme.color : Color.secondary)
    }
}

/// Singola riga dell'elenco. Stesse interazioni della cella a icona: clic =
/// avvia, ⇧/⌘ + clic = selezione, clic destro/Ctrl = editor dei tag, hover per
/// ⌘R/⌘I.
struct AppRowView: View {
    @ObservedObject var app: AppItem

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings
    @EnvironmentObject var tagStore: TagStore

    @State private var hovering = false

    private var isSelected: Bool { model.selectedAppIDs.contains(app.id) }
    private var hasTags: Bool { !tagStore.canonicalTags(for: app.id).isEmpty }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                iconView
                Text(app.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if settings.showTagIndicator && hasTags {
                    Circle().fill(settings.theme.color).frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(app.architecture.label)
                .foregroundStyle(.secondary)
                .frame(width: ListLayout.arch, alignment: .leading)

            Text(app.version ?? "—")
                .foregroundStyle(.secondary)
                .frame(width: ListLayout.version, alignment: .leading)

            Text(dateText)
                .foregroundStyle(.secondary)
                .frame(width: ListLayout.date, alignment: .leading)

            Text(sizeText)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: ListLayout.size, alignment: .trailing)

            updateBadge
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .padding(.horizontal, ListLayout.hInset)
        .frame(height: ListLayout.rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
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
        .popover(isPresented: popoverBinding, arrowEdge: .leading) {
            TagEditorView(appIDs: model.tagEditorTargetIDs, anchorName: app.name)
                .environmentObject(tagStore)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 22, height: 22)
        }
    }

    /// Cella del badge update: larghezza sempre riservata (Color.clear di base),
    /// badge centrato sopra quando c'è un aggiornamento.
    private var updateBadge: some View {
        ZStack {
            Color.clear
            if let info = model.updatesByID[app.id] {
                let color: Color = info.source == "App Store" ? .blue : .green
                Image(systemName: "arrow.up.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, color)
                    .font(.system(size: 14))
                    .help("Aggiornamento disponibile: \(info.latestVersion) (\(info.source))")
            }
        }
        .frame(width: ListLayout.update, height: ListLayout.rowHeight)
    }

    private var rowBackground: some View {
        let color: Color = isSelected ? settings.theme.color.opacity(0.20)
            : hovering ? Color.primary.opacity(0.08)
            : Color.clear
        return Rectangle().fill(color)
    }

    private var dateText: String {
        guard let date = app.dateAdded else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    private var sizeText: String {
        guard let bytes = model.sizesByID[app.id] else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
