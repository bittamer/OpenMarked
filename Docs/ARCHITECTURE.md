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

## Navigation Direction

Phase 7 keeps document navigation native where possible and preview-specific behavior inside `PreviewWebView`.

Navigation behavior:

- The outline sidebar renders the renderer-provided heading list, filters headings through `OutlineFilter`, and sends heading IDs to the WebView navigation bridge.
- Preview search uses a small injected JavaScript helper rather than relying on WebKit find APIs, so highlighting and next/previous behavior are predictable on the MVP deployment target.
- Source actions are native AppKit operations: reveal in Finder, open in the default editor, copy path, and reload from disk.
- Render diagnostics are exposed through a status-bar popover. Missing-image warnings are descriptive even when no exact preview location is available.
- Status statistics stay compact in the bar, with character and line counts available through tooltips.

## Export Direction

Phase 8 keeps export document assembly in `OpenMarkedCore` and platform workflows in `OpenMarkedApp`.

Export behavior:

- Standalone HTML export uses `HTMLExportDocumentBuilder`, sanitizes the same scripts/event handlers as preview, preserves the current theme CSS, and embeds local images as data URLs by default.
- Copy Rendered HTML copies the rendered body fragment to both HTML and plain-text pasteboard flavors.
- PDF export and Print use an offscreen `WKWebView` loaded with the current standalone HTML and AppKit print operations, so print CSS applies through the native print pipeline.
- Save-panel cancellation is treated as a no-op. Write/PDF failures use `ExportError` and show a short native alert plus status-bar feedback.
- Automated smoke coverage validates standalone HTML structure, image embedding, and export writing. PDF remains covered by build/smoke launch and manual visual inspection because robust PDF visual assertions are out of scope for the MVP.

## Settings And Polish Direction

Phase 9 keeps persistent preferences in `OpenMarkedCore` and applies them from the app coordinator to the active document window.

Settings behavior:

- `ApplicationSettings` is a small codable value that stores preview defaults, content policy, export defaults, live preview behavior, scroll preservation, and optional session restoration.
- `ApplicationSettingsStore` persists settings and last-opened document paths through `UserDefaults`, with normalization for unknown themes and out-of-range font scales.
- Current documents re-render when content policy or preview defaults change, while newly opened documents use the normalized default layout unless a per-document layout was restored.
- Reduced-motion preferences are read from SwiftUI environment and passed into `PreviewWebView`, which switches smooth scrolling helpers to immediate scrolling.
- Remote images can be disabled before preview/export assembly by rewriting remote image sources to inert placeholders while retaining the original URL in a diagnostic attribute.
- Accessibility polish is kept mostly in SwiftUI view declarations: primary toolbar controls, settings, empty/error states, and picker/search controls expose labels or native labels.

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
