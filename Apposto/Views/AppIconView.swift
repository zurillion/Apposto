import SwiftUI

/// Singola cella: icona dell'app più nome opzionale, con evidenziazione al
/// passaggio del mouse.
struct AppIconView: View {
    let app: AppItem
    let iconSize: Double
    let showLabel: Bool

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
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
    }
}
