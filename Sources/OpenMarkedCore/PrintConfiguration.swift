import Foundation

public enum PrintPageSize: String, CaseIterable, Codable, Identifiable, Sendable {
    case letter
    case a4
    case legal

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .letter:
            return "Letter"
        case .a4:
            return "A4"
        case .legal:
            return "Legal"
        }
    }

    public var cssValue: String {
        switch self {
        case .letter:
            return "letter"
        case .a4:
            return "A4"
        case .legal:
            return "legal"
        }
    }

    public var paperSizePoints: (width: Double, height: Double) {
        switch self {
        case .letter:
            return (612, 792)
        case .a4:
            return (595.28, 841.89)
        case .legal:
            return (612, 1008)
        }
    }
}

public struct PrintMargins: Codable, Equatable, Sendable {
    public static let minimumInches = 0.25
    public static let maximumInches = 2.0
    public static let `default` = PrintMargins(top: 0.75, right: 0.75, bottom: 0.75, left: 0.75)

    public var top: Double
    public var right: Double
    public var bottom: Double
    public var left: Double

    public init(top: Double = 0.75, right: Double = 0.75, bottom: Double = 0.75, left: Double = 0.75) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public func normalized() -> PrintMargins {
        PrintMargins(
            top: Self.clamped(top),
            right: Self.clamped(right),
            bottom: Self.clamped(bottom),
            left: Self.clamped(left)
        )
    }

    public var topPoints: Double {
        top * 72
    }

    public var rightPoints: Double {
        right * 72
    }

    public var bottomPoints: Double {
        bottom * 72
    }

    public var leftPoints: Double {
        left * 72
    }

    public var cssValue: String {
        "\(Self.cssInches(top)) \(Self.cssInches(right)) \(Self.cssInches(bottom)) \(Self.cssInches(left))"
    }

    private static func clamped(_ value: Double) -> Double {
        min(maximumInches, max(minimumInches, value))
    }

    private static func cssInches(_ value: Double) -> String {
        String(format: "%.2fin", clamped(value))
    }
}

public enum PrintThemeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case preview
    case defaultPrint

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .preview:
            return "Preview Theme"
        case .defaultPrint:
            return "Default Print"
        }
    }
}

public struct PrintConfiguration: Codable, Equatable, Sendable {
    public static let minimumContentMaxWidth = 560
    public static let maximumContentMaxWidth = 1_400
    public static let defaultContentMaxWidth = 820

    public var pageSize: PrintPageSize
    public var margins: PrintMargins
    public var contentMaxWidth: Int?
    public var startsHeadingOneOnNewPage: Bool
    public var startsHeadingTwoOnNewPage: Bool
    public var includesDocumentTitle: Bool
    public var themeMode: PrintThemeMode

    public init(
        pageSize: PrintPageSize = .letter,
        margins: PrintMargins = .default,
        contentMaxWidth: Int? = nil,
        startsHeadingOneOnNewPage: Bool = false,
        startsHeadingTwoOnNewPage: Bool = false,
        includesDocumentTitle: Bool = false,
        themeMode: PrintThemeMode = .preview
    ) {
        self.pageSize = pageSize
        self.margins = margins
        self.contentMaxWidth = contentMaxWidth
        self.startsHeadingOneOnNewPage = startsHeadingOneOnNewPage
        self.startsHeadingTwoOnNewPage = startsHeadingTwoOnNewPage
        self.includesDocumentTitle = includesDocumentTitle
        self.themeMode = themeMode
    }

    public static let `default` = PrintConfiguration()

    public func normalized() -> PrintConfiguration {
        var configuration = self
        configuration.margins = margins.normalized()
        if let contentMaxWidth {
            configuration.contentMaxWidth = min(
                Self.maximumContentMaxWidth,
                max(Self.minimumContentMaxWidth, contentMaxWidth)
            )
        }
        return configuration
    }

    public var overridesPageSetup: Bool {
        let normalized = normalized()
        return normalized.pageSize != Self.default.pageSize
            || normalized.margins != Self.default.margins
    }

    public var requiresPrintStyleOverrides: Bool {
        let normalized = normalized()
        return normalized.overridesPageSetup
            || normalized.contentMaxWidth != nil
            || normalized.startsHeadingOneOnNewPage
            || normalized.startsHeadingTwoOnNewPage
            || normalized.includesDocumentTitle
            || normalized.themeMode != .preview
    }

    public var bodyClasses: [String] {
        var classes: [String] = []
        let normalized = normalized()

        if normalized.includesDocumentTitle {
            classes.append("om-print-include-title")
        }
        if normalized.startsHeadingOneOnNewPage {
            classes.append("om-print-break-h1")
        }
        if normalized.startsHeadingTwoOnNewPage {
            classes.append("om-print-break-h2")
        }
        if normalized.contentMaxWidth != nil {
            classes.append("om-print-limit-width")
        }
        if normalized.themeMode == .defaultPrint {
            classes.append("om-print-default-theme")
        }

        return classes
    }
}
