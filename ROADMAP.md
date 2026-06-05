# OpenMarked Roadmap

## MVP: 0.1.0

The MVP is a native macOS Markdown previewer that can open local Markdown files, render them beautifully, follow edits from external editors, navigate long documents, and export HTML/PDF.

Current state: 0.1.0 is tagged. 0.2.0 adds distribution and QA hardening on top of the MVP.

### 0.1.0-alpha.1: Foundation

- Repository documentation.
- Swift Package based app skeleton.
- Core test target.
- CI build/test workflow.
- Markdown fixture corpus.

### 0.1.0-alpha.2: Usable Preview

- File open and drag/drop.
- Markdown renderer integration.
- WKWebView preview.
- Local image support.
- Live file watching.
- Built-in themes.
- Outline sidebar.
- Search.
- Status bar statistics.

### 0.1.0-beta.1: Export and Polish

- Standalone HTML export.
- PDF export.
- Print support.
- Copy rendered HTML.
- Settings window.
- Keyboard shortcuts.
- Accessibility pass.
- Dark mode QA.

### 0.1.0: Public MVP

- All P0 MVP tickets complete.
- Fixture tests pass.
- Manual QA checklist passes.
- Release notes and known limitations are published.
- Developer ZIP artifact is available.
- Standard macOS menu bar and default app/window commands work when OpenMarked is focused.

## 0.2.0 Distribution And QA Hardening

Make the MVP easier to trust, install, test, and visually validate.

- Record a Computer Use visual QA pass in `Docs/VISUAL_QA.md`.
- Add screenshot-based visual coverage for built-in themes, tables, code blocks, local images, and dark mode.
- Add PDF/export fixture verification beyond smoke tests.
- Add Developer ID signing and notarization hooks for when credentials are available.
- Produce a DMG with clear install instructions and Gatekeeper expectations.
- Add crash/log collection guidance for issue reports without sending user data anywhere.
- Add a small screenshots/gallery section to README.

## Recommended Next Milestone: 0.3.0 Markdown Power Pack

Add the highest-value Markdown extensions that make the app more useful for developers and technical writers.

- Mermaid diagrams.
- KaTeX math.
- GitHub alerts/callouts.
- Link validation.
- Local heading/link validation diagnostics.
- GitHub README compatibility mode.

## 0.4.0 Document Inspection And Themes

Build the tools that make OpenMarked more than a passive previewer.

- Front matter inspector.
- Links and images inspector.
- Rich document statistics panel.
- Current section highlight in the outline.
- Theme manager and custom CSS import.
- Print-specific CSS controls.

## 0.5.0 Publishing Workflows

Turn export into a repeatable workflow for writers and documentation teams.

- Export profiles.
- Export preset editor.
- EPUB export.
- DOCX export through a carefully scoped conversion path.
- TextBundle/TextPack support.

## 0.6.0 Folder And Automation Workflows

Support larger documentation projects and power-user automation.

- Folder watching and wiki-style navigation.
- Command line utility and automation hooks.
- URL scheme and Shortcuts actions.
- Include syntax for multi-file documents.
- Backlinks for folder workspaces.

## Explicitly Deferred from MVP

- Scrivener project rendering.
- Browser extensions.
- Web page to Markdown conversion.
- Style extraction from websites.
- Full custom processor/rule engine.
- Plugin API.
- Speed reading.
- AI features.
