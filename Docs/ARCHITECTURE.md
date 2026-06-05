# Architecture Decisions

## Phase 0 Decision Summary

OpenMarked starts as a Swift Package based macOS app skeleton.

This choice keeps the project easy to build in command-line and CI environments while still allowing contributors to open `Package.swift` directly in Xcode. A dedicated `.xcodeproj` or `.xcworkspace` can be introduced later if packaging, signing, asset catalogs, or advanced app lifecycle needs require it.

## Minimum macOS Target

The MVP targets macOS 13.0 or newer.

Reasons:

- Modern SwiftUI app structure is available.
- WKWebView is mature for preview rendering.
- The target avoids early complexity from supporting older SwiftUI behavior.
- macOS 13 remains broad enough for an open source desktop utility MVP.

## Build Structure

Current package targets:

- `OpenMarkedApp`: executable target containing the native SwiftUI app shell.
- `OpenMarkedCore`: library target for app-independent types and services.
- `OpenMarkedCoreTests`: XCTest target for core behavior.

Planned package/module boundaries:

- `DocumentCore`: source document model, metadata, file access, bookmarks, restoration.
- `MarkdownEngine`: Markdown renderer abstraction and cmark-gfm implementation.
- `PreviewEngine`: HTML assembly, asset resolution, WKWebView coordination.
- `ThemeKit`: built-in themes, custom CSS loading, print CSS.
- `FileWatching`: file/folder watchers and debounce logic.
- `ExportKit`: HTML/PDF export and future export adapters.

For Phase 0, these are documented rather than all created as empty modules. Modules should be added when there is real code to place inside them.

## Rendering Direction

The MVP will render Markdown to HTML and display it in `WKWebView`.

Recommended renderer for Phase 3:

- `cmark-gfm` for CommonMark and GitHub Flavored Markdown compatibility.

The renderer must be wrapped behind a Swift protocol so future engines can be evaluated without rewriting the app shell.

## Sandboxing Direction

OpenMarked should be designed for sandboxed file access:

- User-selected files should use security-scoped access.
- Document-relative assets should be resolved carefully.
- Remote scripts should be blocked by default.
- Remote image loading should be controlled by a setting.

Even if early local builds are not sandboxed, sandbox assumptions should shape the code from the beginning.

## Distribution Direction

Phase 0 verifies with Swift Package Manager:

```sh
swift build
swift test
```

Later phases can add:

- App bundle packaging.
- Code signing.
- Notarization.
- DMG creation.
- Homebrew Cask.

