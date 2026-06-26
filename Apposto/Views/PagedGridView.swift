import SwiftUI

/// Griglia di icone suddivisa in pagine.
///
/// Il numero di colonne/righe (e quindi di icone per pagina) è calcolato dallo
/// spazio disponibile, dalla dimensione dell'icona e dalla spaziatura. Le
/// pagine si cambiano con drag, swipe del trackpad (gestito dall'`AppDelegate`)
/// o toccando i pallini in basso.
struct PagedGridView: View {
    let apps: [AppItem]
    let onLaunch: (AppItem) -> Void

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings

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

            let gridColumns = Array(
                repeating: GridItem(.fixed(cellW), spacing: spacing, alignment: .top),
                count: columns
            )

            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { _, pageApps in
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
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
                .offset(x: -CGFloat(page) * geo.size.width)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: page)

                PageIndicator(count: pageCount, current: page) { model.currentPage = $0 }
                    .padding(.bottom, 14)
            }
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
