import SwiftUI

/// Griglia di icone suddivisa in pagine.
///
/// Il numero di colonne/righe (e quindi di icone per pagina) è calcolato dallo
/// spazio disponibile, dalla dimensione dell'icona e dalla spaziatura. Le
/// pagine si cambiano con drag, swipe del trackpad (gestito dall'`AppDelegate`)
/// o toccando i pallini in basso.
///
/// Lo scorrimento è realizzato con un `HStack` traslato (`offset`), che anima
/// in modo affidabile. Per non disegnare centinaia di icone insieme (una
/// `LazyVGrid` fuori da uno `ScrollView` materializza tutte le celle) vengono
/// renderizzate solo la **pagina corrente e le due adiacenti**: abbastanza per
/// uno swipe fluido, ma poche da non rallentare il ridimensionamento delle
/// icone.
struct PagedGridView: View {
    let apps: [AppItem]
    let onLaunch: (AppItem) -> Void

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 24
            let topPadding: CGFloat = 20
            let bottomReserve: CGFloat = 44   // spazio per i pallini di pagina
            let availW = max(geo.size.width - inset * 2, 1)
            // Le righe per pagina si calcolano sull'area utile (sotto la barra
            // di ricerca, sopra i pallini), così le icone allineate in alto non
            // finiscono sotto l'indicatore di pagina.
            let availH = max(geo.size.height - topPadding - bottomReserve, 1)

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

            let gridColumns = Array(
                repeating: GridItem(.fixed(cellW), spacing: spacing, alignment: .top),
                count: columns
            )

            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(Array(pages.indices), id: \.self) { i in
                        Group {
                            if abs(i - page) <= 1 {
                                pageGrid(pages[i],
                                         gridColumns: gridColumns,
                                         spacing: spacing,
                                         inset: inset,
                                         topPadding: topPadding)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
                .offset(x: -CGFloat(page) * geo.size.width)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: page)

                PageIndicator(count: pageCount, current: page) { model.currentPage = $0 }
                    .padding(.bottom, 14)
            }
            .clipped()
            .contentShape(Rectangle())
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
            .onAppear { model.pageCount = pageCount }
            .onChange(of: pageCount) { newCount in
                model.pageCount = newCount
                if model.currentPage > newCount - 1 {
                    model.currentPage = max(0, newCount - 1)
                }
            }
        }
    }

    @ViewBuilder
    private func pageGrid(_ pageApps: [AppItem],
                          gridColumns: [GridItem],
                          spacing: CGFloat,
                          inset: CGFloat,
                          topPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(pageApps) { app in
                    AppIconView(app: app,
                                iconSize: settings.iconSize,
                                showLabel: settings.showLabels)
                        .onTapGesture { onLaunch(app) }
                }
            }
            .padding(.horizontal, inset)
            .padding(.top, topPadding)
            // Le icone restano in alto: lo Spacer riempie lo spazio sotto.
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
