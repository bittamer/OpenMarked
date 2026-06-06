# OpenMarked 0.4.0

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
