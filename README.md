# OpenMarked

![OpenMarked logo](Packaging/Assets/OpenMarkedLogo.svg)

OpenMarked is an open source, native macOS Markdown previewer and publishing companion.

The project is currently at `0.4.1`: OpenMarked is now a Document Workbench with a native inspector, front matter metadata, rich statistics, link and asset review, export readiness checks, custom CSS themes, print controls, repeatable visual QA, PDF/export artifact checks, ZIP/DMG packaging, and optional Developer ID/notarization hooks. The 0.4.1 patch adds the app icon/logo release polish and hardens PDF export.

## Current Status

This repository currently contains:

- Product design: `DESIGN.md`.
- Logo SVG and packaged macOS app icon: `Packaging/Assets/OpenMarkedLogo.svg` and `Packaging/Assets/OpenMarkedIcon.icns`.
- MVP implementation plan: `Docs/MVP_IMPLEMENTATION_PLAN.md`.
- 0.3.0 Markdown Power Pack plan: `Docs/0.3.0_IMPLEMENTATION_PLAN.md`.
- 0.3.0 backlog tracker: `Docs/0.3.0_BACKLOG.md`.
- 0.4.0 Document Workbench plan: `Docs/0.4.0_IMPLEMENTATION_PLAN.md`.
- 0.4.0 backlog tracker: `Docs/0.4.0_BACKLOG.md`.
- Document inspector guide: `Docs/DOCUMENT_INSPECTOR.md`.
- Custom themes guide: `Docs/CUSTOM_THEMES.md`.
- Print and export guide: `Docs/PRINT_AND_EXPORT.md`.
- Rich Markdown guide: `Docs/RICH_MARKDOWN.md`.
- Rich content dependency policy: `Docs/RICH_CONTENT_DEPENDENCIES.md`.
- Link validation behavior: `Docs/LINK_VALIDATION.md`.
- Roadmap: `ROADMAP.md`.
- Swift Package based native macOS app shell.
- App/window state models for empty, loading, loaded, and error states.
- File open panel, drag/drop file opening, Dock file opening, and recent-document registration.
- Native macOS menu bar, standard app/window commands such as Quit, document commands, keyboard shortcuts, and a compact toolbar.
- Markdown document loading with UTF-8 decoding, line-ending normalization, front matter parsing, source statistics, security-scoped bookmark helpers, and per-document window state persistence.
- Markdown rendering core backed by the system `libcmark-gfm` library, with GFM extensions, footnotes, heading IDs, outline extraction, full HTML assembly, and render diagnostics.
- GitHub alert/callout rendering for note, tip, important, warning, and caution blockquotes.
- Local link, heading-fragment, cross-document heading, malformed URL, and unsupported-scheme diagnostics.
- Offline Mermaid diagram and KaTeX math rendering using bundled local assets rather than CDN dependencies.
- Native document inspector with Summary, Metadata, Links, Assets, Diagnostics, Statistics, and Export Readiness sections.
- YAML, TOML, and JSON front matter inspection with normalized standard fields, custom fields, title source, and file facts.
- Rich statistics for words, characters, lines, reading time, estimated pages, headings, sections, links, images, missing references, code blocks, tables, footnotes, callouts, Mermaid diagrams, KaTeX math, wide table candidates, and diagnostics.
- Export readiness checks for missing links/assets, malformed or unsupported links, remote images, blocked remote images, rich-content failures, malformed front matter, wide tables, and multi-page export review.
- WKWebView preview loading with document-relative assets, outline navigation, scroll preservation on reload, external-link handling, and preview HTML script sanitization.
- Ten built-in preview themes - Default, GitHub, Minimal, plus popular palettes (Catppuccin, Tokyo Night, Everforest, Nord, Rose Pine, Dracula, Gruvbox), each with light and dark variants - alongside print CSS, font scaling, toolbar/menu theme switching, and offline pre-highlighted code blocks.
- Custom preview themes through a native Theme Manager, with local CSS import, built-in theme duplication, rename/delete/reveal actions, a live preview gallery, safe CSS validation, and fallback behavior for missing or unsafe user CSS.
- Separate app chrome themes for the OpenMarked window shell, with palette choices for Catppuccin, Tokyo Night, Everforest, Nord, Rose Pine, Dracula, and Gruvbox.
- Live preview for external source edits, atomic save replacement, missing-file feedback, local image asset watching, debounce/coalescing, and subtle update status.
- Outline filtering, current-section highlighting, rendered-preview search, richer status statistics, diagnostics popover, and source file actions.
- Standalone HTML export, copy rendered HTML, PDF export, native print, repeat export to the previous per-document destination, and export error handling.
- Print controls for page size, margins, content width, heading page breaks, print-only document title, and preview-theme vs. Default print CSS.
- A native Settings window for app appearance, preview defaults, render profile, rich Markdown controls, link validation, content loading, print controls, export defaults, live preview, scroll preservation, and session restoration.
- Keyboard shortcuts for core document, preview, navigation, zoom, search, export, and print actions.
- Accessibility labels for primary controls and states, plus reduced-motion handling for preview navigation/search scrolling.
- Manual QA checklist, release notes, release gate notes, performance smoke coverage, WebKit screenshot baselines for preview, inspector, and settings surfaces, PDF/export artifact checks, and a developer packaging script that creates `OpenMarked.app`, a ZIP artifact, and a DMG.
- Core test target.
- Markdown fixture corpus.
- CI workflow for Swift build, verifier, visual snapshots, export artifacts, and tests.

Signing credentials, notarization, Homebrew Cask, and strict hash-based visual regression enforcement are deferred beyond `0.4.1`. The packaging script supports Developer ID signing and notarization when credentials are available.

## Screenshots

![Default theme preview](Docs/Screenshots/visual-qa/default-readme-light.png)

![GitHub theme with GFM](Docs/Screenshots/visual-qa/github-gfm-light.png)

![GitHub rich Markdown light](Docs/Screenshots/visual-qa/github-rich-markdown-light.png)

![GitHub rich Markdown dark](Docs/Screenshots/visual-qa/github-rich-markdown-dark.png)

![Minimal prose theme](Docs/Screenshots/visual-qa/minimal-prose-light.png)

![Fixture user CSS theme](Docs/Screenshots/visual-qa/user-fixture-theme-gfm-light.png)

![Inspector summary](Docs/Screenshots/visual-qa/inspector-summary-light.png)

![Inspector diagnostics](Docs/Screenshots/visual-qa/inspector-diagnostics-dark.png)

![Theme manager](Docs/Screenshots/visual-qa/settings-theme-manager-light.png)

![Print controls](Docs/Screenshots/visual-qa/settings-print-controls-light.png)

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

Some Command Line Tools only environments do not expose `XCTest` or Swift Testing to SwiftPM. In that case, `swift run OpenMarkedVerifier` provides the local smoke verification, while CI should run `swift test` on a full Xcode runner.

For the full release gate:

```sh
Scripts/verify_release.sh
```

## Developer Packaging

Create a local developer artifact with:

```sh
Scripts/package_release.sh
```

The script builds Release configuration, wraps the executable in `dist/OpenMarked-0.4.1/OpenMarked.app`, copies SwiftPM resources, verifies packaged rich-content resources, signs the bundle, verifies the signature, and creates `dist/OpenMarked-0.4.1-macOS.zip` plus `dist/OpenMarked-0.4.1-macOS.dmg`.

By default the app is ad hoc signed. Set `OPENMARKED_SIGN_IDENTITY` to use a Developer ID certificate. Set `OPENMARKED_NOTARIZE=1` with `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD` to submit the DMG for notarization.

These artifacts are not notarized by default. Gatekeeper behavior is documented in `Docs/RELEASE.md` and `RELEASE_NOTES.md`.

## Usage

Launch the app from Xcode, SwiftPM, or the packaged app. Open one or more Markdown files with File > Open, the toolbar open button, drag and drop, Dock file opening, or Open Recent. When OpenMarked is focused, macOS shows the OpenMarked menu bar with standard commands such as About, Settings, Hide, Quit, Window actions, and the app's Markdown-specific commands. Supported source extensions are `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.txt`, and `.text`.

OpenMarked renders CommonMark plus GitHub Flavored Markdown tables, strikethrough, task lists, autolinks, footnotes, GitHub alert/callout blockquotes, Mermaid diagrams, and KaTeX math through `cmark-gfm` plus OpenMarked postprocessing. It adds stable heading IDs, an outline sidebar, local-image and link diagnostics, document statistics, and offline code highlighting for common MVP languages.

OpenMarked bundles local Mermaid `11.15.0` and KaTeX `0.17.0` resources. Mermaid and KaTeX render offline in preview, PDF/print, snapshots, and standalone HTML export. Supported math delimiters are inline `$...$` and display `$$...$$`; escaped dollars, common currency text, code spans/fences, and link text are kept literal. See `Docs/RICH_MARKDOWN.md` for supported syntax and troubleshooting.

Live preview watches the source file and local image references, including common atomic-save workflows. Use View/toolbar controls to toggle the outline, show the inspector, search the rendered preview, change theme, zoom text, reveal the source in Finder, or open the source in the default editor.

The inspector helps review the active document without leaving the preview. It shows resolved title metadata, front matter fields, file facts, links, images/assets, diagnostics, richer statistics, and export readiness. Inspection stays local-first: remote links are not crawled and remote images are reported without background fetching.

Export supports standalone HTML, copying the rendered HTML fragment, PDF export, native Print, and repeat HTML/PDF export to the previous per-document destination. HTML export can embed local images and theme CSS according to Settings, and rich standalone HTML embeds the trusted local Mermaid/KaTeX runtime needed to render diagrams and math offline. Print controls cover page size, margins, content width, heading page breaks, a print-only document title, and preview-theme versus Default print styling.

## Settings And Privacy

Settings are available from the app menu and persist with `UserDefaults`. Current preferences cover render profile, default theme, custom user themes, app chrome theme, default font scale, reading statistics, live updates, scroll preservation, remote image loading, raw HTML rendering, Mermaid, KaTeX, GitHub callouts, local/heading/remote link reporting, print controls, HTML export CSS embedding, local image embedding, and optional restoration of last opened documents.

OpenMarked is designed as a local-first viewer. It does not send document contents to a service. Remote images are loaded only when the setting is enabled; remote scripts and inline event handlers are blocked in preview HTML. Link validation does not crawl remote URLs during normal rendering. Custom themes are local CSS only, with `@import`, `javascript:` URLs, and embedded script/style tags blocked. Last opened document paths are saved only when session restoration is enabled by the user.

## Known Limitations

The `0.4.1` developer artifact is ad hoc signed but not notarized unless Developer ID credentials are supplied. It does not yet ship as a Homebrew Cask. Folder workspaces, backlinks, plugin processors, DOCX/EPUB export, grammar tools, browser integrations, and AI features are intentionally deferred.

## Feedback

Use the GitHub issue templates for [bug reports](.github/ISSUE_TEMPLATE/bug_report.md), [rendering issues](.github/ISSUE_TEMPLATE/rendering_issue.md), and [feature requests](.github/ISSUE_TEMPLATE/feature_request.md). Rendering issues are most useful with a small Markdown sample and any local assets needed to reproduce the output. See [diagnostics guidance](Docs/DIAGNOSTICS.md) before sharing logs or crash reports.

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
