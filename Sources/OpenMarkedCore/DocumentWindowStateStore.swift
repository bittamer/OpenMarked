import Foundation

public struct DocumentWindowFrame: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DocumentExportDestinations: Codable, Equatable, Sendable {
    public var html: URL?
    public var pdf: URL?

    public init(html: URL? = nil, pdf: URL? = nil) {
        self.html = html
        self.pdf = pdf
    }

    public static let empty = DocumentExportDestinations()
}

public struct PersistedDocumentWindowState: Codable, Equatable, Sendable {
    public let documentID: String
    public let sourceURL: URL
    public let bookmarkData: Data?
    public let layout: WindowLayoutState
    public let frame: DocumentWindowFrame?
    public let exportDestinations: DocumentExportDestinations
    public let savedAt: Date

    public init(
        documentID: String,
        sourceURL: URL,
        bookmarkData: Data?,
        layout: WindowLayoutState,
        frame: DocumentWindowFrame?,
        exportDestinations: DocumentExportDestinations = .empty,
        savedAt: Date = Date()
    ) {
        self.documentID = documentID
        self.sourceURL = sourceURL
        self.bookmarkData = bookmarkData
        self.layout = layout
        self.frame = frame
        self.exportDestinations = exportDestinations
        self.savedAt = savedAt
    }

    private enum CodingKeys: String, CodingKey {
        case documentID
        case sourceURL
        case bookmarkData
        case layout
        case frame
        case exportDestinations
        case savedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentID = try container.decode(String.self, forKey: .documentID)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        layout = try container.decode(WindowLayoutState.self, forKey: .layout)
        frame = try container.decodeIfPresent(DocumentWindowFrame.self, forKey: .frame)
        exportDestinations = try container.decodeIfPresent(DocumentExportDestinations.self, forKey: .exportDestinations) ?? .empty
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
    }
}

public final class DocumentWindowStateStore: @unchecked Sendable {
    public static let shared = DocumentWindowStateStore()

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let lock = NSLock()
    private var cachedStates: [String: PersistedDocumentWindowState]

    public init(userDefaults: UserDefaults = .standard, storageKey: String = "OpenMarked.DocumentWindowStateStore") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.cachedStates = Self.loadPersistedStates(userDefaults: userDefaults, storageKey: storageKey)
    }

    public func save(_ state: PersistedDocumentWindowState) {
        lock.lock()
        defer { lock.unlock() }

        cachedStates[state.documentID] = state
        persistCachedStates()
    }

    public func save(
        document: MarkdownDocument,
        layout: WindowLayoutState,
        frame: DocumentWindowFrame? = nil,
        exportDestinations: DocumentExportDestinations = .empty,
        savedAt: Date = Date()
    ) {
        save(
            PersistedDocumentWindowState(
                documentID: document.id,
                sourceURL: document.sourceURL,
                bookmarkData: document.securityScopedBookmark?.data,
                layout: layout,
                frame: frame,
                exportDestinations: exportDestinations,
                savedAt: savedAt
            )
        )
    }

    public func restore(forDocumentID documentID: String) -> PersistedDocumentWindowState? {
        lock.lock()
        defer { lock.unlock() }

        return cachedStates[documentID]
    }

    public func restore(for url: URL) -> PersistedDocumentWindowState? {
        restore(forDocumentID: url.standardizedFileURL.path)
    }

    public func remove(forDocumentID documentID: String) {
        lock.lock()
        defer { lock.unlock() }

        cachedStates.removeValue(forKey: documentID)
        persistCachedStates()
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        cachedStates.removeAll()
        userDefaults.removeObject(forKey: storageKey)
    }

    public func loadAll() -> [String: PersistedDocumentWindowState] {
        lock.lock()
        defer { lock.unlock() }

        return cachedStates
    }

    private static func loadPersistedStates(
        userDefaults: UserDefaults,
        storageKey: String
    ) -> [String: PersistedDocumentWindowState] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: PersistedDocumentWindowState].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persistCachedStates() {
        do {
            let data = try JSONEncoder().encode(cachedStates)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to persist document window state: \(error)")
        }
    }
}
