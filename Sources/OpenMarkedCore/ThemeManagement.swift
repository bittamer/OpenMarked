import Foundation

public struct UserPreviewTheme: Equatable, Identifiable, Sendable, Codable {
    public static let idPrefix = "user."

    public var id: String
    public var name: String
    public var screenCSSPath: String
    public var codeCSSPath: String?
    public var printCSSPath: String?
    public var defaultMaxWidth: Int

    public init(
        id: String,
        name: String,
        screenCSSPath: String,
        codeCSSPath: String? = nil,
        printCSSPath: String? = nil,
        defaultMaxWidth: Int = PreviewThemeStore.defaultTheme.defaultMaxWidth
    ) {
        self.id = id
        self.name = name
        self.screenCSSPath = screenCSSPath
        self.codeCSSPath = codeCSSPath
        self.printCSSPath = printCSSPath
        self.defaultMaxWidth = defaultMaxWidth
    }

    public static func isUserThemeID(_ id: String) -> Bool {
        id.hasPrefix(idPrefix)
    }

    static func makeID() -> String {
        "\(idPrefix)\(UUID().uuidString.lowercased())"
    }
}

public enum UserPreviewThemeError: Error, Equatable, LocalizedError, Sendable {
    case nonLocalFile
    case unsupportedFileType(String)
    case unreadableFile(String)
    case emptyCSS
    case importRulesUnsupported
    case javascriptURLBlocked
    case embeddedHTMLBlocked
    case missingBuiltInTheme(String)
    case missingUserTheme(String)
    case invalidThemeName

    public var errorDescription: String? {
        switch self {
        case .nonLocalFile:
            return "OpenMarked can only import local CSS files."
        case .unsupportedFileType(let pathExtension):
            return "OpenMarked can only import .css files, not .\(pathExtension)."
        case .unreadableFile(let path):
            return "OpenMarked could not read the CSS file at \(path)."
        case .emptyCSS:
            return "OpenMarked cannot import an empty CSS file."
        case .importRulesUnsupported:
            return "OpenMarked does not allow CSS @import rules in custom themes."
        case .javascriptURLBlocked:
            return "OpenMarked blocked a custom theme containing a javascript: URL."
        case .embeddedHTMLBlocked:
            return "OpenMarked blocked a custom theme containing embedded HTML."
        case .missingBuiltInTheme(let id):
            return "OpenMarked could not find the built-in theme \(id)."
        case .missingUserTheme(let id):
            return "OpenMarked could not find the user theme \(id)."
        case .invalidThemeName:
            return "Theme names cannot be empty."
        }
    }
}

public final class UserPreviewThemeStore: @unchecked Sendable {
    public static let shared = UserPreviewThemeStore()

    public let themesDirectoryURL: URL

    private let userDefaults: UserDefaults
    private let metadataKey: String
    private let fileManager: FileManager
    private let previewThemeCacheLock = NSLock()
    private var previewThemeCache: [String: CachedPreviewTheme] = [:]

    public init(
        userDefaults: UserDefaults = .standard,
        metadataKey: String = "OpenMarkedUserPreviewThemes",
        themesDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.metadataKey = metadataKey
        self.fileManager = fileManager
        self.themesDirectoryURL = themesDirectoryURL ?? Self.defaultThemesDirectoryURL(fileManager: fileManager)
    }

    public func load() -> [UserPreviewTheme] {
        guard
            let data = userDefaults.data(forKey: metadataKey),
            let decoded = try? JSONDecoder().decode([UserPreviewTheme].self, from: data)
        else {
            return []
        }

        return decoded.filter { theme in
            UserPreviewTheme.isUserThemeID(theme.id)
                && !theme.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !theme.screenCSSPath.isEmpty
        }
    }

    public func save(_ themes: [UserPreviewTheme]) {
        let uniqueThemes = themes.reduce(into: [UserPreviewTheme]()) { result, theme in
            guard !result.contains(where: { $0.id == theme.id }) else {
                return
            }
            result.append(theme)
        }

        guard let data = try? JSONEncoder().encode(uniqueThemes) else {
            return
        }

        userDefaults.set(data, forKey: metadataKey)
        invalidatePreviewThemeCache()
    }

    @discardableResult
    public func importTheme(
        from sourceURL: URL,
        name: String? = nil,
        defaultMaxWidth: Int = PreviewThemeStore.defaultTheme.defaultMaxWidth
    ) throws -> UserPreviewTheme {
        let css = try readImportableCSS(from: sourceURL)
        let themeName = try normalizedThemeName(name ?? sourceURL.deletingPathExtension().lastPathComponent)
        let id = UserPreviewTheme.makeID()
        let destinationURL = themesDirectoryURL.appendingPathComponent("\(id).css", isDirectory: false)
        try ensureThemesDirectory()
        try css.write(to: destinationURL, atomically: true, encoding: .utf8)

        let theme = UserPreviewTheme(
            id: id,
            name: themeName,
            screenCSSPath: destinationURL.path,
            defaultMaxWidth: defaultMaxWidth
        )
        var themes = load()
        themes.append(theme)
        save(themes)
        return theme
    }

    @discardableResult
    public func duplicateBuiltInTheme(id builtInThemeID: String, name: String? = nil) throws -> UserPreviewTheme {
        guard PreviewThemeStore.isBuiltInThemeID(builtInThemeID) else {
            throw UserPreviewThemeError.missingBuiltInTheme(builtInThemeID)
        }

        let builtInTheme = PreviewThemeStore.builtInTheme(id: builtInThemeID)
        let themeName = try normalizedThemeName(name ?? "\(builtInTheme.name) Copy")
        let id = UserPreviewTheme.makeID()
        let screenURL = themesDirectoryURL.appendingPathComponent("\(id).css", isDirectory: false)
        let codeURL = themesDirectoryURL.appendingPathComponent("\(id)-code.css", isDirectory: false)
        let printURL = themesDirectoryURL.appendingPathComponent("\(id)-print.css", isDirectory: false)

        try ensureThemesDirectory()
        try builtInTheme.screenCSS.write(to: screenURL, atomically: true, encoding: .utf8)
        try builtInTheme.codeHighlightingCSS.write(to: codeURL, atomically: true, encoding: .utf8)
        try builtInTheme.printCSS.write(to: printURL, atomically: true, encoding: .utf8)

        let theme = UserPreviewTheme(
            id: id,
            name: themeName,
            screenCSSPath: screenURL.path,
            codeCSSPath: codeURL.path,
            printCSSPath: printURL.path,
            defaultMaxWidth: builtInTheme.defaultMaxWidth
        )
        var themes = load()
        themes.append(theme)
        save(themes)
        return theme
    }

    @discardableResult
    public func renameTheme(id themeID: String, name: String) throws -> UserPreviewTheme {
        let themeName = try normalizedThemeName(name)
        var themes = load()
        guard let index = themes.firstIndex(where: { $0.id == themeID }) else {
            throw UserPreviewThemeError.missingUserTheme(themeID)
        }

        themes[index].name = themeName
        save(themes)
        return themes[index]
    }

    public func deleteTheme(id themeID: String) throws {
        var themes = load()
        guard let index = themes.firstIndex(where: { $0.id == themeID }) else {
            throw UserPreviewThemeError.missingUserTheme(themeID)
        }

        let theme = themes.remove(at: index)
        removeManagedThemeFile(theme.screenCSSPath)
        if let codeCSSPath = theme.codeCSSPath {
            removeManagedThemeFile(codeCSSPath)
        }
        if let printCSSPath = theme.printCSSPath {
            removeManagedThemeFile(printCSSPath)
        }
        save(themes)
    }

    public func previewTheme(for userTheme: UserPreviewTheme) -> PreviewTheme {
        let signature = UserThemeCSSSignature(theme: userTheme, fileManager: fileManager)

        previewThemeCacheLock.lock()
        if let cached = previewThemeCache[userTheme.id],
           cached.userTheme == userTheme,
           cached.signature == signature {
            previewThemeCacheLock.unlock()
            return cached.previewTheme
        }
        previewThemeCacheLock.unlock()

        let fallbackTheme = PreviewThemeStore.defaultTheme
        let screenCSS = validatedCSS(atPath: userTheme.screenCSSPath) ?? fallbackTheme.screenCSS
        let codeCSS = userTheme.codeCSSPath.flatMap(validatedCSS(atPath:)) ?? fallbackTheme.codeHighlightingCSS
        let printCSS = userTheme.printCSSPath.flatMap(validatedCSS(atPath:)) ?? fallbackTheme.printCSS

        let previewTheme = PreviewTheme(
            id: userTheme.id,
            name: userTheme.name,
            screenCSS: screenCSS,
            printCSS: printCSS,
            codeHighlightingCSS: codeCSS,
            supportsDarkMode: true,
            defaultMaxWidth: min(1_400, max(560, userTheme.defaultMaxWidth))
        )

        previewThemeCacheLock.lock()
        previewThemeCache[userTheme.id] = CachedPreviewTheme(
            userTheme: userTheme,
            signature: signature,
            previewTheme: previewTheme
        )
        previewThemeCacheLock.unlock()

        return previewTheme
    }

    public func previewTheme(id themeID: String) -> PreviewTheme? {
        guard let theme = load().first(where: { $0.id == themeID }) else {
            return nil
        }

        return previewTheme(for: theme)
    }

    public func ensureThemesDirectory() throws {
        try fileManager.createDirectory(at: themesDirectoryURL, withIntermediateDirectories: true)
    }

    public static func validateCSS(_ css: String) throws {
        let trimmedCSS = css.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCSS.isEmpty else {
            throw UserPreviewThemeError.emptyCSS
        }

        if trimmedCSS.range(of: #"(?is)@\s*import\b"#, options: .regularExpression) != nil {
            throw UserPreviewThemeError.importRulesUnsupported
        }

        if trimmedCSS.range(of: #"(?is)javascript\s*:"#, options: .regularExpression) != nil {
            throw UserPreviewThemeError.javascriptURLBlocked
        }

        if trimmedCSS.range(of: #"(?is)<\s*/?\s*(script|style)\b"#, options: .regularExpression) != nil {
            throw UserPreviewThemeError.embeddedHTMLBlocked
        }
    }

    private func readImportableCSS(from sourceURL: URL) throws -> String {
        guard sourceURL.isFileURL else {
            throw UserPreviewThemeError.nonLocalFile
        }

        let pathExtension = sourceURL.pathExtension.lowercased()
        guard pathExtension == "css" else {
            throw UserPreviewThemeError.unsupportedFileType(pathExtension.isEmpty ? "file" : pathExtension)
        }

        do {
            let resourceValues = try sourceURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else {
                throw UserPreviewThemeError.unreadableFile(sourceURL.path)
            }
        } catch let error as UserPreviewThemeError {
            throw error
        } catch {
            throw UserPreviewThemeError.unreadableFile(sourceURL.path)
        }

        do {
            let css = try String(contentsOf: sourceURL, encoding: .utf8)
            try Self.validateCSS(css)
            return css
        } catch let error as UserPreviewThemeError {
            throw error
        } catch {
            throw UserPreviewThemeError.unreadableFile(sourceURL.path)
        }
    }

    private func validatedCSS(atPath path: String) -> String? {
        guard !path.isEmpty else {
            return nil
        }

        do {
            let css = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
            try Self.validateCSS(css)
            return css
        } catch {
            return nil
        }
    }

    private func normalizedThemeName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw UserPreviewThemeError.invalidThemeName
        }

        return String(name.prefix(80))
    }

    private func removeManagedThemeFile(_ path: String) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let managedDirectoryPath = themesDirectoryURL.standardizedFileURL.path
        guard url.path.hasPrefix("\(managedDirectoryPath)/") else {
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    private func invalidatePreviewThemeCache() {
        previewThemeCacheLock.lock()
        previewThemeCache.removeAll()
        previewThemeCacheLock.unlock()
    }

    private struct CachedPreviewTheme {
        let userTheme: UserPreviewTheme
        let signature: UserThemeCSSSignature
        let previewTheme: PreviewTheme
    }

    private struct UserThemeCSSSignature: Equatable {
        let screen: ThemeFileSignature
        let code: ThemeFileSignature?
        let print: ThemeFileSignature?

        init(theme: UserPreviewTheme, fileManager: FileManager) {
            screen = ThemeFileSignature(path: theme.screenCSSPath, fileManager: fileManager)
            code = theme.codeCSSPath.map { ThemeFileSignature(path: $0, fileManager: fileManager) }
            print = theme.printCSSPath.map { ThemeFileSignature(path: $0, fileManager: fileManager) }
        }
    }

    private struct ThemeFileSignature: Equatable {
        let path: String
        let exists: Bool
        let fileSize: UInt64?
        let modifiedAt: Date?

        init(path: String, fileManager: FileManager) {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            self.path = url.path

            guard
                let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                let size = attributes[.size] as? NSNumber
            else {
                exists = false
                fileSize = nil
                modifiedAt = nil
                return
            }

            exists = true
            fileSize = size.uint64Value
            modifiedAt = attributes[.modificationDate] as? Date
        }
    }

    private static func defaultThemesDirectoryURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        return applicationSupportURL
            .appendingPathComponent("OpenMarked", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }
}

public extension PreviewThemeStore {
    static func normalizedThemeID(_ id: String) -> String {
        if isBuiltInThemeID(id) || UserPreviewTheme.isUserThemeID(id) {
            return id
        }

        return defaultThemeID
    }
}
