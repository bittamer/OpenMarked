# OpenMarked Print And Export

OpenMarked supports standalone HTML export, copying rendered HTML, PDF export, native Print, and repeat export to the previous per-document destination.

## Print Controls

Print settings live in Settings and apply to standalone HTML print CSS, PDF export, and native Print.

Controls:

- Page size: Letter, A4, or Legal.
- Margins: top, right, bottom, and left in inches.
- Content max width: optional print width limit.
- Start H1 on new page.
- Start H2 on new page.
- Include document title as print-only header.
- Print style: use the active preview theme or Default print CSS.

Values are normalized before use. Margins are clamped between 0.25 and 2.0 inches. Content width is clamped between 560 and 1400 pixels.

## Standalone HTML

Standalone HTML export can include:

- Rendered Markdown body.
- Theme CSS.
- Code highlighting CSS.
- Print CSS.
- Local image embedding when enabled.
- Bundled Mermaid and KaTeX runtime assets when rich content requires them.

Exported rich HTML is designed to work offline. It embeds OpenMarked's trusted local Mermaid/KaTeX runtime when needed rather than loading a CDN.

## PDF Export And Print

PDF export and native Print render through WebKit. OpenMarked waits for rich content to finish rendering before capture, then applies print configuration to the generated HTML and `NSPrintInfo`.

Print configuration affects:

- Paper size.
- Margins.
- Content width.
- Heading page breaks.
- Print-only document title.
- Print CSS selection.

## Repeat Export

After a successful HTML or PDF export, OpenMarked stores the destination for that document window. Export HTML Again and Export PDF Again reuse that destination without reopening a save panel.

Repeat export still asks for explicit replacement confirmation before overwriting the existing file.

## Export Readiness

The inspector's Export section reports practical review items before sharing output:

- Missing local links or images.
- Missing heading fragments.
- Malformed or unsupported links.
- Remote images and blocked remote images.
- Mermaid and KaTeX failures.
- Malformed front matter.
- Wide table candidates.
- Multi-page export review notes.

Warnings do not prevent export. They make risky output visible before the user chooses to share it.

## Limitations

OpenMarked 0.4.0 does not include export profiles, DOCX export, EPUB export, Pandoc integration, or a print preset editor. Those belong to later publishing-workflow releases.
