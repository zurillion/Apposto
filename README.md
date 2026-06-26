# Apposto

Un launcher di applicazioni per macOS ispirato a Launchpad, ma molto più
flessibile. Premi una scorciatoia globale per far comparire una finestra
floating con le icone delle tue app: cerca, ridimensiona la finestra, regola
densità e dimensioni delle icone, sfoglia le pagine con uno swipe.

> ⚠️ Stato: **v1 (base)**. Questa è la prima iterazione: hotkey + finestra
> floating + griglia paginata + ricerca. Le feature successive sono in fondo,
> nella roadmap.

## Funzionalità (v1)

- **Hotkey globale** per mostrare/nascondere il launcher. Default: **⌥ + Spazio**.
- **Finestra floating ridimensionabile** (a differenza di Launchpad).
- **Scansione ricorsiva** delle app in `/Applications`, `/System/Applications`,
  `/System/Library/CoreServices/Applications` e `~/Applications`, comprese le
  sottocartelle (es. *Utilities*). I bundle `.app` sono trattati come foglie.
- **Griglia adattiva**: il numero di icone per pagina dipende da dimensione
  della finestra, dimensione dell'icona e spaziatura — tutto regolabile.
- **Ricerca istantanea** dalla barra in alto (insensibile a maiuscole/accenti);
  premi Invio per avviare il primo risultato.
- **Pagine con indicatore a pallini**; si cambia pagina con swipe del trackpad,
  trascinamento, o cliccando i pallini.
- **App "agent"**: nessuna icona nel Dock, vive nella barra dei menu.

## Requisiti

- **macOS 12 (Monterey) o successivo** (testato come target; funziona su
  macOS 26 *Tahoe* e oltre).
- **Xcode 16 o successivo** per aprire il progetto (usa i *synchronized
  groups*).

## Come compilare ed eseguire

1. Apri `Apposto.xcodeproj` con Xcode.
2. Seleziona lo schema **Apposto** e premi **⌘R**.
3. Al primo avvio l'app non mostra finestre: comparirà solo l'icona nella
   **barra dei menu** (una griglia 3×3). Premi **⌥ + Spazio** per aprire il
   launcher.

> **Firma**: per l'uso locale Xcode firma automaticamente l'app ("Sign to Run
> Locally"), non serve un Apple Developer Team. Per distribuirla, imposta il tuo
> team in *Signing & Capabilities*.

> **Sandbox**: l'app è volutamente **non sandboxed** (come Alfred/Raycast),
> condizione necessaria per enumerare e avviare app arbitrarie.

## Preferenze

Apri le Preferenze dalla voce di menu della barra dei menu, o con **⌘,**:

- **Dimensione icona** e **Spaziatura** (slider).
- **Mostra i nomi** sotto le icone (on/off).
- **Colonne**: `Auto` (si adatta alla larghezza) oppure un numero fisso.
- **Ricarica** l'elenco delle app.

## Architettura

```
Apposto/
├─ AppostoApp.swift            # @main, scena Settings
├─ AppDelegate.swift           # hotkey, status item, monitor ESC/swipe, pannello
├─ Models/
│  ├─ AppItem.swift            # modello di una app (nome, url, icona)
│  ├─ AppScanner.swift         # scansione ricorsiva delle cartelle app
│  ├─ AppModel.swift           # stato condiviso + azioni (reload/launch)
│  └─ LauncherSettings.swift   # impostazioni persistite in UserDefaults
├─ HotKey/
│  └─ HotKeyManager.swift      # RegisterEventHotKey (Carbon), nessun permesso
├─ Window/
│  └─ LauncherWindowController.swift  # NSPanel floating + posizionamento
└─ Views/
   ├─ LauncherRootView.swift   # ricerca + griglia
   ├─ SearchBar.swift
   ├─ PagedGridView.swift      # paginazione + layout adattivo
   ├─ AppIconView.swift
   ├─ PageIndicator.swift      # pallini
   ├─ VisualEffectBackground.swift  # vibrancy
   └─ SettingsView.swift
```

### Note tecniche

- L'**hotkey** usa l'API Carbon `RegisterEventHotKey`: funziona a livello di
  sistema senza richiedere il permesso di Accessibilità.
- Lo **swipe orizzontale** del trackpad è intercettato da un monitor locale
  `NSEvent` (`.scrollWheel`) nell'`AppDelegate`, più affidabile del routing
  degli eventi scroll in SwiftUI.
- Per cambiare la **hotkey** di default modifica la riga in `setupHotKey()`
  (`AppDelegate.swift`), usando i virtual key code di `Carbon.HIToolbox` e le
  maschere `cmdKey`/`optionKey`/`shiftKey`/`controlKey`.

## Roadmap (idee per le prossime iterazioni)

- Hotkey configurabile dalle Preferenze (con "registratore" di scorciatoia).
- Cartelle/gruppi e riordino manuale delle icone (drag & drop).
- Navigazione completa da tastiera (frecce per selezione, Invio per avviare).
- Scansione anche via Spotlight (`NSMetadataQuery`) per trovare app ovunque.
- Aggiornamento live quando si installano/rimuovono app.
- Avvio automatico al login.
- Temi e personalizzazione dello sfondo.
