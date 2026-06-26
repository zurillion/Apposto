import SwiftUI

/// Singola cella: icona dell'app più nome opzionale, con evidenziazione al
/// passaggio del mouse. L'icona è caricata pigramente alla comparsa.
struct AppIconView: View {
    @ObservedObject var app: AppItem
    let iconSize: Double
    let showLabel: Bool

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            iconView
                .frame(width: iconSize, height: iconSize)

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
            RoundedRectangle(cornerRadius: 14)
                .fill(hovering ? Color.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { hovering = $0 }
        .help(app.name)
        .onAppear(perform: loadIconIfNeeded)
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            // Segnaposto discreto finché l'icona non è pronta.
            RoundedRectangle(cornerRadius: iconSize * 0.2)
                .fill(Color.primary.opacity(0.08))
        }
    }

    private func loadIconIfNeeded() {
        guard app.icon == nil else { return }
        IconLoader.shared.icon(for: app.url) { [weak app] image in
            app?.icon = image
        }
    }
}
