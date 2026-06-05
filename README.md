# OpenMarked

OpenMarked is an open source, native macOS Markdown previewer and publishing companion.

The project is currently through Phase 9: settings, accessibility, and polish. The first MVP is focused on a beautiful local Markdown preview experience, reliable CommonMark/GitHub Flavored Markdown rendering, file watching, document navigation, built-in themes, HTML/PDF export, and a small set of persistent user preferences.

## Current Status

This repository currently contains:

- Product design: `DESIGN.md`.
- MVP implementation plan: `MVP_IMPLEMENTATION_PLAN.md`.
- Roadmap: `ROADMAP.md`.
- Swift Package based native macOS app shell.
- App/window state models for empty, loading, loaded, and error states.
- File open panel, drag/drop file opening, Dock file opening, and recent-document registration.
- Native menu commands and a toolbar mapped to Phase 1 shell actions.
- Markdown document loading with UTF-8 decoding, line-ending normalization, front matter parsing, source statistics, security-scoped bookmark helpers, and per-document window state persistence.
- Markdown rendering core backed by the system `libcmark-gfm` library, with GFM extensions, footnotes, heading IDs, outline extraction, full HTML assembly, and render diagnostics.
- WKWebView preview loading with document-relative assets, outline navigation, scroll preservation on reload, external-link handling, and preview HTML script sanitization.
- Built-in preview themes, print CSS, font scaling, toolbar/menu theme switching, and offline pre-highlighted code blocks.
- Live preview for external source edits, atomic save replacement, missing-file feedback, local image asset watching, debounce/coalescing, and subtle update status.
- Outline filtering, rendered-preview search, richer status statistics, diagnostics popover, and source file actions.
- Standalone HTML export, copy rendered HTML, PDF export, print, and export error handling.
- A native Settings window for preview defaults, content loading, export defaults, live preview, scroll preservation, and session restoration.
- Keyboard shortcuts for core document, preview, navigation, zoom, search, export, and print actions.
- Accessibility labels for primary controls and states, plus reduced-motion handling for preview navigation/search scrolling.
- Core test target.
- Markdown fixture corpus.
- CI workflow for Swift build and tests.

Packaging, signing, notarization, release automation, and final visual QA are implemented in later MVP phases.

## Platform

- Minimum macOS target: macOS 13.0.
- Language: Swift.
- UI direction: SwiftUI with AppKit where native macOS document/window behavior needs it.
- Preview direction: WKWebView.
- Markdown renderer direction: cmark-gfm behind a Swift abstraction.

## Build and Test

Use Swift Package Manager:

```sh
swift build
swift run OpenMarkedVerifier
swift test
```

Open the package in Xcode by opening `Package.swift`.

Some Command Line Tools only environments do not expose `XCTest` or Swift Testing to SwiftPM. In that case, `swift run OpenMarkedVerifier` provides the Phase 0 local smoke verification, while CI should run `swift test` on a full Xcode runner.

## Usage

Launch the app from Xcode or with SwiftPM, then open one or more Markdown files with File > Open, the toolbar open button, drag and drop, Dock file opening, or Open Recent. Supported source extensions are `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, and `.txt`.

OpenMarked renders CommonMark plus GitHub Flavored Markdown tables, strikethrough, task lists, autolinks, and footnotes through `cmark-gfm`. It adds stable heading IDs, an outline sidebar, local-image diagnostics, document statistics, and offline code highlighting for common MVP languages.

Live preview watches the source file and local image references, including common atomic-save workflows. Use View/toolbar controls to toggle the outline, search the rendered preview, change theme, zoom text, reveal the source in Finder, or open the source in the default editor.

Export supports standalone HTML, copying the rendered HTML fragment, PDF export, and native Print. HTML export can embed local images and theme CSS according to Settings.

## Settings And Privacy

Settings are available from the app menu and persist with `UserDefaults`. Current preferences cover default theme, default font scale, live updates, scroll preservation, remote image loading, raw HTML rendering, HTML export CSS embedding, local image embedding, and optional restoration of last opened documents.

OpenMarked is designed as a local-first viewer. It does not send document contents to a service. Remote images are loaded only when the setting is enabled; remote scripts and inline event handlers are blocked in preview HTML. Last opened document paths are saved only when session restoration is enabled by the user.

## Known Limitations

The MVP does not yet ship as a signed `.app` bundle, notarized DMG, or Homebrew Cask. PDF and print output use WebKit/AppKit and still need final visual QA across themes. Custom themes, plugin processors, DOCX/EPUB export, grammar tools, and browser integrations are intentionally deferred.

## Feedback

Use the GitHub issue templates for [bug reports](.github/ISSUE_TEMPLATE/bug_report.md), [rendering issues](.github/ISSUE_TEMPLATE/rendering_issue.md), and [feature requests](.github/ISSUE_TEMPLATE/feature_request.md). Rendering issues are most useful with a small Markdown sample and any local assets needed to reproduce the output.

## MVP Non-Goals

These are intentionally deferred until after the core preview app works well:

- DOCX import/export.
- EPUB export.
- RTF/RTFD import.
- Scrivener project rendering.
- Browser extensions.
- Web page to Markdown conversion.
- Full custom processor/rule engine.
- Plugin API.
- Grammar checking.
- AI features.

## License

OpenMarked is licensed under the GNU General Public License v3.0. See `LICENSE`.
