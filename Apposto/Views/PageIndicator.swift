import SwiftUI

/// Pallini di paginazione in stile Launchpad. Toccando un pallino si salta
/// direttamente a quella pagina.
struct PageIndicator: View {
    let count: Int
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        if count > 1 {
            HStack(spacing: 9) {
                ForEach(Array(0..<count), id: \.self) { index in
                    Circle()
                        .fill(index == current ? Color.primary.opacity(0.85)
                                                : Color.primary.opacity(0.25))
                        .frame(width: 7, height: 7)
                        .onTapGesture { onSelect(index) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
