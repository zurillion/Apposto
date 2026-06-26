import SwiftUI

/// Finestra Preferenze: regola dimensione icone, spaziatura, etichette e
/// colonne, e permette di ricaricare l'elenco delle app.
struct SettingsView: View {
    @EnvironmentObject var settings: LauncherSettings
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Aspetto icone") {
                LabeledSlider(title: "Dimensione", value: $settings.iconSize,
                              range: 32...160, step: 4, unit: "px")
                LabeledSlider(title: "Spaziatura", value: $settings.spacing,
                              range: 0...80, step: 2, unit: "px")
                Toggle("Mostra i nomi", isOn: $settings.showLabels)
            }

            Section("Griglia") {
                Stepper(value: $settings.columnsOverride, in: 0...20) {
                    Text("Colonne: " + (settings.columnsOverride == 0
                                        ? "Auto"
                                        : "\(settings.columnsOverride)"))
                }
                Text("Imposta 0 per adattare automaticamente le colonne alla larghezza della finestra. Le righe per pagina si adattano sempre all'altezza.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Applicazioni") {
                HStack {
                    Text("\(model.apps.count) app trovate")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Ricarica") { model.reload() }
                }
            }

            Section("Scorciatoia") {
                Text("Premi ⌃ ⌥ ⌘ + Spazio per aprire o chiudere Apposto.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460, height: 470)
    }
}

/// Riga "etichetta + slider + valore" riutilizzabile.
private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text("\(Int(value)) \(unit)")
                .monospacedDigit()
                .frame(width: 60, alignment: .trailing)
        }
    }
}
