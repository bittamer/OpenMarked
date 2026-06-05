import Dispatch
import Foundation

#if canImport(Darwin)
import Darwin
#endif

public struct FileWatchEvent: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case changed
        case deleted
        case replaced
        case permissionChanged
    }

    public let url: URL
    public let kind: Kind
    public let occurredAt: Date

    public init(url: URL, kind: Kind, occurredAt: Date = Date()) {
        self.url = url
        self.kind = kind
        self.occurredAt = occurredAt
    }
}

public final class FileSystemWatcher {
    public typealias EventHandler = @Sendable (FileWatchEvent) -> Void

    private let url: URL
    private let debounceInterval: TimeInterval
    private let callbackQueue: DispatchQueue
    private let handler: EventHandler
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<UUID>()
    private let queueID = UUID()

    private var fileSource: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private var pendingWorkItem: DispatchWorkItem?
    private var lastSnapshot: WatchedFileSnapshot
    private var isWatching = false

    public init(
        url: URL,
        debounceInterval: TimeInterval = 0.25,
        callbackQueue: DispatchQueue = .main,
        handler: @escaping EventHandler
    ) {
        self.url = url.standardizedFileURL
        self.debounceInterval = debounceInterval
        self.callbackQueue = callbackQueue
        self.handler = handler
        self.queue = DispatchQueue(label: "org.openmarked.file-watcher.\(UUID().uuidString)")
        self.lastSnapshot = WatchedFileSnapshot.read(url: url.standardizedFileURL)
        self.queue.setSpecific(key: queueKey, value: queueID)
    }

    deinit {
        stop()
    }

    public func start() {
        performOnQueue {
            guard !isWatching else {
                return
            }

            isWatching = true
            lastSnapshot = WatchedFileSnapshot.read(url: url)
            startDirectorySourceLocked()
            startFileSourceLocked()
        }
    }

    public func stop() {
        performOnQueue {
            stopLocked()
        }
    }

    private func performOnQueue(_ operation: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) == queueID {
            operation()
        } else {
            queue.sync(execute: operation)
        }
    }

    private func startDirectorySourceLocked() {
        guard directorySource == nil else {
            return
        }

        let directoryURL = url.deletingLastPathComponent()
        let descriptor = openEventOnlyDescriptor(path: directoryURL.path)
        guard descriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleDirectoryEventLocked()
        }
        source.setCancelHandler {
            close(descriptor)
        }

        directorySource = source
        source.resume()
    }

    private func startFileSourceLocked() {
        guard fileSource == nil else {
            return
        }

        let descriptor = openEventOnlyDescriptor(path: url.path)
        guard descriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self, weak source] in
            guard let source else {
                return
            }
            self?.handleFileEventLocked(source.data)
        }
        source.setCancelHandler {
            close(descriptor)
        }

        fileSource = source
        source.resume()
    }

    private func stopFileSourceLocked() {
        fileSource?.cancel()
        fileSource = nil
    }

    private func stopLocked() {
        guard isWatching else {
            return
        }

        isWatching = false
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        stopFileSourceLocked()
        directorySource?.cancel()
        directorySource = nil
    }

    private func handleFileEventLocked(_ flags: DispatchSource.FileSystemEvent) {
        let newSnapshot = WatchedFileSnapshot.read(url: url)
        defer {
            lastSnapshot = newSnapshot
        }

        if flags.contains(.revoke) {
            scheduleLocked(kind: .permissionChanged)
            return
        }

        if flags.contains(.delete) || flags.contains(.rename) || !newSnapshot.exists {
            stopFileSourceLocked()
            scheduleLocked(kind: .deleted)
            return
        }

        scheduleLocked(kind: newSnapshot.identity == lastSnapshot.identity ? .changed : .replaced)
    }

    private func handleDirectoryEventLocked() {
        let newSnapshot = WatchedFileSnapshot.read(url: url)
        let previousSnapshot = lastSnapshot
        defer {
            lastSnapshot = newSnapshot
        }

        guard newSnapshot != previousSnapshot else {
            return
        }

        if newSnapshot.exists {
            if fileSource == nil || newSnapshot.identity != previousSnapshot.identity {
                stopFileSourceLocked()
                startFileSourceLocked()
            }

            scheduleLocked(kind: previousSnapshot.exists ? .changed : .replaced)
        } else {
            stopFileSourceLocked()
            scheduleLocked(kind: previousSnapshot.exists ? .deleted : .changed)
        }
    }

    private func scheduleLocked(kind: FileWatchEvent.Kind) {
        pendingWorkItem?.cancel()

        let event = FileWatchEvent(url: url, kind: kind)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isWatching else {
                return
            }

            let callbackQueue = self.callbackQueue
            let handler = self.handler
            callbackQueue.async {
                handler(event)
            }
        }

        pendingWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func openEventOnlyDescriptor(path: String) -> CInt {
        #if canImport(Darwin)
        return open(path, O_EVTONLY)
        #else
        return open(path, O_RDONLY)
        #endif
    }
}

private struct WatchedFileSnapshot: Equatable {
    let exists: Bool
    let identity: WatchedFileIdentity?
    let fileSize: Int64
    let modifiedAt: TimeInterval?

    static func read(url: URL, fileManager: FileManager = .default) -> WatchedFileSnapshot {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return WatchedFileSnapshot(exists: false, identity: nil, fileSize: 0, modifiedAt: nil)
        }

        let identity = WatchedFileIdentity(
            deviceID: (attributes[.systemNumber] as? NSNumber)?.uint64Value,
            fileID: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        )
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970

        return WatchedFileSnapshot(
            exists: true,
            identity: identity,
            fileSize: fileSize,
            modifiedAt: modifiedAt
        )
    }
}

private struct WatchedFileIdentity: Equatable {
    let deviceID: UInt64?
    let fileID: UInt64?
}
