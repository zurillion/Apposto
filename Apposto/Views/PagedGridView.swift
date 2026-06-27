import SwiftUI

/// Griglia di icone suddivisa in pagine.
///
/// Il numero di colonne/righe (e quindi di icone per pagina) è calcolato dallo
/// spazio disponibile, dalla dimensione dell'icona e dalla spaziatura. Le
/// pagine si cambiano con drag, swipe del trackpad (gestito dall'`AppDelegate`)
/// o toccando i pallini in basso.
///
/// Importante: viene renderizzata SOLO la pagina corrente. Una `LazyVGrid` non
/// dentro uno `ScrollView` materializza tutte le sue celle, quindi disegnare
/// tutte le pagine insieme significherebbe centinaia di icone: ricalcolarle a
/// ogni cambio di dimensione bloccherebbe il thread principale (beachball).
struct PagedGridView: View {
    let apps: [AppItem]
    let onLaunch: (AppItem) -> Void

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings

    /// Pagina precedente, per scegliere la direzione della transizione.
    @State private var lastPage = 0

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 24
            let availW = max(geo.size.width - inset * 2, 1)
            let availH = max(geo.size.height - inset * 2, 1)

            let cellW = settings.iconSize + 28
            let cellH = settings.iconSize + (settings.showLabels ? 34 : 8) + 8
            let spacing = max(settings.spacing, 0)

            let columns = settings.columnsOverride > 0
                ? settings.columnsOverride
                : max(1, Int((availW + spacing) / (cellW + spacing)))
            let rows = max(1, Int((availH + spacing) / (cellH + spacing)))
            let perPage = max(1, columns * rows)

            let pages = paginate(apps, perPage: perPage)
            let pageCount = max(pages.count, 1)
            let page = min(max(model.currentPage, 0), pageCount - 1)
            let forward = page >= lastPage

            let gridColumns = Array(
                repeating: GridItem(.fixed(cellW), spacing: spacing, alignment: .top),
                count: columns
            )

            ZStack(alignment: .bottom) {
                Group {
                    if pages.indices.contains(page) {
                        pageGrid(pages[page], gridColumns: gridColumns, spacing: spacing, inset: inset)
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        Color.clear
                    }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading),
                    removal: .move(edge: forward ? .leading : .trailing)
                ))

                PageIndicator(count: pageCount, current: page) { model.currentPage = $0 }
                    .padding(.bottom, 14)
            }
            .clipped()
            .contentShape(Rectangle())
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: page)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let threshold = max(geo.size.width * 0.15, 40)
                        if value.translation.width < -threshold {
                            model.stepPage(1)
                        } else if value.translation.width > threshold {
                            model.stepPage(-1)
                        }
                    }
            )
            .onAppear {
                model.pageCount = pageCount
                lastPage = page
            }
            .onChange(of: pageCount) { newCount in
                model.pageCount = newCount
                if model.currentPage > newCount - 1 {
                    model.currentPage = max(0, newCount - 1)
                }
            }
            .onChange(of: page) { newPage in
                lastPage = newPage
            }
        }
    }

    @ViewBuilder
    private func pageGrid(_ pageApps: [AppItem],
                          gridColumns: [GridItem],
                          spacing: CGFloat,
                          inset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(pageApps) { app in
                    AppIconView(app: app,
                                iconSize: settings.iconSize,
                                showLabel: settings.showLabels)
                        .onTapGesture { onLaunch(app) }
                }
            }
            .padding(.horizontal, inset)
            Spacer(minLength: 0)
        }
    }

    private func paginate(_ items: [AppItem], perPage: Int) -> [[AppItem]] {
        guard perPage > 0, !items.isEmpty else { return [[]] }
        var result: [[AppItem]] = []
        var index = 0
        while index < items.count {
            result.append(Array(items[index ..< min(index + perPage, items.count)]))
            index += perPage
        }
        return result
    }
}
