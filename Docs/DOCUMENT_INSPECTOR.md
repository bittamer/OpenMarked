# OpenMarked Document Inspector

OpenMarked 0.4.0 adds a native document inspector for reviewing the active Markdown file after it renders. The inspector is a right sidebar, not an editor. It helps answer whether the document has the right metadata, structure, references, assets, diagnostics, and export readiness.

## Opening The Inspector

Use the toolbar or View menu to show or hide the inspector. The selected section is stored with the window layout, so reopening a document restores the last visible inspector section when possible.

Inspector sections:

- Summary: resolved title, high-level document counts, diagnostics count, and export status.
- Metadata: YAML, TOML, or JSON front matter fields plus file facts.
- Links: rendered anchors with local, remote, malformed, unsupported, and missing statuses.
- Assets: rendered images with local path, byte size, image dimensions when available, and missing/remote status.
- Diagnostics: render, link, rich-content, front matter, and content-policy diagnostics.
- Statistics: reading and structure metrics, including sections and rich Markdown counts.
- Export: readiness notes and warnings for PDF, Print, and standalone HTML.

## Metadata

The inspector uses the same document model as the preview. Front matter is removed from the rendered Markdown body and becomes structured metadata in the inspector.

Supported front matter formats:

- YAML delimited with `---`.
- TOML delimited with `+++`.
- JSON delimited with `;;;`.

Metadata fields are normalized for display. Lists become token chips, booleans and numbers are typed, date-like values are recognized, and nested values are kept readable as text. Standard fields such as `title`, `description`, `author`, `date`, `tags`, `slug`, `draft`, and `layout` are grouped ahead of custom fields.

The display title resolves in this order:

1. Front matter `title`.
2. First Markdown heading.
3. File name.

## Statistics

The Statistics section expands beyond the status bar. It reports:

- Words, characters, lines, reading time, and estimated page count.
- Headings by level and per-section word/paragraph counts.
- Paragraphs, links, images, missing references, code blocks, tables, footnotes, callouts, Mermaid diagrams, KaTeX math expressions, wide table candidates, and diagnostics.

Reading speed and whether front matter is included in word counts are controlled in Settings.

## Links And Assets

Link inspection is local-first. OpenMarked validates local files, same-document heading fragments, readable Markdown heading fragments in local Markdown files, malformed URLs, and unsupported schemes. Remote HTTP(S) links are parsed and reported but are not crawled during normal rendering.

Asset inspection reports local image paths, missing local images, remote images, data images, and blocked remote images. Local image size and dimensions are shown when available. Remote image fetching follows the preview content setting; inspection itself does not perform background network fetches.

## Diagnostics

Diagnostics come from the render pipeline and inspection builder. They include missing local links/images, missing heading fragments, malformed links, malformed front matter, unsupported schemes, Mermaid or math failures, disabled rich-content features, malformed GitHub callouts, skipped remote link validation, unsupported extensions, and render failures.

## Export Readiness

Export readiness is not a certification step. It is a practical preflight list for issues that often matter before sharing a PDF, printing, or exporting standalone HTML.

Readiness can include:

- Missing local links or images.
- Missing heading fragments.
- Malformed or unsupported links.
- Remote images or blocked remote images.
- Mermaid or KaTeX rendering failures.
- Malformed front matter.
- Wide table candidates.
- Multi-page export review notes.

Remote links are not crawled. A document can still be exported with readiness warnings; the warnings are there to make review deliberate.

## Privacy

The inspector does not send document contents anywhere. It works from the loaded Markdown file, the rendered HTML, local filesystem checks for selected files/assets, and the app settings. Remote link crawling and remote theme loading are not part of the 0.4.0 inspector.
