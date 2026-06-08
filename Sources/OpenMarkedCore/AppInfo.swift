import Foundation

public enum AppInfo {
    public static let name = "OpenMarked"
    public static let version = "0.4.1"
    public static let build = "5"
    public static let bundleIdentifier = "org.openmarked.OpenMarked"
    public static let minimumMacOSVersion = "13.0"
    public static let repositoryURL = URL(string: "https://github.com/openmarked/openmarked")!
    public static let licenseName = "GNU General Public License v3.0"

    public static let summary = "An open source, native macOS Markdown previewer."

    public static let supportedFileExtensions: Set<String> = [
        "md",
        "markdown",
        "mdown",
        "mkd",
        "mkdn",
        "txt",
        "text"
    ]

    public static func supportsFileExtension(_ fileExtension: String) -> Bool {
        supportedFileExtensions.contains(fileExtension.lowercased())
    }
}
