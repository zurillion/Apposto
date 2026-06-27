import SwiftUI

/// Otto temi colorati selezionabili dalle Preferenze. Il colore del tema viene
/// usato come tinta dell'app (selezione, chip dei tag, pallino, controlli).
enum AppTheme: String, CaseIterable, Identifiable {
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case green
    case teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:   return Color(red: 0.20, green: 0.50, blue: 0.97)
        case .indigo: return Color(red: 0.35, green: 0.34, blue: 0.84)
        case .purple: return Color(red: 0.58, green: 0.31, blue: 0.86)
        case .pink:   return Color(red: 0.92, green: 0.28, blue: 0.60)
        case .red:    return Color(red: 0.89, green: 0.27, blue: 0.24)
        case .orange: return Color(red: 0.96, green: 0.55, blue: 0.13)
        case .green:  return Color(red: 0.22, green: 0.70, blue: 0.36)
        case .teal:   return Color(red: 0.15, green: 0.62, blue: 0.66)
        }
    }

    var displayName: String {
        switch self {
        case .blue:   return "Blu"
        case .indigo: return "Indaco"
        case .purple: return "Viola"
        case .pink:   return "Rosa"
        case .red:    return "Rosso"
        case .orange: return "Arancione"
        case .green:  return "Verde"
        case .teal:   return "Verde acqua"
        }
    }
}
