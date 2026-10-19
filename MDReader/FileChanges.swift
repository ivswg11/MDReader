import Foundation

/// Changes to a file on disk, so an open document can follow edits made in other apps.
nonisolated enum FileChanges {
    /// Yields each time the file at `url` is written. Bursts collapse into one pending event.
    static func stream(for url: URL) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let watcher = Watcher(url: url) { continuation.yield() }
            continuation.onTermination = { _ in watcher.cancel() }
        }
    }
}

/// Watches one path. Most editors save by writing a new file and renaming it over the old one,
/// which leaves the open descriptor on the replaced file, so on delete or rename it reopens the path.
private nonisolated final class Watcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @Sendable () -> Void
    /// All state below is only touched on this queue.
    private let queue = DispatchQueue(label: "FileChanges")
    private var source: DispatchSourceFileSystemObject?
    private var isCancelled = false

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
        queue.async { self.watch() }
    }

    func cancel() {
        queue.async {
            self.isCancelled = true
            self.source?.cancel()
            self.source = nil
        }
    }

    private func watch() {
        guard !isCancelled else { return }
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // Between an editor removing the old file and moving the new one in, the path is empty.
            queue.asyncAfter(deadline: .now() + 0.25) { self.watch() }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler {
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                source.cancel()
                self.source = nil
                self.watch()
            }
            self.onChange()
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }
}
