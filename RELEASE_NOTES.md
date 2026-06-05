# OpenMarked 0.1.0

OpenMarked 0.1.0 is the first MVP release candidate for an open source, native macOS Markdown previewer.

## Highlights

- Native macOS app shell with a regular app menu bar, standard app/window commands, file open, drag/drop, Dock file opening, recent documents, toolbar controls, Markdown-specific menus, and keyboard shortcuts.
- CommonMark and GitHub Flavored Markdown rendering through `cmark-gfm`, including tables, strikethrough, task lists, autolinks, and footnotes.
- Heading IDs, outline navigation, outline filtering, rendered-preview search, document statistics, and diagnostics.
- Built-in Default, GitHub, and Minimal themes with print CSS and offline code highlighting.
- WKWebView preview with document-relative assets, external link handling, scroll preservation, and script/event-handler sanitization.
- Live preview for source edits, atomic replacement saves, and local image asset changes.
- Standalone HTML export, copy rendered HTML, PDF export, and native Print.
- Settings for preview defaults, content policy, export defaults, live updates, scroll preservation, and optional session restoration.
- Accessibility labels for primary controls and states, plus reduced-motion-aware preview navigation.

## Supported Files

OpenMarked supports Markdown and text files with these extensions: `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.txt`, and `.text`.

## Installation

The developer ZIP artifact is created by:

```sh
Scripts/package_release.sh
```

The resulting file is `dist/OpenMarked-0.1.0-macOS.zip`. Expand it and move `OpenMarked.app` to Applications if desired.

This MVP artifact is ad hoc signed but not notarized. On macOS, Gatekeeper may require opening it from Finder's context menu. Only run local developer artifacts from sources you trust.

## Known Limitations

- The app is not notarized and does not yet ship as a DMG or Homebrew Cask.
- PDF and print output use WebKit/AppKit and should be visually checked before publishing release artifacts.
- Custom themes, plugin processors, DOCX/EPUB export, RTF/RTFD import, Scrivener project rendering, browser integrations, grammar tools, and AI features are deferred.
- Automated visual regression coverage is not yet implemented.

## Reporting Issues

Use the GitHub issue templates for bug reports, rendering issues, and feature requests. Rendering bugs are most useful with a minimal Markdown sample and any local assets needed to reproduce the output.
