import Foundation

public enum PerformanceMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case automatic
    case fidelity
    case performance

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .fidelity:
            return "Fidelity"
        case .performance:
            return "Performance"
        }
    }
}

public enum CurrentSectionTrackingPreference: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case automatic
    case always
    case disabled

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .always:
            return "Always"
        case .disabled:
            return "Disabled"
        }
    }
}

public enum ReferencedImageReloadMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case automatic
    case perFile
    case directory
    case manual

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .perFile:
            return "Per File"
        case .directory:
            return "Folders"
        case .manual:
            return "Manual"
        }
    }
}

public enum CurrentSectionTrackingBehavior: String, Equatable, Sendable {
    case active
    case idleOnly
    case disabled
}

public enum AssetWatchStrategy: String, Equatable, Sendable {
    case perFile
    case directoryFiltered
    case manualReload
}

public struct DocumentPerformanceProfile: Equatable, Sendable {
    public let sourceByteCount: Int
    public let headingCount: Int
    public let imageCount: Int
    public let linkCount: Int

    public init(
        sourceByteCount: Int,
        headingCount: Int,
        imageCount: Int,
        linkCount: Int
    ) {
        self.sourceByteCount = sourceByteCount
        self.headingCount = headingCount
        self.imageCount = imageCount
        self.linkCount = linkCount
    }

    public var isLargeForSectionTracking: Bool {
        sourceByteCount > 500_000 || headingCount > 220 || imageCount > 180
    }

    public var isVeryLargeForSectionTracking: Bool {
        sourceByteCount > 1_500_000 || headingCount > 600 || imageCount > 450
    }

    public var isLargeForAssetWatching: Bool {
        imageCount > 80
    }

    public var isVeryLargeForAssetWatching: Bool {
        imageCount > 260
    }
}

public struct ApplicationSettings: Codable, Equatable, Sendable {
    public var defaultThemeID: String
    public var appChromeThemeID: String
    public var defaultFontScale: Double
    public var isLivePreviewEnabled: Bool
    public var preservesScrollPosition: Bool
    public var allowsRemoteImages: Bool
    public var allowsRawHTML: Bool
    public var embedsCSSInHTMLExport: Bool
    public var embedsLocalImagesInHTMLExport: Bool
    public var restoresLastOpenedDocuments: Bool
    public var renderProfile: MarkdownRenderProfile
    public var richMarkdownOptions: RichMarkdownOptions
    public var statisticsWordsPerMinute: Int
    public var includesFrontMatterInStatistics: Bool
    public var printConfiguration: PrintConfiguration
    public var performanceMode: PerformanceMode
    public var currentSectionTracking: CurrentSectionTrackingPreference
    public var referencedImageReloadMode: ReferencedImageReloadMode

    public init(
        defaultThemeID: String = PreviewThemeStore.defaultThemeID,
        appChromeThemeID: String = AppChromeThemeStore.defaultThemeID,
        defaultFontScale: Double = 1.0,
        isLivePreviewEnabled: Bool = true,
        preservesScrollPosition: Bool = true,
        allowsRemoteImages: Bool = true,
        allowsRawHTML: Bool = true,
        embedsCSSInHTMLExport: Bool = true,
        embedsLocalImagesInHTMLExport: Bool = true,
        restoresLastOpenedDocuments: Bool = false,
        renderProfile: MarkdownRenderProfile = .openMarked,
        richMarkdownOptions: RichMarkdownOptions = .default,
        statisticsWordsPerMinute: Int = DocumentStatisticsOptions.defaultWordsPerMinute,
        includesFrontMatterInStatistics: Bool = false,
        printConfiguration: PrintConfiguration = .default,
        performanceMode: PerformanceMode = .automatic,
        currentSectionTracking: CurrentSectionTrackingPreference = .automatic,
        referencedImageReloadMode: ReferencedImageReloadMode = .automatic
    ) {
        self.defaultThemeID = defaultThemeID
        self.appChromeThemeID = appChromeThemeID
        self.defaultFontScale = defaultFontScale
        self.isLivePreviewEnabled = isLivePreviewEnabled
        self.preservesScrollPosition = preservesScrollPosition
        self.allowsRemoteImages = allowsRemoteImages
        self.allowsRawHTML = allowsRawHTML
        self.embedsCSSInHTMLExport = embedsCSSInHTMLExport
        self.embedsLocalImagesInHTMLExport = embedsLocalImagesInHTMLExport
        self.restoresLastOpenedDocuments = restoresLastOpenedDocuments
        self.renderProfile = renderProfile
        self.richMarkdownOptions = richMarkdownOptions
        self.statisticsWordsPerMinute = statisticsWordsPerMinute
        self.includesFrontMatterInStatistics = includesFrontMatterInStatistics
        self.printConfiguration = printConfiguration
        self.performanceMode = performanceMode
        self.currentSectionTracking = currentSectionTracking
        self.referencedImageReloadMode = referencedImageReloadMode
    }

    public static let `default` = ApplicationSettings()

    public func normalized() -> ApplicationSettings {
        var settings = self
        settings.defaultThemeID = PreviewThemeStore.normalizedThemeID(defaultThemeID)
        settings.appChromeThemeID = AppChromeThemeStore.theme(id: appChromeThemeID).id
        settings.defaultFontScale = min(2.0, max(0.6, defaultFontScale))
        settings.statisticsWordsPerMinute = DocumentStatisticsOptions(
            wordsPerMinute: statisticsWordsPerMinute,
            includesFrontMatter: includesFrontMatterInStatistics
        )
        .normalized()
        .wordsPerMinute
        settings.printConfiguration = printConfiguration.normalized()
        return settings
    }

    public var documentStatisticsOptions: DocumentStatisticsOptions {
        DocumentStatisticsOptions(
            wordsPerMinute: statisticsWordsPerMinute,
            includesFrontMatter: includesFrontMatterInStatistics
        )
        .normalized()
    }

    public func currentSectionTrackingBehavior(for profile: DocumentPerformanceProfile) -> CurrentSectionTrackingBehavior {
        switch currentSectionTracking {
        case .disabled:
            return .disabled
        case .always:
            return .active
        case .automatic:
            switch performanceMode {
            case .fidelity:
                return .active
            case .performance:
                return profile.isLargeForSectionTracking ? .idleOnly : .active
            case .automatic:
                if profile.isVeryLargeForSectionTracking {
                    return .disabled
                }
                return profile.isLargeForSectionTracking ? .idleOnly : .active
            }
        }
    }

    public func assetWatchStrategy(
        for profile: DocumentPerformanceProfile,
        directoryCount: Int
    ) -> AssetWatchStrategy {
        switch referencedImageReloadMode {
        case .perFile:
            return .perFile
        case .directory:
            return .directoryFiltered
        case .manual:
            return .manualReload
        case .automatic:
            switch performanceMode {
            case .fidelity:
                return profile.isVeryLargeForAssetWatching ? .directoryFiltered : .perFile
            case .performance:
                return profile.isLargeForAssetWatching ? .manualReload : .directoryFiltered
            case .automatic:
                if profile.isVeryLargeForAssetWatching {
                    return .manualReload
                }
                if profile.isLargeForAssetWatching || directoryCount < profile.imageCount {
                    return .directoryFiltered
                }
                return .perFile
            }
        }
    }

    public var defaultLayout: WindowLayoutState {
        WindowLayoutState(
            isOutlineVisible: true,
            selectedThemeID: PreviewThemeStore.normalizedThemeID(defaultThemeID),
            fontScale: min(2.0, max(0.6, defaultFontScale))
        )
    }

    private enum CodingKeys: String, CodingKey {
        case defaultThemeID
        case appChromeThemeID
        case defaultFontScale
        case isLivePreviewEnabled
        case preservesScrollPosition
        case allowsRemoteImages
        case allowsRawHTML
        case embedsCSSInHTMLExport
        case embedsLocalImagesInHTMLExport
        case restoresLastOpenedDocuments
        case renderProfile
        case richMarkdownOptions
        case statisticsWordsPerMinute
        case includesFrontMatterInStatistics
        case printConfiguration
        case performanceMode
        case currentSectionTracking
        case referencedImageReloadMode
    }

    public init(from decoder: Decoder) throws {
        let defaults = ApplicationSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            defaultThemeID: try container.decodeIfPresent(String.self, forKey: .defaultThemeID) ?? defaults.defaultThemeID,
            appChromeThemeID: try container.decodeIfPresent(String.self, forKey: .appChromeThemeID) ?? defaults.appChromeThemeID,
            defaultFontScale: try container.decodeIfPresent(Double.self, forKey: .defaultFontScale) ?? defaults.defaultFontScale,
            isLivePreviewEnabled: try container.decodeIfPresent(Bool.self, forKey: .isLivePreviewEnabled) ?? defaults.isLivePreviewEnabled,
            preservesScrollPosition: try container.decodeIfPresent(Bool.self, forKey: .preservesScrollPosition) ?? defaults.preservesScrollPosition,
            allowsRemoteImages: try container.decodeIfPresent(Bool.self, forKey: .allowsRemoteImages) ?? defaults.allowsRemoteImages,
            allowsRawHTML: try container.decodeIfPresent(Bool.self, forKey: .allowsRawHTML) ?? defaults.allowsRawHTML,
            embedsCSSInHTMLExport: try container.decodeIfPresent(Bool.self, forKey: .embedsCSSInHTMLExport) ?? defaults.embedsCSSInHTMLExport,
            embedsLocalImagesInHTMLExport: try container.decodeIfPresent(Bool.self, forKey: .embedsLocalImagesInHTMLExport) ?? defaults.embedsLocalImagesInHTMLExport,
            restoresLastOpenedDocuments: try container.decodeIfPresent(Bool.self, forKey: .restoresLastOpenedDocuments) ?? defaults.restoresLastOpenedDocuments,
            renderProfile: try container.decodeIfPresent(MarkdownRenderProfile.self, forKey: .renderProfile) ?? defaults.renderProfile,
            richMarkdownOptions: try container.decodeIfPresent(RichMarkdownOptions.self, forKey: .richMarkdownOptions) ?? defaults.richMarkdownOptions,
            statisticsWordsPerMinute: try container.decodeIfPresent(Int.self, forKey: .statisticsWordsPerMinute) ?? defaults.statisticsWordsPerMinute,
            includesFrontMatterInStatistics: try container.decodeIfPresent(Bool.self, forKey: .includesFrontMatterInStatistics) ?? defaults.includesFrontMatterInStatistics,
            printConfiguration: try container.decodeIfPresent(PrintConfiguration.self, forKey: .printConfiguration) ?? defaults.printConfiguration,
            performanceMode: try container.decodeIfPresent(PerformanceMode.self, forKey: .performanceMode) ?? defaults.performanceMode,
            currentSectionTracking: try container.decodeIfPresent(CurrentSectionTrackingPreference.self, forKey: .currentSectionTracking) ?? defaults.currentSectionTracking,
            referencedImageReloadMode: try container.decodeIfPresent(ReferencedImageReloadMode.self, forKey: .referencedImageReloadMode) ?? defaults.referencedImageReloadMode
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
