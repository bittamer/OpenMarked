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

public struct PersistedDocumentWindowState: Codable, Equatable, Sendable {
    public let documentID: String
    public let sourceURL: URL
    public let bookmarkData: Data?
    public let layout: WindowLayoutState
    public let frame: DocumentWindowFrame?
    public let savedAt: Date

    public init(
        documentID: String,
        sourceURL: URL,
        bookmarkData: Data?,
        layout: WindowLayoutState,
        frame: DocumentWindowFrame?,
        savedAt: Date = Date()
    ) {
        self.documentID = documentID
        self.sourceURL = sourceURL
        self.bookmarkData = bookmarkData
        self.layout = layout
        self.frame = frame
        self.savedAt = savedAt
    }
}

public final class DocumentWindowStateStore: @unchecked Sendable {
    public static let shared = DocumentWindowStateStore()

    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(userDefaults: UserDefaults = .standard, storageKey: String = "OpenMarked.DocumentWindowStateStore") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    public func save(_ state: PersistedDocumentWindowState) {
        var states = loadAll()
        states[state.documentID] = state
        persist(states)
    }

    public func save(document: MarkdownDocument, layout: WindowLayoutState, frame: DocumentWindowFrame? = nil, savedAt: Date = Date()) {
        save(
            PersistedDocumentWindowState(
                documentID: document.id,
                sourceURL: document.sourceURL,
                bookmarkData: document.securityScopedBookmark?.data,
                layout: layout,
                frame: frame,
                savedAt: savedAt
            )
        )
    }

    public func restore(forDocumentID documentID: String) -> PersistedDocumentWindowState? {
        loadAll()[documentID]
    }

    public func restore(for url: URL) -> PersistedDocumentWindowState? {
        restore(forDocumentID: url.standardizedFileURL.path)
    }

    public func remove(forDocumentID documentID: String) {
        var states = loadAll()
        states.removeValue(forKey: documentID)
        persist(states)
    }

    public func removeAll() {
        userDefaults.removeObject(forKey: storageKey)
    }

    public func loadAll() -> [String: PersistedDocumentWindowState] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: PersistedDocumentWindowState].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persist(_ states: [String: PersistedDocumentWindowState]) {
        do {
            let data = try JSONEncoder().encode(states)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to persist document window state: \(error)")
        }
    }
}
