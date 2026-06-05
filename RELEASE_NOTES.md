# OpenMarked 0.2.0

OpenMarked 0.2.0 hardens the MVP release with visual QA, export verification, screenshots, and improved packaging.

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
- WebKit screenshot baselines for built-in themes, GFM tables/code, local images, and dark mode.
- Automated PDF/export artifact verification.
- ZIP and DMG developer artifacts.
- Optional Developer ID signing and notarization hooks in `Scripts/package_release.sh`.

## Supported Files

OpenMarked supports Markdown and text files with these extensions: `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.txt`, and `.text`.

## Installation

The developer artifacts are created by:

```sh
Scripts/package_release.sh
```

The resulting files are `dist/OpenMarked-0.2.0-macOS.zip` and `dist/OpenMarked-0.2.0-macOS.dmg`.

These developer artifacts are ad hoc signed by default but not notarized unless Apple signing credentials are supplied. On macOS, Gatekeeper may require opening them from Finder's context menu. Only run local developer artifacts from sources you trust.

## Known Limitations

- The app is not notarized by default and does not yet ship as a Homebrew Cask.
- Native print panel behavior should be checked manually before publishing public release artifacts.
- Custom themes, plugin processors, DOCX/EPUB export, RTF/RTFD import, Scrivener project rendering, browser integrations, grammar tools, and AI features are deferred.
- Automated visual regression coverage is not yet implemented.

## Reporting Issues

Use the GitHub issue templates for bug reports, rendering issues, and feature requests. Rendering bugs are most useful with a minimal Markdown sample and any local assets needed to reproduce the output.
