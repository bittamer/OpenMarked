# OpenMarked 0.5.0

OpenMarked 0.5.0 is the Native Tabbed Documents release.

## Highlights

- Adds native macOS document tabs for Markdown document windows.
- Opens additional documents from File > Open, the toolbar open button, drag/drop, Finder/Dock, Open Recent, and session restore into the active native tab group instead of scattering separate top-level windows.
- Keeps each tab backed by its own `DocumentWindowController`, preserving per-document preview state, live preview, outline, inspector, theme, zoom, search, and export destinations.
- Routes active-tab changes through native key/main window notifications so toolbar and menu commands follow the selected tab.
- Cleans up closed tabs through native window close notifications, stopping only the closed document's watchers and preserving other tabs.
- Uses macOS native Window menu tab commands for tab switching, Move Tab to New Window, and Merge All Windows, with OpenMarked-supplied Show Tab Bar and Show All Tabs menu items.
- Adds File > Open in New Window... for opening selected Markdown files outside the current tab group.
- Improves session restore by saving the current open document list across tab opens/closes and filtering missing or unsupported files before launch restore.
- Expands QA coverage for native tabs, tab command routing, session restore, and export/print behavior from selected tabs.

## Installation

Developer artifacts are created by:

```sh
Scripts/package_release.sh
```

The resulting files are `dist/OpenMarked-0.5.0-macOS.zip` and `dist/OpenMarked-0.5.0-macOS.dmg`.

These developer artifacts are ad hoc signed by default but not notarized unless Apple signing credentials are supplied. On macOS, Gatekeeper may require opening them from Finder's context menu. Only run local developer artifacts from sources you trust.

## Known Limitations

- Opening the same source file more than once may create duplicate tabs in 0.5.0.
- Exact native tab order and tab group topology are not restored; session restore reopens the saved document list and groups documents into tabs where possible.

# OpenMarked 0.4.1

OpenMarked 0.4.1 is a polish and reliability patch for the Document Workbench release.

## Highlights

- Adds the OpenMarked SVG logo to the README and the app's empty-state chrome.
- Packages a native macOS app icon so Finder, Dock, and the app bundle show the OpenMarked identity.
- Hardens PDF export by using WebKit PDF generation, validating the resulting PDF data, and preventing repeated export attempts from leaving WebKit work running.
- Keeps the repository and packaged app metadata aligned under the GNU General Public License v3.0.

## Installation

Developer artifacts are created by:

```sh
Scripts/package_release.sh
```

The resulting files are `dist/OpenMarked-0.4.1-macOS.zip` and `dist/OpenMarked-0.4.1-macOS.dmg`.

These developer artifacts are ad hoc signed by default but not notarized unless Apple signing credentials are supplied. On macOS, Gatekeeper may require opening them from Finder's context menu. Only run local developer artifacts from sources you trust.

## OpenMarked 0.4.0

OpenMarked 0.4.0 is the Document Workbench release. It keeps the native Markdown previewer from earlier releases and adds the tools needed to inspect a document, understand its metadata, review references and assets, manage themes, and prepare output for export or print.

## Highlights

- Native document inspector with Summary, Metadata, Links, Assets, Diagnostics, Statistics, and Export Readiness sections.
- YAML, TOML, and JSON front matter inspection with standard fields, custom fields, normalized values, resolved title source, and file facts.
- Rich document statistics for words, characters, lines, reading time, estimated pages, sections, tables, links, images, missing references, code blocks, footnotes, GitHub callouts, Mermaid diagrams, KaTeX math, wide table candidates, and diagnostics.
- Links and assets inspector for valid local references, missing local references, remote references, malformed links, unsupported schemes, local image metadata, remote images, and blocked remote images.
- Export readiness warnings for missing links/assets, malformed links, unsupported schemes, remote images, rich-content failures, malformed front matter, wide tables, and multi-page review.
- Current-section outline highlighting and status breadcrumb while scrolling the preview.
- Theme Manager for previewing built-in themes, importing local CSS, duplicating built-in themes, renaming/deleting user themes, and revealing the managed theme folder.
- Custom theme safety checks for local `.css` files, empty CSS, `@import`, `javascript:` URLs, and embedded script/style tags.
- Print controls for page size, margins, content width, heading page breaks, print-only document title, and preview-theme versus Default print styling.
- Repeat HTML and PDF export to the previous per-document destination with explicit overwrite confirmation.
- Visual QA matrix expanded to preview, palette theme, inspector, Theme Manager, and print-controls snapshots.

## Still Included From Earlier Releases

- Native macOS app shell with standard menu bar, window commands, toolbar, Settings, and keyboard shortcuts.
- cmark-gfm rendering with GFM tables, strikethrough, task lists, autolinks, footnotes, heading IDs, and outline extraction.
- GitHub callouts, Mermaid diagrams, KaTeX math, and local link diagnostics.
- Offline bundled Mermaid `11.15.0` and KaTeX `0.17.0` assets.
- WKWebView preview with document-relative assets, local image watching, external-link handling, preview sanitization, search, zoom, and live preview.
- Standalone HTML export, copy rendered HTML, PDF export, native Print, ZIP/DMG packaging, and optional Developer ID/notarization hooks.

## Documentation

Focused guides:

- `Docs/DOCUMENT_INSPECTOR.md`
- `Docs/CUSTOM_THEMES.md`
- `Docs/PRINT_AND_EXPORT.md`
- `Docs/RICH_MARKDOWN.md`
- `Docs/LINK_VALIDATION.md`
- `Docs/RICH_CONTENT_DEPENDENCIES.md`

## Privacy And Network Behavior

OpenMarked remains local-first:

- Document contents are not sent to a service.
- Mermaid and KaTeX are bundled local assets, not CDN dependencies.
- Remote scripts and inline event handlers are stripped from preview/export HTML.
- Remote HTTP(S) links are parsed but not crawled during normal rendering.
- Optional remote link reporting produces an informational skipped-check diagnostic instead of contacting the network.
- Remote images load only when the remote image setting is enabled.
- Custom themes must be local CSS; remote CSS imports and user-authored JavaScript are blocked.

## Installation

Developer artifacts are created by:

```sh
Scripts/package_release.sh
```

The resulting files are `dist/OpenMarked-0.4.0-macOS.zip` and `dist/OpenMarked-0.4.0-macOS.dmg`.

These developer artifacts are ad hoc signed by default but not notarized unless Apple signing credentials are supplied. On macOS, Gatekeeper may require opening them from Finder's context menu. Only run local developer artifacts from sources you trust.

## Known Limitations

- The app is not notarized by default and does not yet ship as a Homebrew Cask.
- Remote link checking does not crawl the network automatically.
- Custom themes are CSS-only; they cannot add Markdown processors or scripts.
- Export profiles, DOCX export, EPUB export, Pandoc integration, and print preset editing are not included yet.
- Folder workspaces, backlinks, plugin processors, RTF/RTFD import, Scrivener project rendering, browser integrations, grammar tools, and AI features are deferred.
- Exact visual hash regression checks are optional because OS font and WebKit rendering can vary by environment.

## Reporting Issues

Use the GitHub issue templates for bug reports, rendering issues, and feature requests. Rendering bugs are most useful with a minimal Markdown sample and any local assets needed to reproduce the output.
