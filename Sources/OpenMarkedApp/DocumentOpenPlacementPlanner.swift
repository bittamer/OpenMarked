import Foundation

struct DocumentWindowDescriptor: Equatable, Identifiable {
    let id: UUID
    var canReplaceWithOpenedDocument: Bool
    var hasOpenedDocument = false
}

enum DocumentOpenAnchor: Equatable {
    case existing(UUID)
    case firstOpenedWindow
}

enum ExternalDocumentOpenPlanner {
    static func preferredWindow(
        activeWindow: DocumentWindowDescriptor?,
        windowsInActivityOrder: [DocumentWindowDescriptor]
    ) -> DocumentWindowDescriptor? {
        if let activeWindow, activeWindow.hasOpenedDocument {
            return activeWindow
        }

        if let mostRecentLoadedWindow = windowsInActivityOrder.reversed().first(where: \.hasOpenedDocument) {
            return mostRecentLoadedWindow
        }

        if let activeWindow {
            return activeWindow
        }

        return windowsInActivityOrder.last
    }

    static func transientEmptyWindowIDs(
        windows: [DocumentWindowDescriptor],
        preservedEmptyWindowIDs: Set<UUID>
    ) -> Set<UUID> {
        Set(
            windows
                .filter { window in
                    window.canReplaceWithOpenedDocument && !preservedEmptyWindowIDs.contains(window.id)
                }
                .map(\.id)
        )
    }
}

enum PlannedDocumentOpenPlacement: Equatable {
    case replace(UUID)
    case newStandaloneWindow
    case newTab(anchor: DocumentOpenAnchor)
}

enum DocumentOpenPlacementPlanner {
    static func plan(
        documentCount: Int,
        preferredWindow: DocumentWindowDescriptor?,
        activeWindow: DocumentWindowDescriptor?
    ) -> [PlannedDocumentOpenPlacement] {
        guard documentCount > 0 else {
            return []
        }

        let anchorCandidate = preferredWindow ?? activeWindow
        var placements: [PlannedDocumentOpenPlacement] = []
        let anchor: DocumentOpenAnchor

        if let candidate = anchorCandidate {
            if candidate.canReplaceWithOpenedDocument {
                placements.append(.replace(candidate.id))
            } else {
                placements.append(.newTab(anchor: .existing(candidate.id)))
            }
            anchor = .existing(candidate.id)
        } else {
            placements.append(.newStandaloneWindow)
            anchor = .firstOpenedWindow
        }

        if documentCount > 1 {
            placements.append(contentsOf: Array(repeating: .newTab(anchor: anchor), count: documentCount - 1))
        }

        return placements
    }
}
