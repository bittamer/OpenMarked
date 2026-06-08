import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageAssetMetadata: Equatable, Sendable {
    public let byteSize: Int64?
    public let pixelWidth: Int?
    public let pixelHeight: Int?
    public let fileSize: Int64
    public let modifiedAt: TimeInterval?
    public let fileID: UInt64?

    public init(
        byteSize: Int64?,
        pixelWidth: Int?,
        pixelHeight: Int?,
        fileSize: Int64,
        modifiedAt: TimeInterval?,
        fileID: UInt64?
    ) {
        self.byteSize = byteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.fileID = fileID
    }
}

public final class ImageAssetMetadataCache: @unchecked Sendable {
    public static let shared = ImageAssetMetadataCache()

    private let lock = NSLock()
    private var cache: [ImageAssetMetadataKey: ImageAssetMetadata] = [:]

    public init() {}

    public func metadata(for url: URL) -> ImageAssetMetadata? {
        let standardizedURL = url.standardizedFileURL
        guard let key = ImageAssetMetadataKey(url: standardizedURL) else {
            return nil
        }

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let dimensions = rasterDimensions(for: standardizedURL) ?? svgDimensions(for: standardizedURL)
        let metadata = ImageAssetMetadata(
            byteSize: key.fileSize,
            pixelWidth: dimensions?.width,
            pixelHeight: dimensions?.height,
            fileSize: key.fileSize,
            modifiedAt: key.modifiedAt,
            fileID: key.fileID
        )

        lock.lock()
        cache[key] = metadata
        lock.unlock()
        return metadata
    }

    public func removeAll() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    private func rasterDimensions(for url: URL) -> (width: Int, height: Int)? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }

        return (width.intValue, height.intValue)
    }

    private func svgDimensions(for url: URL) -> (width: Int, height: Int)? {
        guard url.pathExtension.lowercased() == "svg",
              let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              let text = String(data: data.prefix(4096), encoding: .utf8),
              let width = svgNumericAttribute("width", in: text),
              let height = svgNumericAttribute("height", in: text) else {
            return nil
        }

        return (width, height)
    }

    private func svgNumericAttribute(_ attribute: String, in text: String) -> Int? {
        let pattern = #"\b\#(attribute)\s*=\s*["']([0-9]+)(?:\.[0-9]+)?(?:px)?["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Int(text[range])
    }
}

private struct ImageAssetMetadataKey: Hashable {
    let path: String
    let fileSize: Int64
    let modifiedAt: TimeInterval?
    let fileID: UInt64?

    init?(url: URL, fileManager: FileManager = .default) {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = (attributes[.size] as? NSNumber)?.int64Value else {
            return nil
        }

        self.path = url.standardizedFileURL.path
        self.fileSize = fileSize
        self.modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970
        self.fileID = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
    }
}

public enum ImageAttributePostProcessor {
    public static func process(_ html: String, document: MarkdownDocument) -> String {
        let pattern = #"<img\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return html
        }

        var rendered = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
        for match in matches.reversed() {
            guard let tagRange = Range(match.range(at: 0), in: html) else {
                continue
            }

            let tag = String(html[tagRange])
            let processedTag = processTag(tag, document: document)
            rendered.replaceSubrange(tagRange, with: processedTag)
        }

        return rendered
    }

    private static func processTag(_ tag: String, document: MarkdownDocument) -> String {
        var attributes: [String] = []

        if !hasAttribute("loading", in: tag) {
            attributes.append(#"loading="lazy""#)
        }
        if !hasAttribute("decoding", in: tag) {
            attributes.append(#"decoding="async""#)
        }

        if let source = attributeValue(named: "src", in: tag),
           let imageURL = LocalAssetReferenceExtractor.localFileURL(
            for: source,
            relativeTo: document.sourceURL.deletingLastPathComponent()
           ),
           let metadata = ImageAssetMetadataCache.shared.metadata(for: imageURL) {
            if !hasAttribute("width", in: tag), let width = metadata.pixelWidth {
                attributes.append(#"width="\#(width)""#)
            }
            if !hasAttribute("height", in: tag), let height = metadata.pixelHeight {
                attributes.append(#"height="\#(height)""#)
            }
        }

        guard !attributes.isEmpty else {
            return tag
        }

        let insertion = " " + attributes.joined(separator: " ")
        if tag.hasSuffix("/>") {
            return String(tag.dropLast(2)) + insertion + " />"
        }
        return String(tag.dropLast()) + insertion + ">"
    }

    static func hasAttribute(_ name: String, in tag: String) -> Bool {
        let pattern = #"\b\#(name)\s*="#
        return tag.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func attributeValue(named name: String, in tag: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              let valueRange = Range(match.range(at: 2), in: tag) else {
            return nil
        }

        return HTMLUtilities.decodeEntities(in: String(tag[valueRange]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public final class PreviewImageCache: @unchecked Sendable {
    public static let shared = PreviewImageCache()

    private let fileManager: FileManager
    private let cacheDirectoryURL: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.cacheDirectoryURL = baseURL
            .appendingPathComponent("OpenMarked", isDirectory: true)
            .appendingPathComponent("PreviewImages", isDirectory: true)
    }

    public func optimizedHTMLForPreview(
        _ html: String,
        baseURL: URL,
        maxPixelWidth: Int = 1800
    ) -> String {
        let pattern = #"<img\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return html
        }

        var rendered = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
        for match in matches.reversed() {
            guard let tagRange = Range(match.range(at: 0), in: html) else {
                continue
            }

            let tag = String(html[tagRange])
            guard let optimizedTag = optimizedTag(tag, baseURL: baseURL, maxPixelWidth: maxPixelWidth) else {
                continue
            }

            rendered.replaceSubrange(tagRange, with: optimizedTag)
        }

        return rendered
    }

    private func optimizedTag(_ tag: String, baseURL: URL, maxPixelWidth: Int) -> String? {
        guard let source = ImageAttributePostProcessor.attributeValue(named: "src", in: tag),
              let imageURL = LocalAssetReferenceExtractor.localFileURL(for: source, relativeTo: baseURL),
              let optimizedURL = optimizedImageURL(for: imageURL, maxPixelWidth: maxPixelWidth),
              optimizedURL.standardizedFileURL.path != imageURL.standardizedFileURL.path else {
            return nil
        }

        let optimizedSource = HTMLUtilities.escapeAttribute(optimizedURL.absoluteString)
        let originalSource = HTMLUtilities.escapeAttribute(source)
        let pattern = #"(\bsrc\s*=\s*)(["'])(.*?)\2"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              let fullRange = Range(match.range(at: 0), in: tag),
              let prefixRange = Range(match.range(at: 1), in: tag),
              let quoteRange = Range(match.range(at: 2), in: tag) else {
            return nil
        }

        var updatedTag = tag
        let quote = String(tag[quoteRange])
        let replacement = "\(tag[prefixRange])\(quote)\(optimizedSource)\(quote)"
        updatedTag.replaceSubrange(fullRange, with: replacement)
        if !ImageAttributePostProcessor.hasAttribute("data-openmarked-original-src", in: updatedTag) {
            updatedTag = String(updatedTag.dropLast()) + #" data-openmarked-original-src="\#(originalSource)">"#
        }
        return updatedTag
    }

    private func optimizedImageURL(for sourceURL: URL, maxPixelWidth: Int) -> URL? {
        guard shouldOptimize(sourceURL),
              let metadata = ImageAssetMetadataCache.shared.metadata(for: sourceURL),
              let width = metadata.pixelWidth,
              let height = metadata.pixelHeight,
              max(width, height) > maxPixelWidth else {
            return nil
        }

        do {
            try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
            let extensionName = outputExtension(for: sourceURL)
            let cacheName = cacheKey(
                sourceURL: sourceURL,
                metadata: metadata,
                maxPixelWidth: maxPixelWidth
            )
            let destinationURL = cacheDirectoryURL
                .appendingPathComponent(cacheName)
                .appendingPathExtension(extensionName)

            if fileManager.fileExists(atPath: destinationURL.path) {
                return destinationURL
            }

            guard downsample(sourceURL: sourceURL, destinationURL: destinationURL, maxPixelWidth: maxPixelWidth) else {
                try? fileManager.removeItem(at: destinationURL)
                return nil
            }

            return destinationURL
        } catch {
            return nil
        }
    }

    private func shouldOptimize(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "tif", "tiff", "heic":
            return true
        default:
            return false
        }
    }

    private func downsample(sourceURL: URL, destinationURL: URL, maxPixelWidth: Int) -> Bool {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelWidth,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false
        ] as CFDictionary

        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, sourceOptions),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions),
              let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                outputTypeIdentifier(for: sourceURL) as CFString,
                1,
                nil
              ) else {
            return false
        }

        CGImageDestinationAddImage(destination, thumbnail, nil)
        return CGImageDestinationFinalize(destination)
    }

    private func outputTypeIdentifier(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return UTType.jpeg.identifier
        case "heic":
            return UTType.heic.identifier
        case "tif", "tiff":
            return UTType.tiff.identifier
        default:
            return UTType.png.identifier
        }
    }

    private func outputExtension(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "jpg"
        case "heic":
            return "heic"
        case "tif", "tiff":
            return "tiff"
        default:
            return "png"
        }
    }

    private func cacheKey(
        sourceURL: URL,
        metadata: ImageAssetMetadata,
        maxPixelWidth: Int
    ) -> String {
        let raw = [
            sourceURL.standardizedFileURL.path,
            String(metadata.fileSize),
            String(metadata.modifiedAt ?? 0),
            String(metadata.fileID ?? 0),
            String(maxPixelWidth)
        ].joined(separator: "|")
        return "om-\(fnv1a64(raw))"
    }

    private func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
