import SwiftUI

/// Finestra Preferenze organizzata in tab.
struct SettingsView: View {
    @EnvironmentObject var settings: LauncherSettings

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("Generale", systemImage: "gearshape") }
            AppearanceSettingsTab()
                .tabItem { Label("Aspetto", systemImage: "square.grid.2x2") }
            SynonymsSettingsTab()
                .tabItem { Label("Sinonimi", systemImage: "tag") }
        }
        .tint(settings.theme.color)
        .frame(width: 480, height: 520)
    }
}

// MARK: - Tab Generale

private struct GeneralSettingsTab: View {
    @EnvironmentObject var settings: LauncherSettings
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Tema") {
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        themeSwatch(theme)
                    }
                    Spacer(minLength: 0)
                }
            }

            Section("Generale") {
                Toggle("Mostra icona nel Dock", isOn: $settings.showInDock)
                Toggle("Pallino sulle app con tag", isOn: $settings.showTagIndicator)
                Toggle("Badge \"Intel\" sulle app solo-Intel", isOn: $settings.showIntelBadge)
            }

            Section("Scorciatoia") {
                HStack {
                    Text("Apri / chiudi")
                    Spacer()
                    ShortcutRecorder(keyCode: $settings.hotKeyCode,
                                     carbonModifiers: $settings.hotKeyModifiers)
                    Button("Ripristina") { settings.resetHotKey() }
                }
                Text("Clicca il pulsante e premi la combinazione (servono uno o più tasti ⌃ ⌥ ⇧ ⌘). Esc per annullare.")
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
                Text("⌘R mostra l'app nel Finder, ⌘I ne apre le Informazioni (per l'app sotto il puntatore).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Aggiornamenti") {
                Toggle("Controlla aggiornamenti (Sparkle e App Store)", isOn: $settings.checkForUpdates)
                if settings.checkForUpdates {
                    HStack {
                        Spacer()
                        Button("Controlla ora") { model.refreshUpdates(force: true) }
                    }
                }
                Text("Opt-in: contatta i feed Sparkle delle app e l'API del Mac App Store; un badge segnala le app aggiornabili. Le app di sistema o senza canale di aggiornamento non vengono controllate. Esito in cache per 24 ore.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private func themeSwatch(_ theme: AppTheme) -> some View {
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
                Circle().strokeBorder(.primary, lineWidth: settings.theme == theme ? 2 : 0)
            )
            .onTapGesture { settings.theme = theme }
            .help(theme.displayName)
    }
}

// MARK: - Tab Aspetto

private struct AppearanceSettingsTab: View {
    @EnvironmentObject var settings: LauncherSettings

    var body: some View {
        Form {
            Section("Aspetto icone") {
                LabeledSlider(title: "Dimensione", value: $settings.iconSize,
                              range: 32...160, step: 4, unit: "px")
                LabeledSlider(title: "Spaziatura", value: $settings.spacing,
                              range: 0...80, step: 2, unit: "px")
                Toggle("Mostra i nomi", isOn: $settings.showLabels)
                Toggle("Mostra anche i nomi originali", isOn: $settings.showOriginalName)
                    .disabled(!settings.showLabels)
                Text("Sotto al nome localizzato mostra il nome originale (non tradotto), in grigio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Mostra la versione", isOn: $settings.showVersion)
                    .disabled(!settings.showLabels)
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
        }
        .padding(20)
    }
}

// MARK: - Tab Sinonimi

private struct SynonymsSettingsTab: View {
    @EnvironmentObject var tagStore: TagStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aggiungendo a un'app un tag di un gruppo, gli altri vengono assegnati alle stesse app (e rimossi insieme). Separa i tag con la virgola.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($tagStore.synonymGroups) { $group in
                        HStack(spacing: 8) {
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

                    if tagStore.synonymGroups.isEmpty {
                        Text("Nessun gruppo di sinonimi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                tagStore.addSynonymGroup()
            } label: {
                Label("Aggiungi gruppo", systemImage: "plus")
            }

            Spacer(minLength: 0)
        }
        .padding(20)
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
