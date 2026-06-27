import SwiftUI

/// Finestra Preferenze: tema, scorciatoia, Dock, aspetto della griglia,
/// sinonimi dei tag e ricarica dell'elenco app.
struct SettingsView: View {
    @EnvironmentObject var settings: LauncherSettings
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var tagStore: TagStore

    var body: some View {
        Form {
            Section("Tema") {
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        Circle()
                            .fill(theme.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .opacity(settings.theme == theme ? 1 : 0)
                            )
                            .overlay(
                                Circle().strokeBorder(.primary,
                                                      lineWidth: settings.theme == theme ? 2 : 0)
                            )
                            .onTapGesture { settings.theme = theme }
                            .help(theme.displayName)
                    }
                    Spacer(minLength: 0)
                }
            }

            Section("Generale") {
                Toggle("Mostra icona nel Dock", isOn: $settings.showInDock)
                Toggle("Pallino sulle app con tag", isOn: $settings.showTagIndicator)
            }

            Section("Scorciatoia") {
                HStack {
                    Text("Apri / chiudi Apposto")
                    Spacer()
                    ShortcutRecorder(keyCode: $settings.hotKeyCode,
                                     carbonModifiers: $settings.hotKeyModifiers)
                    Button("Ripristina") { settings.resetHotKey() }
                }
                Text("Clicca il pulsante e premi la nuova combinazione (servono uno o più tasti ⌃ ⌥ ⇧ ⌘). Esc per annullare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

            Section("Sinonimi") {
                Text("Aggiungendo un tag di un gruppo, gli altri vengono assegnati alle stesse app (e rimossi insieme). Separa i tag con la virgola.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach($tagStore.synonymGroups) { $group in
                    HStack {
                        TextField("es. Programmazione, Sviluppo, Development", text: $group.text)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            tagStore.removeSynonymGroup(group.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Rimuovi gruppo")
                    }
                }
                Button {
                    tagStore.addSynonymGroup()
                } label: {
                    Label("Aggiungi gruppo", systemImage: "plus")
                }
            }

            Section("Applicazioni") {
                HStack {
                    Text("\(model.apps.count) app trovate")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Ricarica") { model.reload() }
                }
            }
        }
        .tint(settings.theme.color)
        .padding(20)
        .frame(width: 480, height: 640)
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
