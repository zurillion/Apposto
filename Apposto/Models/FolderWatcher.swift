import Foundation
import CoreServices

/// Osserva una o più cartelle (ricorsivamente) e invoca `onChange` quando il
/// loro contenuto cambia — ad esempio quando si installa o si rimuove un'app.
///
/// Usa FSEvents, che riporta gli eventi dell'intero sottoalbero delle cartelle
/// osservate, così vengono intercettati anche i cambiamenti nelle sottocartelle
/// (es. `/Applications/Utilities`). Gli eventi vengono raggruppati dalla
/// latenza dello stream; il chiamante può comunque applicare un ulteriore
/// debounce.
final class FolderWatcher {
    private let paths: [String]
    private let latency: CFTimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.apposto.FolderWatcher")
    private var stream: FSEventStreamRef?

    init(paths: [String], latency: CFTimeInterval = 1.0, onChange: @escaping () -> Void) {
        self.paths = paths
        self.latency = latency
        self.onChange = onChange
    }

    func start() {
        guard stream == nil, !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.onChange()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            UInt32(kFSEventStreamCreateFlagNoDefer)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
