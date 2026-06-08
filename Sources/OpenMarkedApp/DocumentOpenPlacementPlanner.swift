import Foundation

struct DocumentWindowDescriptor: Equatable, Identifiable {
    let id: UUID
    var canReplaceWithOpenedDocument: Bool
}

enum DocumentOpenAnchor: Equatable {
    case existing(UUID)
    case firstOpenedWindow
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
