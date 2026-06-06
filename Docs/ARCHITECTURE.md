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

- `OpenMarkedApp`: executable target containing the native SwiftUI app shell and packaged as the `OpenMarked` product.
- `OpenMarkedCore`: library target for app-independent types and services.
- `CMarkdownGFM`: C shim target that links against the system `libcmark-gfm`.
- `OpenMarkedVerifier`: executable target for local smoke and release verification.
- `OpenMarkedSnapshotter`: executable target for WebKit visual snapshots and PDF/export artifact checks.
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

## App Lifecycle Direction

OpenMarked is a SwiftUI app with an AppKit delegate for macOS-specific lifecycle behavior.

Lifecycle behavior:

- `OpenMarkedApplication` owns the SwiftUI window group, settings scene, and command definitions.
- `AppDelegate` handles file-open events from Finder/Dock and session restoration after launch.
- The delegate explicitly sets the activation policy to `.regular` and activates the app at launch so SwiftPM and packaged builds behave like normal foreground Mac apps with a visible menu bar.
- SwiftUI commands preserve standard macOS app/window behavior while adding Markdown-specific menu items for open, reload, search, outline, theme, source actions, export, print, settings, and About.

## Theme Direction

Phase 5 theme assets live under `Sources/OpenMarkedCore/Resources/Themes`. During SwiftPM development they load through `Bundle.module`; packaged app builds copy the resource bundle under `Contents/Resources`, and `PreviewThemeStore` checks that conventional app-bundle location first.

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
- Render diagnostics are exposed through a status-bar popover. Missing-image, missing-link, heading-fragment, malformed-link, unsupported-scheme, and skipped link checks are grouped by kind so warnings stay scannable.
- Status statistics stay compact in the bar and recompute with the current reading settings. The Statistics inspector expands the same inspection data into metric tiles, heading-level counts, section word/paragraph counts, longest section, and estimated printable pages.

## Link Validation Direction

Phase 2 of 0.3.0 keeps link validation local-first and render-pipeline owned.

Link validation behavior:

- `LinkReferenceExtractor` reads rendered anchor tags, so code examples are ignored.
- Local file links resolve relative to the source document directory.
- Same-document fragments validate against the final renderer heading IDs.
- Cross-document Markdown heading fragments are inspected only for local, readable, size-limited target files.
- Remote HTTP(S) links are parsed but not crawled during normal rendering.
- Unsupported schemes and malformed URLs produce diagnostics without interrupting preview.

## Rich Content Resource Direction

Phases 3 through 5 of 0.3.0 establish the bundled rich-content resource pipeline, Mermaid rendering path, and KaTeX math rendering path.

Rich content behavior:

- Mermaid `11.15.0` and KaTeX `0.17.0` are vendored as SwiftPM resources with local license/version metadata.
- `RichContentAssetStore` is the only code path that should resolve rich assets; it supports both source-tree paths and SwiftPM's flattened processed-resource layout.
- `HTMLDocumentAssembler` conditionally adds OpenMarked rich CSS and KaTeX CSS/font references when the detected, enabled document features require them.
- `PreviewWebView`, PDF/print export, and `OpenMarkedSnapshotter` call `RichContentWebViewRuntime.installAndWait` after sanitized HTML loads.
- Standalone HTML export embeds the same trusted local runtime assets after sanitization, while user-authored document scripts remain removed.
- `MermaidPostProcessor` replaces Mermaid code fences with stable figure placeholders before syntax highlighting, preserving source text for diagnostics and offline export.
- The OpenMarked runtime renders Mermaid placeholders to SVG with the bundled Mermaid library and reports inline/runtime failures through the shared rich-content status result.
- `MathPostProcessor` scans rendered HTML text nodes for inline `$...$` and display `$$...$$` math, skipping protected tags, links, and existing rich-content containers.
- The OpenMarked runtime renders math placeholders with bundled KaTeX, `trust: false`, and `htmlAndMathml` output. Invalid TeX receives a low-noise inline fallback and runtime status error.

## Export Direction

Phase 8 keeps export document assembly in `OpenMarkedCore` and platform workflows in `OpenMarkedApp`.

Export behavior:

- Standalone HTML export uses `HTMLExportDocumentBuilder`, sanitizes the same scripts/event handlers as preview, preserves the current theme CSS, embeds local images as data URLs by default, and injects trusted bundled rich-content runtime scripts when Mermaid or math output requires them.
- Copy Rendered HTML copies the rendered body fragment to both HTML and plain-text pasteboard flavors.
- PDF export and Print use an offscreen `WKWebView` loaded with the current standalone HTML and AppKit print operations, so print CSS applies through the native print pipeline and rich content is rendered before capture/print.
- Save-panel cancellation is treated as a no-op. Write/PDF failures use `ExportError` and show a short native alert plus status-bar feedback.
- Automated smoke coverage validates standalone HTML structure, image embedding, and export writing. PDF remains covered by build/smoke launch and manual visual inspection because robust PDF visual assertions are out of scope for the MVP.

## Settings And Polish Direction

Phase 9 keeps persistent preferences in `OpenMarkedCore` and applies them from the app coordinator to the active document window.

Settings behavior:

- `ApplicationSettings` is a small codable value that stores preview defaults, content policy, export defaults, live preview behavior, reading statistics preferences, scroll preservation, and optional session restoration.
- `ApplicationSettingsStore` persists settings and last-opened document paths through `UserDefaults`, with normalization for unknown themes, out-of-range font scales, and out-of-range reading-speed values.
- `MarkdownRenderProfile` is stored with settings and passed through `RenderOptions`; the default OpenMarked profile preserves current behavior, while the GitHub README profile switches heading slug generation and profile-aware heading-link validation.
- Rich Markdown toggles for Mermaid, KaTeX, GitHub callouts, and link validation live in `RichMarkdownOptions` and re-render the active document when changed.
- Current documents re-render when content policy, rich Markdown settings, render profile, or preview defaults change. Theme and zoom only update from defaults when those specific defaults changed.
- `DocumentWindowState.richContentPreview` tracks pending, rendering, ready, and failed rich-content runtime states separately from live-preview file watching.
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

Phase 10 keeps distribution lightweight and reproducible while the project is still pre-notarization.

Distribution behavior:

- `Scripts/verify_release.sh` runs the automated release gate: debug build, app product build, release build, verifier, performance smoke, visual snapshots, PDF/export artifact checks, SwiftPM tests, package metadata, diff hygiene, ASCII scan, packaging, signing, ZIP creation, and DMG creation.
- `Scripts/package_release.sh` wraps the SwiftPM release executable into `dist/OpenMarked-0.3.0/OpenMarked.app`, copies the SwiftPM resource bundle under `Contents/Resources`, verifies bundled rich-content resources are present, writes Info.plist metadata from `Packaging/Info.plist.template`, signs the bundle, and creates `dist/OpenMarked-0.3.0-macOS.zip` plus `dist/OpenMarked-0.3.0-macOS.dmg`.
- Release notes live in `RELEASE_NOTES.md`; the owner gate and tag instructions live in `Docs/RELEASE.md`; the manual pass lives in `Docs/QA.md`.
- Artifacts are ad hoc signed by default and not notarized unless Developer ID credentials are supplied through environment variables.

Later phases can add:

- Developer ID signing.
- Notarization.
- Sparkle or another update mechanism.
- Homebrew Cask.
