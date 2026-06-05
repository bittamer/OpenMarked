# OpenMarked Design Document

## Summary

OpenMarked is an open source, native macOS Markdown previewer and publishing companion. It is designed for people who already have a favorite editor and want a beautiful, fast, reliable rendered preview that follows their writing, helps them inspect the final output, and exports clean documents when they are ready.

The project is inspired by the broad workflow category of apps like Marked, but it should not copy proprietary UI, branding, assets, wording, or implementation details. The goal is to build an open, community-owned Markdown viewer that feels first-class on macOS and eventually becomes the best place to preview, inspect, proof, theme, and publish Markdown.

The MVP should focus on two things above all else:

1. Rendering Markdown correctly and predictably.
2. Making the preview experience beautiful, fast, and effortless.

Advanced publishing, custom processors, office-document workflows, browser extensions, and power-user automation are valuable, but they should build on top of a polished core rather than delay it.

## Product Positioning

OpenMarked is not primarily a Markdown editor. It is a viewer, previewer, and publishing surface.

The app should answer a simple need:

> I want to write Markdown anywhere and see exactly how it will look, with excellent typography, correct rendering, and useful document tools.

This positioning keeps the product focused. Editors already exist. OpenMarked should make those editors better.

## Target Users

### Writers

Writers use Markdown for blog posts, essays, newsletters, notes, books, and documentation. They care about typography, word count, navigation, readability, and reliable export.

### Developers

Developers use Markdown for README files, design docs, changelogs, prompts, plans, and generated documentation. They care about GitHub-compatible rendering, code highlighting, Mermaid diagrams, local images, tables, task lists, and fast updates.

### Technical Writers

Technical writers need predictable output, style consistency, link validation, document structure, reusable export settings, and possibly DOCX/PDF deliverables.

### Open Source Maintainers

Maintainers want a local preview that matches common publishing targets, especially GitHub. They also benefit from visual diffs, link checking, and previewing generated docs.

## Design Principles

### Native First

OpenMarked should feel like a real Mac app: menu commands, keyboard shortcuts, document windows, drag-and-drop, Quick Look-like immediacy, macOS accessibility, window restoration, sandbox-friendly file access, and good behavior with multiple Spaces and external displays.

### Preview First

The preview is the product. All chrome should support reading, inspection, navigation, and export. The app should open quickly into a clean rendered document, not a dashboard or landing page.

### Editor Agnostic

The app should work with any editor that saves local files: VS Code, Xcode, Vim, Emacs, BBEdit, Nova, Zed, Obsidian, iA Writer, Ulysses exports, Scrivener exports, terminal workflows, and generated files.

### Correct by Default

Rendering should be based on a well-maintained Markdown implementation, not a fragile custom parser. GitHub Flavored Markdown compatibility should be a first-class target.

### Beautiful Without Configuration

A new user should drop a Markdown file onto the app and get a handsome document immediately. Themes should be tasteful, readable, print-aware, dark-mode-aware, and accessible.

### Local and Private

Markdown files, previews, and exports should remain local unless the user explicitly configures an external service. Link checking and remote image loading should be transparent and controllable.

### Extensible Later

The architecture should leave room for custom renderers, processors, export backends, and automation, but MVP should avoid premature plugin complexity.

## Core Workflows

### Open and Preview a File

The user opens a `.md`, `.markdown`, `.mdown`, `.txt`, `.text`, or compatible bundle. OpenMarked renders the document in a clean preview window, resolves local images, applies the selected theme, and starts watching the file for changes.

### Live Preview While Editing Elsewhere

The user edits the file in another app. When the file changes, OpenMarked re-renders quickly, preserves scroll position where possible, and optionally highlights or scrolls to the edited region.

### Inspect Document Structure

The user opens a sidebar or command palette to jump between headings, search the document, inspect front matter, view links/images, or navigate errors and warnings.

### Switch Styles

The user chooses among built-in styles or a custom CSS theme. Style changes apply instantly without changing the source file.

### Export

The user exports to HTML or PDF in the MVP. Later versions add DOCX, EPUB, RTF, OpenDocument, OPML, and TextBundle.

### Use as a Reading Surface

The user opens long Markdown documents, plans, generated AI output, or documentation folders and reads them comfortably with a table of contents, mini map/outline, search, and keyboard navigation.

## MVP Scope

The MVP should feel complete for local Markdown previewing even if advanced publishing is deferred.

### Must Have

- Native macOS app written in Swift.
- Open files by File > Open, drag-and-drop, and Dock icon drop.
- Watch opened files for changes and update preview automatically.
- Render CommonMark and GitHub Flavored Markdown.
- Support headings, paragraphs, emphasis, blockquotes, lists, nested lists, tables, fenced code blocks, task lists, strikethrough, autolinks, footnotes, and raw HTML according to renderer capability.
- Syntax highlighting for fenced code blocks.
- Local image rendering with relative paths.
- Light and dark mode.
- Built-in beautiful preview themes.
- A clean document window with preview, status bar, toolbar, and optional outline sidebar.
- Document outline generated from headings.
- Search within rendered preview.
- Word count, character count, and reading time.
- Export complete standalone HTML.
- Export PDF using current print theme.
- Copy rendered HTML to clipboard.
- Print support.
- Per-document window restoration.
- Basic settings for default theme, font scale, file watching, and export behavior.
- Sandboxed file access that works correctly with user-selected files and folders.
- Accessibility support for keyboard navigation, VoiceOver labels, reduced motion, and sufficient contrast.

### Should Have

- Scroll position preservation after updates.
- Scroll to first changed paragraph.
- Link click popover with copy/open options.
- Basic link validation for local links and headings.
- Theme editor for adding custom CSS files.
- Front matter display and support for metadata-driven title.
- Mermaid diagram rendering.
- Math rendering with KaTeX.
- Command palette for common actions.
- Recent documents and quick open.
- Tabs or multiple windows.

### Not MVP

- DOCX import/export.
- EPUB export.
- RTF/RTFD import.
- Scrivener project rendering.
- Browser extensions.
- Web page to Markdown conversion.
- Style extraction from websites.
- Full custom processor/rule engine.
- Plugin marketplace.
- OPML/mind map rendering.
- Speed reading.
- Advanced proofreading and grammar checking.
- AI integrations.

## Feature Roadmap

### Phase 0: Project Foundation

Set up the app shell, repository structure, contribution guidelines, test fixtures, renderer abstraction, and a minimal preview window.

Deliverables:

- Swift app target.
- Markdown rendering module.
- Theme loading module.
- WKWebView preview module.
- File watcher module.
- Test Markdown corpus.
- Snapshot/export fixtures.

### Phase 1: Beautiful Core Preview

This became the core of the MVP and is now implemented through the Phase 10 release candidate.

Deliverables:

- File open/drop.
- Live file watching.
- CommonMark/GFM rendering.
- Syntax highlighting.
- Relative image support.
- Outline sidebar.
- Search.
- Status bar with word count and reading time.
- Three to five excellent built-in themes.
- HTML export.
- PDF export.
- Preferences window.

### Phase 2: Writing and Inspection Tools

Add the tools that make OpenMarked more than a passive viewer.

Deliverables:

- Scroll to edit.
- Link validation.
- Front matter inspector.
- Document statistics panel.
- Word repetition visualization.
- Basic keyword highlighting.
- Broken image warnings.
- Theme manager.
- Custom CSS import.
- Print-specific CSS controls.

### Phase 3: Technical Writing Power

Support richer Markdown documents and developer workflows.

Deliverables:

- Mermaid diagrams.
- KaTeX math.
- GitHub-style alerts/callouts.
- Wiki-style links and backlink panel for folders.
- Folder watching.
- Include syntax for multi-file documents.
- Code include syntax.
- GitHub README compatibility mode.
- Export profiles.

### Phase 4: Publishing Formats

Add document conversion features after the preview foundation is mature.

Deliverables:

- EPUB export.
- RTF export.
- DOCX export.
- DOCX import to Markdown.
- TextBundle/TextPack support.
- OPML export.
- Pandoc integration.

### Phase 5: Automation and Extensibility

Add power-user workflows without compromising safety.

Deliverables:

- URL scheme.
- Shortcuts actions.
- Command line tool.
- AppleScript support if feasible.
- Custom processor rules.
- External command sandbox model.
- Plugin API.
- Browser extension for page-to-Markdown capture.

## User Interface Design

### Main Window

The main window should be quiet, document-focused, and recognizably Mac-native.

Layout:

- Toolbar at top.
- Optional left outline sidebar.
- Primary preview area.
- Optional right inspector sidebar for document details.
- Thin status bar at bottom.

Toolbar controls:

- Open.
- Reveal source file.
- Refresh.
- Theme selector.
- Toggle outline.
- Search.
- Export.
- More actions menu.

Status bar:

- Current processor mode.
- Word count.
- Reading time.
- Warnings count.
- Zoom/font scale.
- File watching state.

The preview should not look like a web page inside a random native wrapper. It should feel like a rendered document canvas. Use high-quality margins, subtle page width constraints, print-like rhythm, smooth dark mode, and typography that respects the selected theme.

### Outline Sidebar

The outline sidebar lists headings in document order with indentation by heading level. It should support:

- Click to jump.
- Filter-as-you-type.
- Collapse nested sections.
- Current section highlight.
- Optional word counts per section later.

### Inspector Sidebar

The inspector can be deferred until after MVP, but the architecture should anticipate it.

Potential panels:

- Metadata.
- Links.
- Images.
- Statistics.
- Export settings.
- Warnings.
- Comments/footnotes.

### Command Palette

A command palette should eventually expose commands without crowding the UI.

Examples:

- Export HTML.
- Export PDF.
- Copy HTML.
- Switch Theme.
- Toggle Outline.
- Validate Links.
- Open in External Editor.
- Reveal in Finder.
- Show Document Statistics.

### Export Panel

MVP can use standard Save panels for HTML/PDF. A richer export panel can come later.

Future design:

- Searchable list of export formats.
- Recently used export profiles.
- Destination picker.
- Format-specific options.
- Keyboard-first operation.
- Clear success/failure feedback.

## Visual Design

OpenMarked should be beautiful because the preview is beautiful, not because the app has heavy decoration.

### App Chrome

- Native macOS materials where appropriate.
- Minimal toolbar.
- No decorative gradients.
- No novelty UI.
- Respect system light/dark mode.
- Use SF Symbols for toolbar icons.
- Avoid large marketing-style empty states.

### Preview Themes

The current MVP ships three built-in themes:

- **Default**: editorial reading style with light and dark variants.
- **GitHub**: README-oriented rendering for common repository documents.
- **Minimal**: restrained, print-friendly rendering.

Future themes can cover additional needs:

- **Manuscript**: warm editorial reading style.
- **Technical**: crisp docs theme with clear code blocks and tables.
- **Presentation**: wider layout for rendered reports or project docs.

Every theme should include:

- Light and dark variants.
- Print CSS.
- Code highlighting theme.
- Table styling.
- Blockquote styling.
- Task list styling.
- Footnote styling.
- Image sizing rules.
- Accessible color contrast.

### Typography

Default type should be readable and modern.

Recommended defaults:

- Body: New York, Charter, or system serif for editorial themes; system sans for technical themes.
- Code: SF Mono.
- Line length: 68-78 characters for prose themes.
- Line height: 1.55-1.7 for prose, 1.45-1.55 for technical docs.
- Heading scale should be clear but not theatrical.

## Markdown Rendering

### Renderer Choice

The MVP should use a proven Markdown implementation. Recommended approach:

- Use `cmark-gfm` for CommonMark plus GitHub Flavored Markdown compatibility.
- Wrap it in a Swift module with a narrow API.
- Generate HTML as an intermediate representation.
- Render the final document in `WKWebView`.

Why:

- `cmark-gfm` tracks the behavior many users expect.
- WKWebView gives high-quality HTML/CSS layout, printing, JavaScript-enabled diagrams, and selectable/searchable text.
- A renderer abstraction leaves room for future engines such as MultiMarkdown, Kramdown, Pandoc, or a pure Swift parser.

### Rendering Pipeline

Pipeline:

1. Read source file.
2. Detect encoding.
3. Extract front matter.
4. Normalize line endings.
5. Resolve include syntax if enabled.
6. Render Markdown to HTML.
7. Post-process HTML.
8. Resolve local assets.
9. Inject theme CSS.
10. Inject code highlighting CSS.
11. Inject optional diagram/math renderers.
12. Load into preview web view.
13. Build outline and document metadata.

### Post-Processing

Post-processing should be structured, not regex-heavy.

Use an HTML parser for:

- Heading IDs.
- Table of contents generation.
- Link rewriting.
- Local image URL rewriting.
- Footnote backlinks.
- Warning collection.
- External link attributes.
- Code block highlighting hooks.

### Raw HTML Policy

Markdown often includes raw HTML. OpenMarked should support it locally, but provide controls.

Default:

- Render raw HTML in trusted local files.
- Block remote scripts by default.
- Allow remote images with a preference.
- Disable arbitrary network requests in strict privacy mode.

Future:

- Safe preview mode.
- Content security policy controls.
- Per-document trust prompts.

## File Watching

File watching should be reliable and calm.

Requirements:

- Watch the source file for changes.
- Coalesce rapid updates.
- Avoid re-rendering partial writes.
- Detect file moves and renames where possible.
- Watch local assets referenced by the document.
- Watch included files in later phases.
- Show clear status when a file is missing, unreadable, or outside sandbox access.

Implementation options:

- Use `DispatchSourceFileSystemObject` for direct file watching.
- Use FSEvents for folder-level watching and multi-file documents.
- Debounce updates with a short interval, such as 150-300 ms.

## Architecture

### Recommended Technology Stack

- Language: Swift.
- UI: SwiftUI for app shell, AppKit where needed for mature macOS document/window behavior.
- Preview: WKWebView.
- Markdown: cmark-gfm via Swift package/C module.
- Syntax highlighting: offline Swift-side pre-highlighting for common MVP languages, with future option for tree-sitter or Shiki-like output.
- Preferences: SwiftUI Settings scene.
- Persistence: AppStorage/UserDefaults for simple settings; JSON/plist for themes/export profiles.
- Tests: XCTest plus fixture-based renderer tests.

### Modules

#### OpenMarkedApp

App entry point, scenes, menu commands, settings, document/window routing.

#### DocumentCore

Document model, source loading, metadata, file access, bookmarks, restoration.

#### MarkdownEngine

Renderer abstraction and cmark-gfm implementation.

#### PreviewEngine

HTML document assembly, asset resolution, preview state, WKWebView coordination.

#### ThemeKit

Theme model, built-in themes, custom CSS loading, print CSS, dark-mode variants.

#### FileWatching

File and folder watchers, debouncing, change events.

#### ExportKit

HTML export, PDF export, future format adapters.

#### Diagnostics

Warnings for broken links, missing images, unsupported syntax, render errors, and export failures.

### Key Types

```swift
struct MarkdownDocument {
    var sourceURL: URL
    var displayName: String
    var sourceText: String
    var frontMatter: FrontMatter?
    var lastRenderedAt: Date?
}

struct RenderRequest {
    var document: MarkdownDocument
    var options: RenderOptions
    var theme: PreviewTheme
}

struct RenderResult {
    var html: String
    var outline: [OutlineItem]
    var statistics: DocumentStatistics
    var diagnostics: [Diagnostic]
}

struct PreviewTheme {
    var id: String
    var name: String
    var css: String
    var printCSS: String
    var supportsDarkMode: Bool
}
```

The exact types will evolve, but the separation matters: source document, render request, render result, preview theme, and diagnostics should be distinct concepts.

## Export Design

### MVP Export Formats

#### Standalone HTML

HTML export should optionally embed:

- Theme CSS.
- Code highlighting CSS.
- Local images as data URLs.
- Metadata.
- Table of contents.

#### PDF

PDF export should use the current print CSS and native print/PDF APIs.

Important:

- Respect page margins.
- Use print-specific theme styles.
- Avoid clipping code blocks and tables where possible.
- Provide a preview before save if feasible.

### Later Export Formats

#### EPUB

Useful for long-form writers. Best implemented once multi-file documents and assets are stable.

#### DOCX

High demand, but complex. Should probably use Pandoc integration first, then possibly native generation later.

#### RTF/ODT/OPML/TextBundle

Valuable, but not essential to the core viewer.

## Settings

Current MVP settings:

- Default theme.
- Font scale.
- Enable/disable live updates.
- Preserve scroll position.
- Remote image loading.
- Raw HTML rendering.
- Include CSS in HTML exports.
- Embed local images in HTML exports.
- Restore last opened documents.

Future settings:

- External editor.
- Custom processors.
- Link validation behavior.
- Export profiles.
- Theme manager.
- Privacy/security modes.
- Keyboard shortcuts customization.

## Open Source Strategy

### License

Use GPL-3.0-only if the goal is ensuring derivative apps remain open source.

Recommended default: GPL-3.0-only for OpenMarked so downstream app improvements stay open.

### Repository Structure

```text
OpenMarked/
  App/
  Packages/
    DocumentCore/
    MarkdownEngine/
    PreviewEngine/
    ThemeKit/
    FileWatching/
    ExportKit/
  Themes/
    BuiltIn/
  Fixtures/
    Markdown/
    HTML/
    Screenshots/
  Docs/
    DESIGN.md
    CONTRIBUTING.md
    ROADMAP.md
```

For a small early project, this can start flatter. The key is to keep renderer, preview, themes, and app shell decoupled.

### Contribution Areas

The project can invite community help around:

- Markdown compatibility fixtures.
- Themes.
- Localization.
- Accessibility.
- Export formats.
- Editor integrations.
- Documentation.
- Performance profiling.
- Visual regression testing.

### Compatibility Test Corpus

OpenMarked should ship with a public fixture suite:

- CommonMark examples.
- GFM examples.
- GitHub README samples.
- Tables and task lists.
- Nested lists.
- Footnotes.
- Code blocks.
- Local images.
- Front matter.
- Edge cases from real docs.

This becomes a major open source advantage: users can trust and inspect rendering behavior.

## Security and Privacy

Markdown preview can be a security boundary because documents may include HTML, images, links, scripts, and local file references.

MVP security rules:

- User-selected files get access through security-scoped bookmarks.
- Relative assets are resolved only from the document directory and explicitly allowed folders.
- Remote scripts are blocked.
- Remote image loading can be disabled.
- JavaScript is enabled only for trusted bundled functionality such as search, highlighting, Mermaid, or math.
- Export should not unexpectedly fetch remote assets unless enabled.
- Diagnostics should report blocked content clearly.

Future:

- Strict mode for untrusted files.
- Per-document trust.
- CSP injection.
- Sandboxed render process policy review.

## Accessibility

Accessibility is part of MVP quality.

Requirements:

- Full keyboard navigation for toolbar, outline, search, and export.
- VoiceOver labels for all controls.
- Proper semantic HTML in preview.
- Respect system font size where possible.
- Respect reduced motion.
- High-contrast theme variants or sufficient contrast in all themes.
- Visible focus rings.
- Search results announced accessibly.

## Performance

Performance targets:

- Open a 10,000-word document in under 500 ms after app launch on modern Macs.
- Re-render typical documents in under 150 ms.
- Keep UI responsive during rendering.
- Coalesce rapid file changes.
- Avoid full WKWebView reloads in future if incremental updates become necessary.
- Handle documents with many code blocks and images without jank.

MVP can reload the full preview. Later phases can explore partial DOM updates if needed.

## Quality Plan

### Automated Tests

- Markdown-to-HTML fixture tests.
- Asset resolution tests.
- Heading ID generation tests.
- Front matter parsing tests.
- Theme loading tests.
- Export HTML tests.
- File watcher debounce tests.

### Visual Tests

- Screenshot fixtures for built-in themes.
- Light/dark mode snapshots.
- Long document snapshots.
- Table/code block snapshots.
- PDF export smoke tests.

### Manual QA

- Drag file onto app icon.
- Edit in VS Code and watch update.
- Edit in Vim and watch update.
- Move source file.
- Open file from iCloud.
- Open file with local images.
- Toggle themes.
- Export HTML and PDF.
- Print.
- Use keyboard-only navigation.
- Test VoiceOver basics.

## Competitive Differentiation

OpenMarked should compete by being:

- Open source.
- Native macOS.
- Beautiful by default.
- Faithful to common Markdown behavior.
- Privacy-respecting.
- Extensible without requiring proprietary workflows.
- Excellent for developers and writers.
- Transparent through public fixtures and community themes.

The long-term opportunity is not merely to recreate an existing commercial app. It is to make Markdown previewing an open platform with reliable rendering, great design, and a community-maintained ecosystem.

## MVP Success Criteria

The MVP is successful when:

- A user can open a Markdown file and immediately get a beautiful preview.
- The preview updates reliably while editing in another app.
- CommonMark/GFM documents render correctly enough for real README and documentation work.
- Local images, tables, code blocks, and task lists look good.
- The outline and search make long documents pleasant to navigate.
- HTML and PDF export work without fuss.
- The app feels native, fast, and calm.
- The project structure is welcoming to contributors.

## Deferred Feature List

These features are desirable but should not block MVP:

- DOCX import/export.
- EPUB export.
- RTF/RTFD support.
- Scrivener project support.
- Browser extensions.
- Web clipping to Markdown.
- Style extraction from URLs.
- Custom processor/rule engine.
- Mermaid and KaTeX if they threaten MVP schedule.
- Grammar checking.
- Advanced readability reports.
- Folder-wide wiki navigation.
- Backlinks.
- Mind maps.
- Speed reading.
- Plugin API.
- Cloud sync.
- AI features.

## Naming Notes

The working name OpenMarked is descriptive, but the project should avoid confusion with any existing app. Before public launch, choose a name and icon that are clearly distinct.

Possible naming directions:

- Markview.
- Markdown Lens.
- PaperMark.
- RenderDown.
- PageDown.
- InkPreview.

The brand should communicate openness, native polish, and readable documents.
