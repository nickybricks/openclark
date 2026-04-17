import Foundation

/// Überwacht Ordner via FSEvents und Polling-Fallback.
final class FileWatcher: @unchecked Sendable {

    private var streams: [FSEventStreamRef] = []
    private var pollTimer: Timer?
    private let config: AppConfig
    private let onNewFile: @Sendable (String) -> Void

    init(config: AppConfig, onNewFile: @escaping @Sendable (String) -> Void) {
        self.config = config
        self.onNewFile = onNewFile
    }

    deinit {
        stop()
    }

    // MARK: - Start / Stop

    func start() {
        let directories = config.config.watchedDirectories.map { path -> String in
            (path as NSString).expandingTildeInPath
        }

        for dir in directories {
            guard FileManager.default.fileExists(atPath: dir) else { continue }
            startFSEventStream(for: dir)
        }

        // Polling-Fallback starten
        let interval = TimeInterval(config.config.pollInterval)
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.pollForNewFiles()
            }
        }
    }

    func stop() {
        for stream in streams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        streams.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - FSEvents

    private func startFSEventStream(for path: String) {
        let pathsToWatch = [path] as CFArray

        // Callback mit Kontext
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            for i in 0..<numEvents {
                let flags = eventFlags[i]
                let path = paths[i]

                // Nur Created und Renamed/Moved Events
                let isCreated = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
                let isRenamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0
                let isFile = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0

                if isFile && (isCreated || isRenamed) {
                    watcher.onNewFile(path)
                }
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latenz in Sekunden
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        streams.append(stream)
    }

    // MARK: - Polling Fallback

    private func pollForNewFiles() {
        let fm = FileManager.default
        let directories = config.config.watchedDirectories.map { ($0 as NSString).expandingTildeInPath }
        let recursive = config.config.recursive

        for dir in directories {
            guard fm.fileExists(atPath: dir) else { continue }
            pollDirectory(dir, recursive: recursive)
        }
    }

    private func pollDirectory(_ path: String, recursive: Bool) {
        let fm = FileManager.default
        let excludedDirs = FileFilters.effectiveExcludedDirectories()

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        ) else { return }

        for case let fileURL as URL in enumerator {
            // Ordner-Ausschlüsse (inkl. versteckte Ordner — muss mit SnapshotManager übereinstimmen)
            if let isDir = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                if excludedDirs.contains(fileURL.lastPathComponent) || fileURL.lastPathComponent.hasPrefix(".") {
                    enumerator.skipDescendants()
                }
                continue
            }

            onNewFile(fileURL.path)
        }
    }
}
