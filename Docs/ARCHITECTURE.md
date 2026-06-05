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

Phase 3 renderer:

- `CMarkGFMRenderer` implements the `MarkdownRenderer` protocol.
- `CMarkdownGFM` is a tiny local C shim that links against the system `libcmark-gfm` library exposed by the macOS SDK.
- GFM extensions are enabled through cmark-gfm's core extension registry.
- Heading IDs, outline extraction, full HTML assembly, and diagnostics are handled in Swift after cmark-gfm produces the HTML fragment.

The renderer is wrapped behind a Swift protocol so future engines can be evaluated without rewriting the app shell.

## Preview Direction

Phase 4 uses a SwiftUI `NSViewRepresentable` wrapper around `WKWebView`.

Preview behavior:

- Rendered HTML is loaded with the source document directory as the base URL so relative assets can resolve.
- The native outline sends heading IDs to the preview through a small JavaScript bridge.
- The WebView captures approximate scroll ratio before reload and restores it after the new HTML finishes loading.
- Link clicks are intercepted: external and local file URLs open through `NSWorkspace` instead of replacing the preview.
- Script tags and inline event handler attributes are stripped before loading preview HTML. Bundled JavaScript needed for preview mechanics is injected through `evaluateJavaScript`, which keeps user document scripts blocked by default.

## Theme Direction

Phase 5 theme assets live under `Sources/OpenMarkedCore/Resources/Themes` and are loaded through `Bundle.module`.

Built-in themes:

- Default: editorial reading style with light and dark variants.
- GitHub: README-oriented style approximating common repository documents without copying proprietary assets.
- Minimal: restrained print-friendly style.

The renderer injects screen CSS, code CSS, print CSS, `--om-font-scale`, and `--om-content-max-width` into the assembled HTML. Code blocks are pre-highlighted in Swift for common MVP languages so preview and future exports work offline without remote scripts.

## Live Preview Direction

Phase 6 uses `FileSystemWatcher` in `OpenMarkedCore` for debounced file-system events.

Live preview behavior:

- The source Markdown file is watched with a direct file descriptor plus a parent-directory watcher so normal saves and atomic replacement saves are both detected.
- Source changes reload the document, skip duplicate source text, render once, preserve scroll through the existing WebView reload path, and do not activate or steal focus from other apps.
- Local image references are extracted from rendered HTML and watched separately, including missing images whose parent directory exists.
- Missing, moved, or unreadable source files leave the window open and show preview/update failure feedback instead of crashing or replacing the whole window state.
- Watchers are restarted when documents reload and stopped when windows close.

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
