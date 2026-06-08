import Foundation
import OpenMarkedCore

struct SessionRestorationPlan: Equatable {
    let urls: [URL]

    var shouldRestore: Bool {
        !urls.isEmpty
    }
}

enum SessionRestorationPlanner {
    static func plan(
        isEnabled: Bool,
        savedURLs: [URL],
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> SessionRestorationPlan {
        guard isEnabled else {
            return SessionRestorationPlan(urls: [])
        }

        let restorableURLs = savedURLs.filter { url in
            AppInfo.supportsFileExtension(url.pathExtension) && fileExists(url)
        }

        return SessionRestorationPlan(urls: restorableURLs)
    }
}
