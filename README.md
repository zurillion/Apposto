# Apposto

Un launcher di applicazioni per macOS ispirato a Launchpad, ma molto più
flessibile. Premi una scorciatoia globale per far comparire una finestra
floating con le icone delle tue app: cerca, ridimensiona la finestra, regola
densità e dimensioni delle icone, sfoglia le pagine con uno swipe.

> ⚠️ Stato: **v1 (base)**. Questa è la prima iterazione: hotkey + finestra
> floating + griglia paginata + ricerca. Le feature successive sono in fondo,
> nella roadmap.

## Funzionalità (v1)

- **Hotkey globale** per mostrare/nascondere il launcher. Default: **⌃⌥⌘ + Spazio**
  (Ctrl + Opzione + Cmd + Spazio).
- **Finestra floating ridimensionabile** (a differenza di Launchpad).
- **Scansione ricorsiva** delle app in `/Applications`, `/System/Applications`,
  `/System/Library/CoreServices/Applications` e `~/Applications`, comprese le
  sottocartelle (es. *Utilities*). I bundle `.app` sono trattati come foglie.
- **Griglia adattiva**: il numero di icone per pagina dipende da dimensione
  della finestra, dimensione dell'icona e spaziatura — tutto regolabile.
- **Ordinamento** (barra in cima) per **nome**, **dimensione** o **data di
  aggiunta**, in entrambe le direzioni. La dimensione dei bundle è calcolata in
  background e messa in cache.
- **Ricerca istantanea** dalla barra in alto (insensibile a maiuscole/accenti);
  premi Invio per avviare il primo risultato.
- **Pagine con indicatore a pallini**; si cambia pagina con swipe del trackpad,
  trascinamento, frecce **← →**, o cliccando i pallini.
- **App "agent"**: nessuna icona nel Dock, vive nella barra dei menu.

### Tag (Fase 1)

- **Database tag persistente** associato alle app (per *bundle id*), salvato in
  `~/Library/Application Support/Apposto/tags.json`. I tag sono
  case-insensitive e possono contenere spazi.
- **Clic destro** (o Ctrl+clic) su un'app → finestra per vedere/aggiungere
  (esistente o nuovo, con suggerimenti) / rimuovere i tag. Mentre scrivi,
  **Tab** completa il tag fino al punto non ambiguo (tutto, se il match è unico).
- **Selezione multipla** (celle evidenziate): **⌘ + clic** aggiunge/toglie la
  singola app, **Shift + clic** seleziona l'intervallo dalla prima selezionata
  fino alla cella cliccata. Un clic semplice (su un'icona o nel vuoto) annulla
  la selezione. Il clic destro su una app selezionata mostra i tag **comuni** e
  li aggiunge/rimuove a tutte.
- **Ricerca per tag** con `#tag`, combinabile col nome dell'app e con più tag in
  qualunque posizione: `#tag1 nome app #tag2`.
- **Indicatore tag**: un pallino sull'icona segnala le app che hanno almeno un
  tag (attivo di default; disattivabile dalle Preferenze).

> Fase 2 (in arrivo): completamento dei tag con **Tab** e tag completati
> mostrati come **ovali colorati** (chip) nel campo di ricerca.

## Requisiti

- **macOS 12 (Monterey) o successivo** (testato come target; funziona su
  macOS 26 *Tahoe* e oltre).
- **Xcode 16 o successivo** per aprire il progetto (usa i *synchronized
  groups*).

## Come compilare ed eseguire

1. Apri `Apposto.xcodeproj` con Xcode.
2. Seleziona lo schema **Apposto** e premi **⌘R**.
3. All'avvio compaiono l'**icona nel Dock** (disattivabile dalle Preferenze) e
   quella nella **barra dei menu** (una griglia 3×3); il launcher si apre
   subito. Da quel momento usi **⌃⌥⌘ + Spazio** (scorciatoia di default,
   modificabile dalle Preferenze) per mostrarlo/nasconderlo, oppure clicchi
   l'icona nel Dock.

> **Firma**: per l'uso locale Xcode firma automaticamente l'app ("Sign to Run
> Locally"), non serve un Apple Developer Team. Per distribuirla, imposta il tuo
> team in *Signing & Capabilities*.

> **Sandbox**: l'app è volutamente **non sandboxed** (come Alfred/Raycast),
> condizione necessaria per enumerare e avviare app arbitrarie.

## Preferenze

Apri le Preferenze dalla voce di menu della barra dei menu, o con **⌘,**:

- **Mostra icona nel Dock** (attiva di default).
- **Pallino sulle app con tag** (attivo di default).
- **Scorciatoia**: clicca il pulsante e premi la nuova combinazione (serve
  almeno un modificatore ⌃ ⌥ ⇧ ⌘; Esc annulla; "Ripristina" torna al default).
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
│  ├─ AppItem.swift            # modello di una app (icona caricata pigramente)
│  ├─ AppScanner.swift         # scansione ricorsiva (solo metadati)
│  ├─ AppCache.swift           # cache su disco dei metadati (avvio istantaneo)
│  ├─ IconLoader.swift         # caricamento icone asincrono + cache in memoria
│  ├─ AppModel.swift           # stato condiviso + azioni (reload/launch/selezione)
│  ├─ LauncherSettings.swift   # impostazioni persistite in UserDefaults
│  ├─ TagStore.swift           # database tag persistente (Application Support)
│  ├─ SearchQuery.swift        # parsing ricerca con #tag + nome app
│  └─ BundleSize.swift         # dimensione bundle (ricorsiva) + cache
├─ HotKey/
│  └─ HotKeyManager.swift      # RegisterEventHotKey (Carbon), nessun permesso
├─ Window/
│  └─ LauncherWindowController.swift  # NSPanel floating + posizionamento
└─ Views/
   ├─ LauncherRootView.swift   # ricerca + griglia
   ├─ SearchBar.swift
   ├─ PagedGridView.swift      # paginazione + layout adattivo
   ├─ AppIconView.swift        # cella: clic/selezione/clic destro + popover tag
   ├─ PageIndicator.swift      # pallini
   ├─ VisualEffectBackground.swift  # vibrancy
   ├─ ShortcutRecorder.swift   # registratore di scorciatoia + formatter
   ├─ RightClickCatcher.swift  # intercetta solo il clic destro
   ├─ TagEditorView.swift      # popover per gestire i tag
   ├─ TagInputField.swift      # campo tag con completamento via Tab
   └─ SettingsView.swift
```

### Note tecniche

- L'**hotkey** usa l'API Carbon `RegisterEventHotKey`: funziona a livello di
  sistema senza richiedere il permesso di Accessibilità.
- Lo **swipe orizzontale** del trackpad è intercettato da un monitor locale
  `NSEvent` (`.scrollWheel`) nell'`AppDelegate`, più affidabile del routing
  degli eventi scroll in SwiftUI.
- La **scorciatoia** è configurabile dalle Preferenze tramite `ShortcutRecorder`
  e persistita in `LauncherSettings`; l'`AppDelegate` la (ri)registra in modo
  reattivo via Combine.
- La **visibilità nel Dock** è gestita a runtime con
  `NSApp.setActivationPolicy(.regular/.accessory)` in base all'impostazione.
- **Caricamento app**: la scansione produce solo metadati (veloce, in
  background) e li salva in cache su disco, così all'avvio la lista compare
  subito mentre una nuova scansione la aggiorna. Le **icone** sono caricate
  pigramente e in modo asincrono (`IconLoader`), per non bloccare l'interfaccia.
  La griglia renderizza solo la **pagina corrente e le due adiacenti** (una
  `LazyVGrid` fuori da uno `ScrollView` materializza tutte le celle): poche
  icone da ricalcolare al cambio dimensione, ma abbastanza per uno swipe fluido.
- **Preferenze**: il launcher resta visibile sotto la finestra Preferenze
  (livello abbassato a `.normal`) e si aggiorna in tempo reale; l'auto-hide
  scatta solo quando si passa a un'altra app (`applicationDidResignActive`).

## Roadmap (idee per le prossime iterazioni)

- **Tag — Fase 2**: campo di ricerca con completamento dei tag tramite **Tab**
  (tag intero se non ambiguo, prefisso comune se ambiguo) e tag completati
  mostrati come **ovali colorati** (chip) inline.
- Opzione per normalizzare la direzione dello swipe del trackpad in base alla
  preferenza di sistema "scorrimento naturale" (oggi si segue sempre quella
  di sistema; il trascinamento col mouse usa invece la direzione fisica).
- Cartelle/gruppi e riordino manuale delle icone (drag & drop).
- Navigazione completa da tastiera: selezione cella con le frecce ↑↓ (le frecce
  ← → cambiano già pagina) e avvio con Invio della cella selezionata.
- Scansione anche via Spotlight (`NSMetadataQuery`) per trovare app ovunque.
- Aggiornamento live quando si installano/rimuovono app.
- Avvio automatico al login.
- Temi e personalizzazione dello sfondo.
