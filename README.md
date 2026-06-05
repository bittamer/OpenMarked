# OpenMarked

OpenMarked is an open source, native macOS Markdown previewer and publishing companion.

The project is currently past Phase 1: native app shell. The first MVP is focused on a beautiful local Markdown preview experience, reliable CommonMark/GitHub Flavored Markdown rendering, file watching, document navigation, built-in themes, and HTML/PDF export.

## Current Status

This repository currently contains:

- Product design: `DESIGN.md`.
- MVP implementation plan: `MVP_IMPLEMENTATION_PLAN.md`.
- Roadmap: `ROADMAP.md`.
- Swift Package based native macOS app shell.
- App/window state models for empty, loading, loaded, and error states.
- File open panel, drag/drop file opening, Dock file opening, and recent-document registration.
- Native menu commands and a toolbar mapped to Phase 1 shell actions.
- Core test target.
- Markdown fixture corpus.
- CI workflow for Swift build and tests.

The app shell is intentionally minimal. File opening, rendering, live preview, themes, navigation, and export are implemented in later MVP phases.

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
