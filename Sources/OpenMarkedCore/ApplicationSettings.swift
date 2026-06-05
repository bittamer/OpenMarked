import Foundation

public struct ApplicationSettings: Codable, Equatable, Sendable {
    public var defaultThemeID: String
    public var defaultFontScale: Double
    public var isLivePreviewEnabled: Bool
    public var preservesScrollPosition: Bool
    public var allowsRemoteImages: Bool
    public var allowsRawHTML: Bool
    public var embedsCSSInHTMLExport: Bool
    public var embedsLocalImagesInHTMLExport: Bool
    public var restoresLastOpenedDocuments: Bool

    public init(
        defaultThemeID: String = PreviewThemeStore.defaultThemeID,
        defaultFontScale: Double = 1.0,
        isLivePreviewEnabled: Bool = true,
        preservesScrollPosition: Bool = true,
        allowsRemoteImages: Bool = true,
        allowsRawHTML: Bool = true,
        embedsCSSInHTMLExport: Bool = true,
        embedsLocalImagesInHTMLExport: Bool = true,
        restoresLastOpenedDocuments: Bool = false
    ) {
        self.defaultThemeID = defaultThemeID
        self.defaultFontScale = defaultFontScale
        self.isLivePreviewEnabled = isLivePreviewEnabled
        self.preservesScrollPosition = preservesScrollPosition
        self.allowsRemoteImages = allowsRemoteImages
        self.allowsRawHTML = allowsRawHTML
        self.embedsCSSInHTMLExport = embedsCSSInHTMLExport
        self.embedsLocalImagesInHTMLExport = embedsLocalImagesInHTMLExport
        self.restoresLastOpenedDocuments = restoresLastOpenedDocuments
    }

    public static let `default` = ApplicationSettings()

    public func normalized() -> ApplicationSettings {
        var settings = self
        settings.defaultThemeID = PreviewThemeStore.theme(id: defaultThemeID).id
        settings.defaultFontScale = min(2.0, max(0.6, defaultFontScale))
        return settings
    }

    public var defaultLayout: WindowLayoutState {
        WindowLayoutState(
            isOutlineVisible: true,
            selectedThemeID: PreviewThemeStore.theme(id: defaultThemeID).id,
            fontScale: min(2.0, max(0.6, defaultFontScale))
        )
    }
}

public final class ApplicationSettingsStore: @unchecked Sendable {
    public static let shared = ApplicationSettingsStore()

    private let userDefaults: UserDefaults
    private let settingsKey: String
    private let lastDocumentPathsKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        settingsKey: String = "OpenMarkedApplicationSettings",
        lastDocumentPathsKey: String = "OpenMarkedLastDocumentPaths"
    ) {
        self.userDefaults = userDefaults
        self.settingsKey = settingsKey
        self.lastDocumentPathsKey = lastDocumentPathsKey
    }

    public func load() -> ApplicationSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(ApplicationSettings.self, from: data) else {
            return .default
        }

        return decoded.normalized()
    }

    public func save(_ settings: ApplicationSettings) {
        guard let data = try? JSONEncoder().encode(settings.normalized()) else {
            return
        }

        userDefaults.set(data, forKey: settingsKey)
    }

    public func loadLastDocumentURLs() -> [URL] {
        userDefaults.stringArray(forKey: lastDocumentPathsKey)?
            .map { URL(fileURLWithPath: $0) } ?? []
    }

    public func saveLastDocumentURLs(_ urls: [URL]) {
        let paths = urls.map { $0.standardizedFileURL.path }
        userDefaults.set(paths, forKey: lastDocumentPathsKey)
    }
}
