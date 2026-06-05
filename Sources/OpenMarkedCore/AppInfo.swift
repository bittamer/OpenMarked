import Foundation

public enum AppInfo {
    public static let name = "OpenMarked"
    public static let version = "0.1.0-alpha.1"
    public static let minimumMacOSVersion = "13.0"

    public static let summary = "An open source, native macOS Markdown previewer."

    public static let supportedFileExtensions: Set<String> = [
        "md",
        "markdown",
        "mdown",
        "mkd",
        "txt",
        "text"
    ]

    public static func supportsFileExtension(_ fileExtension: String) -> Bool {
        supportedFileExtensions.contains(fileExtension.lowercased())
    }
}

