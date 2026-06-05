# OpenMarked MVP Implementation Plan

## Purpose

This document converts the product design in `DESIGN.md` into a detailed, ticket-based implementation plan for the first shippable MVP of OpenMarked.

Status: the MVP implementation is complete through Phase 10 as a `0.1.0` release candidate. Automated release verification and developer ZIP packaging pass locally. Manual fixture visual QA, owner approval, and the release tag remain pending; use `Docs/BACKLOG.md`, `Docs/QA.md`, `Docs/RELEASE.md`, and `ROADMAP.md` for current release status.

The MVP goal is not to match every advanced feature of mature commercial Markdown previewers. The MVP goal is to deliver a beautiful, native macOS app that reliably opens Markdown files, renders them correctly, follows edits from external editors, helps users navigate long documents, and exports clean HTML/PDF.

## MVP Definition

The MVP is complete when a user can:

1. Open a Markdown file from Finder, the Dock, or File > Open.
2. See a polished native macOS document window with a beautiful rendered preview.
3. Edit the file in another editor and see the preview update automatically.
4. Render common CommonMark and GitHub Flavored Markdown documents correctly.
5. Use local images, tables, task lists, code blocks, links, and front matter without surprises.
6. Navigate a long document through outline and search.
7. See basic document statistics.
8. Switch between a small set of high-quality built-in themes.
9. Export standalone HTML.
10. Export or print PDF.
11. Use the app comfortably with keyboard navigation, dark mode, and accessible controls.

## Non-Goals for MVP

These features should be explicitly deferred unless they become trivial byproducts of MVP work:

- DOCX import/export.
- EPUB export.
- RTF/RTFD import.
- Scrivener project rendering.
- Browser extensions.
- Web page to Markdown conversion.
- Style extraction from websites.
- Full custom processor/rule engine.
- Plugin API.
- OPML or mind map rendering.
- Speed reading.
- Grammar checking.
- AI features.
- Cloud sync.
- Multi-user collaboration.

## Suggested MVP Release Name

Use `0.1.0` for the first public MVP.

Use pre-release milestones:

- `0.1.0-alpha.1`: app opens files and renders Markdown.
- `0.1.0-alpha.2`: live preview, themes, outline, and stats.
- `0.1.0-beta.1`: exports, settings, accessibility, and quality pass.
- `0.1.0`: public MVP release.

## Planning Assumptions

- Language: Swift.
- UI: SwiftUI plus AppKit where macOS document/window behavior needs it.
- Preview: WKWebView.
- Markdown renderer: `cmark-gfm`, wrapped behind a Swift interface.
- Syntax highlighting: offline Swift-side pre-highlighting for common MVP languages, with future room for tree-sitter or Shiki-like output.
- Minimum deployment target: macOS 13+.
- Distribution: ad hoc signed developer ZIP for MVP, with Developer ID signing, notarization, Homebrew Cask, and DMG deferred until the app is stable.
- Tests: XCTest plus fixture-based rendering and export tests.

## Ticket Format

Each ticket includes:

- **Goal**: what the ticket accomplishes.
- **Scope**: what to build.
- **Acceptance Criteria**: what must be true to close the ticket.
- **Implementation Notes**: guidance and risks.
- **Test Notes**: what to verify.
- **Dependencies**: tickets that should land first.

Estimate scale:

- XS: less than half a day.
- S: about one day.
- M: two to three days.
- L: four to six days.
- XL: more than a week or needs decomposition.

Priority scale:

- P0: required for MVP.
- P1: strongly recommended for MVP.
- P2: polish or follow-up.

## Phase Overview

| Phase | Name | Outcome |
| --- | --- | --- |
| 0 | Product and Project Foundation | Decisions, repo shape, CI, fixtures, and project skeleton are ready. |
| 1 | Native App Shell | A native macOS app can open windows, files, menus, and basic UI states. |
| 2 | Document Model and File Access | Source files can be read safely, restored, tracked, and represented consistently. |
| 3 | Markdown Rendering Core | Markdown becomes HTML through a tested renderer pipeline. |
| 4 | Preview WebView | Rendered HTML appears in a native preview with local assets and safe policies. |
| 5 | Theme System and Visual Design | Built-in themes make the app beautiful by default. |
| 6 | Live Preview | External edits update the preview reliably and calmly. |
| 7 | Navigation and Document Tools | Outline, search, statistics, and source actions make long docs usable. |
| 8 | Export and Print | HTML, PDF, print, and copy HTML workflows are shippable. |
| 9 | Settings, Accessibility, and Polish | MVP preferences, keyboard behavior, restoration, and accessibility land. |
| 10 | QA, Packaging, and Release | The app is tested, documented, packaged, and ready for public MVP release. |

## Phase 0: Product and Project Foundation

### Goal

Create a clear project baseline before writing substantial app code.

### Exit Criteria

- The repository has an app skeleton or Xcode project.
- The project has a license, contribution guide, and basic README.
- CI can build and run tests.
- Markdown fixture corpus exists.
- The MVP backlog is represented in issues or a local tracker.

### Tickets

#### MVP-000: Confirm MVP Scope and Milestones

- Priority: P0
- Estimate: S
- Dependencies: none

**Goal**

Lock the initial MVP scope so implementation does not drift into advanced publishing features too early.

**Scope**

- Review `DESIGN.md`.
- Review this plan.
- Create a short `ROADMAP.md` with MVP, post-MVP, and future buckets.
- Define what counts as `0.1.0-alpha.1`, `0.1.0-alpha.2`, `0.1.0-beta.1`, and `0.1.0`.

**Acceptance Criteria**

- `ROADMAP.md` exists.
- MVP requirements are listed clearly.
- Deferred features are listed clearly.
- No MVP requirement depends on DOCX, EPUB, Scrivener, browser extensions, or custom processors.

**Implementation Notes**

- Keep the roadmap short. The detailed plan lives here.
- Treat this as a guardrail document for contributors.

**Test Notes**

- Manual review only.

#### MVP-001: Choose License, Public Name, and Repository Metadata

- Priority: P0
- Estimate: XS
- Dependencies: none

**Goal**

Prepare the project for open source collaboration.

**Scope**

- Use GPL-3.0-only for the project license.
- Add `LICENSE`.
- Add initial `README.md`.
- Add repository description.
- Decide whether `OpenMarked` remains the public name for MVP.

**Acceptance Criteria**

- `LICENSE` exists.
- `README.md` states what the app does, platform target, current status, and non-goals.
- Name avoids proprietary branding confusion.

**Implementation Notes**

- If the name is uncertain, use `OpenMarked` internally and mark branding as temporary.

**Test Notes**

- Manual review only.

#### MVP-002: Decide Deployment Target and Build Tooling

- Priority: P0
- Estimate: S
- Dependencies: MVP-000

**Goal**

Choose the macOS baseline and project structure before dependencies are added.

**Scope**

- Decide minimum macOS version.
- Decide whether to use one Xcode project with local Swift packages or a Swift package workspace.
- Record the decision in `Docs/ARCHITECTURE.md` or `README.md`.

**Acceptance Criteria**

- Minimum macOS target is documented.
- Build structure is documented.
- Decision includes tradeoffs for SwiftUI APIs, WKWebView, sandboxing, and distribution.

**Implementation Notes**

- macOS 13+ is a good starting point for modern SwiftUI without being too narrow.
- If supporting macOS 12 or 11 matters, audit SwiftUI APIs early.

**Test Notes**

- Confirm project builds on the chosen target SDK.

#### MVP-003: Create Xcode App Skeleton

- Priority: P0
- Estimate: M
- Dependencies: MVP-002

**Goal**

Create a native macOS app target that launches reliably.

**Scope**

- Add Xcode project or workspace.
- Add app target.
- Add test target.
- Add Swift package/module structure.
- Add placeholder app icon.
- Add a basic `OpenMarkedApp` entry point.
- Add a default empty window.

**Acceptance Criteria**

- App builds in Debug.
- App launches to an empty native window.
- Tests run, even if only one placeholder test exists.
- Build products are ignored by git.

**Implementation Notes**

- Keep the initial window plain. Avoid spending design time before the preview exists.
- Prefer local packages for `DocumentCore`, `MarkdownEngine`, `PreviewEngine`, `ThemeKit`, `FileWatching`, and `ExportKit` if that does not slow setup.

**Test Notes**

- Run build.
- Run tests.
- Launch app manually.

#### MVP-004: Add CI Build and Test Workflow

- Priority: P0
- Estimate: M
- Dependencies: MVP-003

**Goal**

Ensure every contribution can be built and tested automatically.

**Scope**

- Add GitHub Actions workflow.
- Build app target.
- Run unit tests.
- Cache Swift Package Manager dependencies if helpful.
- Add basic status badge to README.

**Acceptance Criteria**

- CI workflow succeeds on main branch.
- CI fails on compile or test failures.
- README explains how to run the same commands locally.

**Implementation Notes**

- Use `xcodebuild` directly for transparency.
- If using a workspace, pin scheme names carefully.

**Test Notes**

- Push branch or run workflow locally if available.

#### MVP-005: Create Markdown Fixture Corpus

- Priority: P0
- Estimate: M
- Dependencies: MVP-000

**Goal**

Create test documents that define expected MVP rendering behavior.

**Scope**

- Add fixture documents for headings, paragraphs, lists, nested lists, blockquotes, tables, task lists, fenced code, inline code, links, images, footnotes, strikethrough, raw HTML, front matter, and long documents.
- Add a README explaining each fixture.
- Include at least one README-like document and one prose document.

**Acceptance Criteria**

- Fixtures exist in `Fixtures/Markdown`.
- Each fixture has a clear purpose.
- Fixture paths are stable for unit and manual tests.

**Implementation Notes**

- Do not overfit to generated expected HTML yet. That happens after the renderer lands.
- Include local images in fixture assets.

**Test Notes**

- Manual review for coverage.

#### MVP-006: Add Coding and Contribution Guidelines

- Priority: P1
- Estimate: S
- Dependencies: MVP-003

**Goal**

Make the project pleasant for future contributors.

**Scope**

- Add `CONTRIBUTING.md`.
- Add code style expectations.
- Add testing expectations.
- Add issue template suggestions if using GitHub.

**Acceptance Criteria**

- Contributors can build, test, and understand contribution expectations from docs.
- Guidelines mention accessibility, privacy, and fixture updates.

**Implementation Notes**

- Keep process light for MVP. Good defaults beat bureaucracy.

**Test Notes**

- Manual review only.

## Phase 1: Native App Shell

### Goal

Build the native macOS foundation that all preview workflows use.

### Exit Criteria

- App has a recognizable main window.
- App can open files through menu and drag/drop.
- App has native menu commands and toolbar placeholders.
- Empty, loading, error, and document states exist.

### Tickets

#### MVP-101: Define App State and Window State Models

- Priority: P0
- Estimate: M
- Dependencies: MVP-003

**Goal**

Create the state model used by windows, documents, rendering, and commands.

**Scope**

- Define app-level state.
- Define window-level state.
- Define loaded document state.
- Define preview loading/error states.
- Define selected theme and layout preferences in state, even if not functional yet.

**Acceptance Criteria**

- Window can represent empty, loading, loaded, and error states.
- State model is testable without UI.
- No renderer-specific logic leaks into app shell state.

**Implementation Notes**

- Avoid a single huge observable object if separate view models are clearer.
- Keep document identity separate from document source text.

**Test Notes**

- Unit test state transitions where practical.

#### MVP-102: Build Main Window Layout

- Priority: P0
- Estimate: M
- Dependencies: MVP-101

**Goal**

Create the core native layout for the app.

**Scope**

- Toolbar region.
- Optional left outline sidebar placeholder.
- Main preview placeholder area.
- Bottom status bar.
- Empty state.
- Error state.

**Acceptance Criteria**

- App launches to an empty window with a useful open-file affordance.
- Layout adapts to reasonable window sizes.
- Status bar remains stable and does not jump.
- Sidebar can be shown/hidden, even with placeholder content.

**Implementation Notes**

- Do not make a landing page.
- The first screen should feel like a document utility.

**Test Notes**

- Manual visual check at small, medium, and large window sizes.

#### MVP-103: Add Native Menu Commands

- Priority: P0
- Estimate: M
- Dependencies: MVP-102

**Goal**

Expose core app actions through standard macOS menus.

**Scope**

- File > Open.
- File > Close.
- File > Export HTML placeholder.
- File > Export PDF placeholder.
- File > Print placeholder.
- View > Toggle Outline.
- View > Reload Preview.
- View > Zoom In/Out/Actual Size.
- Help > OpenMarked Help placeholder.

**Acceptance Criteria**

- Menu items appear in expected locations.
- Keyboard shortcuts are assigned for common commands.
- Disabled commands are disabled when no document is open.
- Commands route to the active window.

**Implementation Notes**

- Use standard macOS shortcut conventions.
- Avoid inventing unusual shortcuts in MVP.

**Test Notes**

- Manual menu and shortcut verification.

#### MVP-104: Implement Open Panel

- Priority: P0
- Estimate: M
- Dependencies: MVP-102

**Goal**

Allow users to open Markdown files through File > Open.

**Scope**

- Present native open panel.
- Restrict selectable files to supported text/Markdown extensions, with an option to enable all text files.
- Load selected file into active window or a new window.
- Show loading and error states.

**Acceptance Criteria**

- User can open `.md`, `.markdown`, `.mdown`, `.txt`, and `.text`.
- Unsupported files are either disabled or produce a clear error.
- Opening a file updates the window title.
- Errors do not crash the app.

**Implementation Notes**

- Use security-scoped URL access if sandboxing is enabled.
- Decide early whether opening a second file replaces current window content or opens a new window. Recommendation: replace empty windows, open new window when current window has a document.

**Test Notes**

- Open valid file.
- Open missing file from recent list after deletion.
- Try unsupported file.

#### MVP-105: Implement Drag-and-Drop File Opening

- Priority: P0
- Estimate: M
- Dependencies: MVP-104

**Goal**

Support the core macOS workflow of dropping a file onto the app or window.

**Scope**

- Drag file onto empty window.
- Drag file onto existing document window.
- Drag file onto Dock icon.
- Handle multiple dropped files.

**Acceptance Criteria**

- Dropping one supported file opens it.
- Dropping multiple supported files opens multiple windows or tabs according to current window policy.
- Dropping unsupported files shows a clear error.
- Dock icon drop works.

**Implementation Notes**

- Multi-file behavior can be simple for MVP: open separate windows.
- Preserve user intent; if they drop on an empty window, use that window.

**Test Notes**

- Manual Finder drag tests.

#### MVP-106: Add Recent Documents Support

- Priority: P1
- Estimate: S
- Dependencies: MVP-104

**Goal**

Make common repeat use convenient.

**Scope**

- Add opened files to recent documents.
- Support File > Open Recent.
- Handle missing recent files gracefully.

**Acceptance Criteria**

- Opened documents appear in Open Recent.
- Selecting a recent document opens it.
- Missing files show an error and can be cleared.

**Implementation Notes**

- Use native NSDocumentController recent document support where possible.

**Test Notes**

- Open, quit, relaunch, open recent.

#### MVP-107: Add Basic Toolbar

- Priority: P1
- Estimate: M
- Dependencies: MVP-103

**Goal**

Provide visible controls for the MVP workflows.

**Scope**

- Open button.
- Refresh button.
- Toggle outline button.
- Theme selector placeholder.
- Search button placeholder.
- Export button placeholder.

**Acceptance Criteria**

- Toolbar icons use SF Symbols.
- Buttons have accessibility labels and tooltips.
- Buttons map to the same commands as menu items.
- Unavailable commands are disabled appropriately.

**Implementation Notes**

- Keep toolbar compact.
- Avoid text-heavy toolbar buttons.

**Test Notes**

- Manual keyboard and VoiceOver label check.

## Phase 2: Document Model and File Access

### Goal

Represent Markdown source documents safely and consistently.

### Exit Criteria

- Files can be read through a document model.
- Security-scoped access is handled.
- Front matter and metadata are parsed.
- Document statistics can be computed from source text.
- Window restoration can remember file identity.

### Tickets

#### MVP-201: Implement Document Model

- Priority: P0
- Estimate: M
- Dependencies: MVP-101

**Goal**

Create the core source document representation.

**Scope**

- `MarkdownDocument` type.
- Source URL.
- Display name.
- Source text.
- File metadata.
- Last loaded date.
- Optional front matter.

**Acceptance Criteria**

- Document model can be constructed from a URL.
- Document model separates source content from render output.
- Document model can represent loading errors.

**Implementation Notes**

- Keep this independent of SwiftUI.
- Include stable document ID derived from security bookmark or URL.

**Test Notes**

- Unit tests for document creation.

#### MVP-202: Implement Safe File Loading

- Priority: P0
- Estimate: M
- Dependencies: MVP-201

**Goal**

Read Markdown source files reliably.

**Scope**

- Read UTF-8 files.
- Detect UTF-8 BOM.
- Normalize line endings.
- Provide error types for unreadable files, directories, missing files, and encoding issues.
- Add optional fallback for common encodings if feasible.

**Acceptance Criteria**

- Valid UTF-8 Markdown loads correctly.
- Empty files load.
- Missing files produce a user-facing error.
- Binary files do not crash the app.

**Implementation Notes**

- Keep fallback encoding out of MVP unless easy.
- Do not silently mangle text.

**Test Notes**

- Unit tests with normal, empty, BOM, CRLF, and invalid files.

#### MVP-203: Implement Security-Scoped Bookmark Handling

- Priority: P0
- Estimate: L
- Dependencies: MVP-202

**Goal**

Make sandboxed file access reliable across app launches.

**Scope**

- Create bookmarks for opened files.
- Resolve bookmarks on reopen.
- Handle stale bookmarks.
- Stop accessing resources when no longer needed.
- Store minimal bookmark data.

**Acceptance Criteria**

- User-selected files can be reopened after app relaunch.
- Stale bookmarks are refreshed when possible.
- Access failures show clear errors.
- No permanent broad filesystem permissions are required.

**Implementation Notes**

- Even if sandboxing is not enabled at first, design for it now.
- Relative assets may require access to the containing directory. Decide whether opening a file grants access to sibling assets through file URL base access, and test with sandbox on.

**Test Notes**

- Manual sandbox test with files in Documents, Desktop, iCloud, and external folder.

#### MVP-204: Parse Front Matter

- Priority: P1
- Estimate: M
- Dependencies: MVP-202

**Goal**

Support common metadata at the top of Markdown documents.

**Scope**

- Detect YAML-style front matter delimited by `---`.
- Detect TOML-style front matter delimited by `+++` if simple.
- Store raw front matter.
- Extract common keys: title, author, date, description.
- Remove front matter from rendered body by default.

**Acceptance Criteria**

- Documents with front matter render without showing metadata block.
- Title metadata can set window/display title when available.
- Malformed front matter does not break rendering.

**Implementation Notes**

- Use a small parser for MVP. Full YAML parsing can be deferred.
- Preserve raw front matter for future inspector.

**Test Notes**

- Unit tests for valid, missing, empty, and malformed front matter.

#### MVP-205: Compute Basic Source Statistics

- Priority: P0
- Estimate: M
- Dependencies: MVP-202

**Goal**

Provide word count, character count, line count, and reading time.

**Scope**

- Word count.
- Character count.
- Line count.
- Estimated reading time.
- Exclude front matter from word count.
- Optionally strip Markdown syntax for better word counts.

**Acceptance Criteria**

- Status bar can display word count and reading time.
- Empty documents report zero counts.
- Counts update after source reload.

**Implementation Notes**

- MVP counts do not need to be perfect, but they should be unsurprising.
- Use a testable statistics service.

**Test Notes**

- Unit tests for prose, code-heavy, empty, and front matter fixtures.

#### MVP-206: Persist Per-Document Window State

- Priority: P1
- Estimate: M
- Dependencies: MVP-203

**Goal**

Restore useful view state across app launches.

**Scope**

- Window size.
- Sidebar visibility.
- Selected theme.
- Font scale.
- Last opened file reference.

**Acceptance Criteria**

- Reopening a document restores its selected theme and window size where possible.
- Global defaults apply to first-time documents.
- Missing documents show a clean recovery path.

**Implementation Notes**

- Store per-document state keyed by bookmark identity or canonical URL.
- Avoid storing source content.

**Test Notes**

- Manual quit/relaunch tests.

## Phase 3: Markdown Rendering Core

### Goal

Convert Markdown source into reliable HTML through a tested renderer pipeline.

### Exit Criteria

- Renderer abstraction exists.
- `cmark-gfm` or chosen renderer is integrated.
- CommonMark/GFM fixtures render.
- Heading IDs, outline data, and diagnostics are generated.
- Rendering errors are captured and shown.

### Tickets

#### MVP-301: Define Renderer Protocol and Render Types

- Priority: P0
- Estimate: M
- Dependencies: MVP-201

**Goal**

Create a renderer boundary that can survive future renderer changes.

**Scope**

- `MarkdownRenderer` protocol.
- `RenderRequest`.
- `RenderOptions`.
- `RenderResult`.
- `RenderDiagnostic`.
- `OutlineItem`.

**Acceptance Criteria**

- App code can request rendering without knowing the renderer implementation.
- Render result includes body HTML, outline, diagnostics, and statistics references.
- Renderer can be unit tested independently.

**Implementation Notes**

- Keep full HTML document assembly separate from raw Markdown-to-body rendering.

**Test Notes**

- Unit tests with a fake renderer.

#### MVP-302: Integrate cmark-gfm

- Priority: P0
- Estimate: L
- Dependencies: MVP-301

**Goal**

Use a proven Markdown renderer for CommonMark/GFM compatibility.

**Scope**

- Add `cmark-gfm` dependency.
- Enable GFM extensions: table, strikethrough, autolink, task list.
- Render Markdown to HTML body.
- Surface renderer errors.

**Acceptance Criteria**

- Headings, lists, code blocks, tables, task lists, strikethrough, autolinks, and blockquotes render.
- Renderer tests pass for MVP fixtures.
- Dependency is documented.

**Implementation Notes**

- Integration may require a C module map or Swift package wrapper.
- Pin dependency version to avoid surprise output changes.

**Test Notes**

- Fixture tests compare important HTML substrings or normalized output.

#### MVP-303: Add Footnote Support Decision

- Priority: P0
- Estimate: S
- Dependencies: MVP-302

**Goal**

Determine how MVP handles footnotes, since renderer support can vary.

**Scope**

- Verify whether chosen renderer supports footnotes.
- If supported, enable and test.
- If unsupported, document as deferred or add a small extension only if low risk.

**Acceptance Criteria**

- Footnote behavior is documented.
- Fixture test covers expected behavior.
- User-facing docs do not claim unsupported behavior.

**Implementation Notes**

- Do not build a full custom Markdown extension engine for MVP.

**Test Notes**

- Footnote fixture test.

#### MVP-304: Implement HTML Document Assembly

- Priority: P0
- Estimate: M
- Dependencies: MVP-302

**Goal**

Wrap rendered body HTML in a complete preview document.

**Scope**

- HTML doctype.
- Head metadata.
- Theme CSS insertion point.
- Code highlighting insertion point.
- Body wrapper.
- Base URL handling.
- CSP placeholder.

**Acceptance Criteria**

- Rendered HTML can be loaded by WKWebView as a full document.
- Theme CSS can be swapped without changing source render logic.
- HTML export can reuse the same assembly path.

**Implementation Notes**

- Keep preview HTML and export HTML close, but allow export-specific options later.

**Test Notes**

- Unit tests for assembled HTML structure.

#### MVP-305: Generate Stable Heading IDs

- Priority: P0
- Estimate: M
- Dependencies: MVP-304

**Goal**

Support outline navigation and internal links.

**Scope**

- Add IDs to headings without IDs.
- Preserve existing heading IDs from raw HTML where possible.
- Deduplicate repeated headings.
- Follow GitHub-like slug behavior if practical.

**Acceptance Criteria**

- Every Markdown heading has a stable ID.
- Duplicate headings get unique IDs.
- Internal links to headings work for normal cases.

**Implementation Notes**

- Use structured HTML parsing if available.
- If using string transforms, keep them constrained and heavily tested.

**Test Notes**

- Unit tests for heading ID generation and duplicates.

#### MVP-306: Build Outline Extraction

- Priority: P0
- Estimate: M
- Dependencies: MVP-305

**Goal**

Provide heading data for the outline sidebar.

**Scope**

- Extract heading level.
- Extract heading plain text.
- Extract heading ID.
- Preserve document order.
- Mark empty headings gracefully.

**Acceptance Criteria**

- Render result includes outline items.
- Outline matches headings in the rendered document.
- Documents without headings return an empty outline.

**Implementation Notes**

- Derive outline after heading ID generation.

**Test Notes**

- Unit tests with nested heading fixture.

#### MVP-307: Add Render Diagnostics

- Priority: P1
- Estimate: M
- Dependencies: MVP-304

**Goal**

Report render-time warnings without blocking preview.

**Scope**

- Missing local image warnings.
- Unsupported extension warnings.
- Raw HTML blocked warnings if strict mode later disables it.
- Renderer failure diagnostics.

**Acceptance Criteria**

- Diagnostics appear in render result.
- Status bar can show warning count later.
- Diagnostics have severity, message, and optional source/context.

**Implementation Notes**

- Keep diagnostics generic enough for link validation later.

**Test Notes**

- Unit tests for missing image fixture.

#### MVP-308: Add Renderer Fixture Tests

- Priority: P0
- Estimate: L
- Dependencies: MVP-302, MVP-305, MVP-306

**Goal**

Protect rendering correctness.

**Scope**

- Test each MVP fixture.
- Normalize output for stable assertions.
- Assert key HTML features rather than brittle whole-document strings where appropriate.
- Add snapshot update instructions.

**Acceptance Criteria**

- Fixture tests run in CI.
- Tests cover GFM extensions and heading/outline behavior.
- Failing tests point clearly to changed rendering behavior.

**Implementation Notes**

- Whole-output snapshots can be useful but brittle. Combine snapshots with targeted assertions.

**Test Notes**

- CI test pass.

## Phase 4: Preview WebView

### Goal

Display rendered documents beautifully and safely in a native macOS window.

### Exit Criteria

- WKWebView preview loads assembled HTML.
- Local images resolve.
- Preview supports reload and theme updates.
- Preview can preserve or restore scroll position.
- Preview policies block unsafe behavior by default.

### Tickets

#### MVP-401: Create WKWebView Preview Component

- Priority: P0
- Estimate: L
- Dependencies: MVP-304

**Goal**

Embed a reusable WKWebView preview in the app.

**Scope**

- SwiftUI wrapper or AppKit view controller.
- Load HTML string with base URL.
- Report load success/failure.
- Expose reload command.
- Expose JavaScript evaluation helper for internal scripts.

**Acceptance Criteria**

- Preview renders simple HTML.
- Preview updates when new render result arrives.
- Preview errors appear in app state.
- Component is isolated from app shell.

**Implementation Notes**

- WKWebView lifecycle can be tricky in SwiftUI. Use an AppKit wrapper if it reduces churn.

**Test Notes**

- Manual render test.
- Unit test wrapper logic where practical.

#### MVP-402: Resolve Local Assets

- Priority: P0
- Estimate: L
- Dependencies: MVP-401, MVP-203

**Goal**

Render local images and linked assets using document-relative paths.

**Scope**

- Resolve relative image paths against source file directory.
- Support absolute local image paths if permitted.
- Support common image formats handled by WebKit.
- Report missing images as diagnostics.
- Avoid leaking access to unrelated files.

**Acceptance Criteria**

- `![image](image.png)` works for a sibling image.
- `![image](assets/image.png)` works for nested assets.
- Missing images show broken image behavior and diagnostics.
- Sandboxed app can load user-permitted assets.

**Implementation Notes**

- Consider copying or mapping assets into a temporary preview directory if sandbox/base URL behavior is unreliable.
- This ticket is a common risk area. Test early.

**Test Notes**

- Fixture with local images.
- Sandboxed manual test.

#### MVP-403: Implement Preview Reload Flow

- Priority: P0
- Estimate: M
- Dependencies: MVP-401, MVP-302

**Goal**

Connect document loading, rendering, and preview display.

**Scope**

- User opens file.
- App reads source.
- Renderer produces HTML.
- Preview loads HTML.
- Loading indicator appears for slow renders.
- Errors appear clearly.

**Acceptance Criteria**

- Opening a Markdown file displays rendered preview.
- Invalid source shows a friendly error state.
- Refresh command re-renders current source.

**Implementation Notes**

- Introduce a render coordinator to avoid doing all work in view code.

**Test Notes**

- Manual open and refresh tests.

#### MVP-404: Add Preview Navigation Bridge

- Priority: P0
- Estimate: M
- Dependencies: MVP-401, MVP-306

**Goal**

Allow native UI to scroll the preview to headings and locations.

**Scope**

- JavaScript function to scroll to element by ID.
- Native method to call scroll.
- Handle missing IDs gracefully.
- Optional highlight flash on target.

**Acceptance Criteria**

- Clicking an outline item scrolls to heading.
- Missing target does not crash.
- Scroll behavior is smooth unless reduced motion is enabled.

**Implementation Notes**

- Keep JS small and bundled locally.

**Test Notes**

- Manual outline navigation test.

#### MVP-405: Preserve Scroll Position on Reload

- Priority: P1
- Estimate: L
- Dependencies: MVP-403

**Goal**

Make live updates feel stable.

**Scope**

- Capture scroll position before reload.
- Restore scroll position after reload.
- Prefer element-relative restoration if possible.
- Fall back to percentage-based restoration.

**Acceptance Criteria**

- Editing a document does not snap preview to top in normal cases.
- Large documents restore to approximately the same section.
- Empty and short documents behave normally.

**Implementation Notes**

- Element-relative restoration is better but more complex.
- MVP can start with scroll percentage, then improve.

**Test Notes**

- Manual edit/reload tests with long document.

#### MVP-406: Add Preview Security Policy

- Priority: P0
- Estimate: M
- Dependencies: MVP-401

**Goal**

Prevent surprising network/script behavior in local previews.

**Scope**

- Decide raw HTML behavior.
- Block remote scripts.
- Add preference placeholder for remote images.
- Prevent navigation inside preview from unexpectedly replacing document.
- External links open in default browser.

**Acceptance Criteria**

- Clicking external links opens default browser.
- Remote scripts do not execute by default.
- Remote image behavior is controlled by setting or documented default.
- Navigation policy is tested manually.

**Implementation Notes**

- Mermaid/KaTeX will need local scripts later; do not block bundled local scripts.

**Test Notes**

- Fixture with external links, remote image, and script tag.

## Phase 5: Theme System and Visual Design

### Goal

Make the preview beautiful by default and easy to restyle.

### Exit Criteria

- Theme model exists.
- Three to five built-in themes are available.
- Dark mode works.
- Print CSS exists.
- Font scale works.
- Code highlighting looks good.

### Tickets

#### MVP-501: Define Theme Model

- Priority: P0
- Estimate: M
- Dependencies: MVP-304

**Goal**

Represent preview styles in a way that supports built-ins and future custom CSS.

**Scope**

- Theme ID.
- Theme name.
- Screen CSS.
- Print CSS.
- Code highlighting style.
- Dark mode support metadata.
- Default layout settings such as max width.

**Acceptance Criteria**

- Theme can be loaded by ID.
- Theme CSS can be injected into preview HTML.
- Missing theme falls back to default.

**Implementation Notes**

- Store built-in theme files as app resources.
- Avoid hardcoding huge CSS strings in Swift.

**Test Notes**

- Unit tests for theme loading and fallback.

#### MVP-502: Build Default Theme

- Priority: P0
- Estimate: L
- Dependencies: MVP-501, MVP-401

**Goal**

Create the primary visual identity for OpenMarked.

**Scope**

- Body typography.
- Headings.
- Links.
- Blockquotes.
- Lists.
- Tables.
- Code blocks.
- Task lists.
- Images.
- Footnotes.
- Horizontal rules.
- Light and dark variants.
- Print rules.

**Acceptance Criteria**

- Default theme looks polished with MVP fixtures.
- Theme supports light and dark mode.
- Long prose is comfortable to read.
- Code-heavy documents remain clear.
- Tables do not look broken.

**Implementation Notes**

- This is a high-impact ticket. Do visual QA with real documents.
- Avoid novelty colors. The document should feel calm and professional.

**Test Notes**

- Manual screenshot review across fixtures.
- Print preview check.

#### MVP-503: Build GitHub-Like Theme

- Priority: P0
- Estimate: M
- Dependencies: MVP-501

**Goal**

Support README and developer documentation workflows.

**Scope**

- Approximate GitHub Markdown layout.
- GitHub-like table, code, task list, and heading styling.
- Light and dark variants.
- Print rules.

**Acceptance Criteria**

- README fixture visually resembles GitHub enough for local confidence.
- Code blocks and tables are readable.
- Theme does not use GitHub proprietary assets.

**Implementation Notes**

- It is fine to approximate behavior and styling; do not copy protected assets.

**Test Notes**

- Manual comparison with public GitHub rendering.

#### MVP-504: Build Minimal/Print Theme

- Priority: P1
- Estimate: M
- Dependencies: MVP-501

**Goal**

Provide a clean theme for export and print.

**Scope**

- Simple typography.
- Strong print behavior.
- Minimal colors.
- Good PDF output.

**Acceptance Criteria**

- PDF export from this theme looks professional.
- Page margins and code blocks are readable.
- Dark mode does not compromise print output.

**Implementation Notes**

- This can become the default PDF theme if screen themes print poorly.

**Test Notes**

- Manual PDF export check.

#### MVP-505: Add Theme Picker

- Priority: P0
- Estimate: M
- Dependencies: MVP-501, MVP-502, MVP-503

**Goal**

Let users switch preview themes.

**Scope**

- Toolbar theme picker.
- View menu theme submenu if feasible.
- Persist selected theme globally.
- Persist selected theme per document if MVP-206 is complete.

**Acceptance Criteria**

- Switching theme updates current preview.
- Default theme applies to new documents.
- Theme selection survives app relaunch.

**Implementation Notes**

- Avoid re-rendering Markdown if only CSS changes, unless easier for MVP.

**Test Notes**

- Manual theme switch tests.

#### MVP-506: Add Code Highlighting

- Priority: P0
- Estimate: L
- Dependencies: MVP-304, MVP-501

**Goal**

Make fenced code blocks useful and attractive.

**Scope**

- Pre-highlight common MVP languages in Swift.
- Include CSS per theme.
- Support language identifiers.
- Handle unknown languages.

**Acceptance Criteria**

- Code blocks with language identifiers are highlighted.
- Unknown languages fall back to plain code.
- Highlighting works offline.
- Highlighting works in exported HTML.

**Implementation Notes**

- Pre-highlighting keeps preview and export offline without requiring remote or bundled code-highlighting JavaScript.

**Test Notes**

- Fixture with Swift, JavaScript, HTML, JSON, shell, unknown language.

#### MVP-507: Add Font Scale Controls

- Priority: P1
- Estimate: M
- Dependencies: MVP-501

**Goal**

Support comfortable reading without editing theme CSS.

**Scope**

- View > Zoom In.
- View > Zoom Out.
- View > Actual Size.
- Status bar font scale indicator.
- Persist global and per-document font scale.

**Acceptance Criteria**

- Font scale changes preview text without breaking layout.
- Scale survives reload.
- Keyboard shortcuts work.

**Implementation Notes**

- Prefer CSS custom property such as `--om-font-scale`.

**Test Notes**

- Manual layout check at small and large scales.

## Phase 6: Live Preview

### Goal

Make OpenMarked follow edits from external editors reliably.

### Exit Criteria

- Opened files are watched.
- Changes trigger debounced reload and render.
- App handles saves, atomic writes, and missing files gracefully.
- Preview updates without stealing focus.

### Tickets

#### MVP-601: Implement File Watcher Abstraction

- Priority: P0
- Estimate: L
- Dependencies: MVP-202

**Goal**

Create a reusable file watching service.

**Scope**

- Watch a single file URL.
- Emit change events.
- Stop watching.
- Handle file replacement.
- Provide debounced event stream.

**Acceptance Criteria**

- Watcher detects normal saves.
- Watcher detects atomic save replacement.
- Watcher can be stopped cleanly.
- No file descriptors leak during repeated opens.

**Implementation Notes**

- Use DispatchSource for direct file watching and consider FSEvents for replacement detection.
- Many editors save by writing a temp file and renaming it. Test this early.

**Test Notes**

- Unit or integration tests if feasible.
- Manual tests with VS Code, Vim, and TextEdit.

#### MVP-602: Connect Watcher to Render Pipeline

- Priority: P0
- Estimate: M
- Dependencies: MVP-403, MVP-601

**Goal**

Update preview automatically when the source file changes.

**Scope**

- Start watcher when document opens.
- On change, reload source.
- Re-render.
- Update preview.
- Update stats and outline.
- Show file watching state in status bar.

**Acceptance Criteria**

- Editing and saving in external editor updates preview.
- Preview does not steal focus from editor.
- Status bar indicates when update occurred or file is watching.

**Implementation Notes**

- Use a render coordinator queue to avoid overlapping renders.

**Test Notes**

- Manual edit/save tests.

#### MVP-603: Debounce and Coalesce Updates

- Priority: P0
- Estimate: M
- Dependencies: MVP-602

**Goal**

Avoid flicker and partial renders during rapid saves.

**Scope**

- Debounce file change events.
- Skip duplicate events for unchanged content.
- Cancel or supersede stale render requests.
- Avoid rendering partially written files.

**Acceptance Criteria**

- Rapid repeated saves produce a stable preview.
- Large file saves do not cause repeated flicker.
- Render queue does not grow unbounded.

**Implementation Notes**

- Start with 150-300 ms debounce.
- Compare content hash before rendering.

**Test Notes**

- Scripted rapid write test.

#### MVP-604: Handle File Missing, Moved, or Permission Lost

- Priority: P0
- Estimate: M
- Dependencies: MVP-602

**Goal**

Fail gracefully when the watched file disappears.

**Scope**

- Missing file state.
- Permission error state.
- Retry/reveal/reopen actions.
- Watcher cleanup.

**Acceptance Criteria**

- Deleting the source file does not crash app.
- Moving the file shows a clear state.
- Restoring file allows preview to recover if possible.

**Implementation Notes**

- macOS file coordination can get complex. MVP can show a clear reopen prompt.

**Test Notes**

- Manual delete, move, rename tests.

#### MVP-605: Watch Local Image Assets

- Priority: P1
- Estimate: L
- Dependencies: MVP-402, MVP-601

**Goal**

Update preview when referenced local images change.

**Scope**

- Extract local image paths from render result.
- Watch those files.
- Re-render or reload preview when assets change.
- Handle missing assets.

**Acceptance Criteria**

- Editing/replacing a referenced image updates preview after save.
- Missing image warning updates when image appears.
- Watchers are cleaned up when document changes.

**Implementation Notes**

- This is valuable for docs workflows but can slip if MVP schedule gets tight.

**Test Notes**

- Manual replace image test.

#### MVP-606: Add Update Feedback

- Priority: P1
- Estimate: S
- Dependencies: MVP-602

**Goal**

Make live updates visible without being distracting.

**Scope**

- Status bar "Updated just now" text.
- Optional subtle flash or progress indicator.
- Render error badge.

**Acceptance Criteria**

- User can tell updates are happening.
- Feedback does not interrupt reading.
- Reduced motion setting is respected.

**Implementation Notes**

- Keep this subtle. The preview should feel calm.

**Test Notes**

- Manual visual check.

## Phase 7: Navigation and Document Tools

### Goal

Make long documents comfortable to inspect and read.

### Exit Criteria

- Outline sidebar works.
- Search works.
- Status bar shows stats.
- Source file actions work.
- Basic diagnostics are visible.

### Tickets

#### MVP-701: Implement Outline Sidebar

- Priority: P0
- Estimate: L
- Dependencies: MVP-306, MVP-404

**Goal**

Let users navigate by heading.

**Scope**

- Sidebar list of outline items.
- Indentation by heading level.
- Click to scroll.
- Empty outline state.
- Toggle sidebar.

**Acceptance Criteria**

- Outline appears for documents with headings.
- Clicking heading scrolls preview.
- Sidebar can be hidden and restored.
- Current document reload updates outline.

**Implementation Notes**

- Current-section tracking can be deferred.
- Keep indentation readable and compact.

**Test Notes**

- Manual nested heading test.

#### MVP-702: Add Outline Filtering

- Priority: P1
- Estimate: M
- Dependencies: MVP-701

**Goal**

Make large outlines navigable.

**Scope**

- Filter field in outline sidebar.
- Match heading text.
- Preserve hierarchy or show flat filtered results.
- Keyboard focus behavior.

**Acceptance Criteria**

- Typing filters outline.
- Selecting filtered result scrolls preview.
- Clearing filter restores full outline.

**Implementation Notes**

- Flat filtered results are acceptable for MVP.

**Test Notes**

- Manual long document test.

#### MVP-703: Implement Preview Search

- Priority: P0
- Estimate: L
- Dependencies: MVP-401

**Goal**

Let users search rendered document text.

**Scope**

- Search field or find bar.
- Keyboard shortcut Command-F.
- Highlight matches.
- Next/previous match.
- Case-insensitive default.
- Escape closes search.

**Acceptance Criteria**

- Search finds visible preview text.
- Next/previous works.
- Search results are highlighted.
- No document source editing is implied.

**Implementation Notes**

- WKWebView native find APIs may be limited depending on macOS version. A small JS search implementation may be more predictable.

**Test Notes**

- Manual search in headings, paragraphs, code blocks, and tables.

#### MVP-704: Add Status Bar Statistics

- Priority: P0
- Estimate: M
- Dependencies: MVP-205, MVP-602

**Goal**

Show useful document metadata at a glance.

**Scope**

- Word count.
- Reading time.
- Character count in tooltip or secondary display.
- Warning count.
- File watching status.

**Acceptance Criteria**

- Stats update after render.
- Empty files show sensible values.
- Status bar remains visually stable.

**Implementation Notes**

- Keep status text short.

**Test Notes**

- Manual checks with fixtures.

#### MVP-705: Add Source File Actions

- Priority: P1
- Estimate: M
- Dependencies: MVP-104

**Goal**

Help users move between preview and source.

**Scope**

- Reveal in Finder.
- Open in default editor.
- Copy file path.
- Reload from disk.

**Acceptance Criteria**

- Actions work from menu and toolbar/more menu.
- Missing files disable or show clear errors.
- Open in editor uses macOS default app for file type.

**Implementation Notes**

- Configurable external editor can wait.

**Test Notes**

- Manual Finder/editor tests.

#### MVP-706: Show Render Diagnostics

- Priority: P1
- Estimate: M
- Dependencies: MVP-307, MVP-704

**Goal**

Make warnings visible and actionable.

**Scope**

- Warning count in status bar.
- Popover or simple list of diagnostics.
- Missing image messages.
- Render error messages.

**Acceptance Criteria**

- User can see what warnings exist.
- Clicking warning can navigate where possible, or at least describe the issue.
- Warnings update after reload.

**Implementation Notes**

- A simple popover is enough for MVP.

**Test Notes**

- Missing image fixture.

#### MVP-707: Implement Link Click Behavior

- Priority: P0
- Estimate: M
- Dependencies: MVP-406

**Goal**

Make links behave like a Mac document preview.

**Scope**

- External links open in default browser.
- Internal anchor links scroll inside preview.
- Local file links open or reveal according to policy.
- Copy link option can be deferred.

**Acceptance Criteria**

- External links do not replace preview.
- Anchor links work.
- Unsafe or inaccessible local file links show clear feedback.

**Implementation Notes**

- This overlaps with preview security policy but should be tested as UX.

**Test Notes**

- Fixture with external, internal, and local links.

## Phase 8: Export and Print

### Goal

Let users turn previews into useful deliverables.

### Exit Criteria

- Standalone HTML export works.
- PDF export works.
- Print works.
- Copy HTML works.
- Export failures are visible and recoverable.

### Tickets

#### MVP-801: Implement Standalone HTML Export

- Priority: P0
- Estimate: L
- Dependencies: MVP-304, MVP-501, MVP-506

**Goal**

Export rendered Markdown as a complete HTML document.

**Scope**

- Save panel.
- Use current render result.
- Include theme CSS.
- Include code highlighting CSS/JS if needed.
- Optionally embed local images or copy relative assets.
- Add metadata title.

**Acceptance Criteria**

- Exported HTML opens in a browser.
- Exported HTML looks like the preview.
- Code highlighting works offline or gracefully degrades.
- Local images work according to selected export option.

**Implementation Notes**

- MVP can default to embedding local images as data URLs for portability, with a setting later.
- If data URL embedding is risky, document relative asset behavior.

**Test Notes**

- Export fixture docs and open in browser.

#### MVP-802: Implement Copy Rendered HTML

- Priority: P0
- Estimate: M
- Dependencies: MVP-304

**Goal**

Let users copy HTML snippets for blogs, CMS tools, and docs.

**Scope**

- Menu command.
- Keyboard shortcut.
- Copy body HTML or full HTML depending on command naming.
- Show success feedback.

**Acceptance Criteria**

- Clipboard receives rendered HTML.
- Command is disabled when no document is open.
- User receives non-disruptive confirmation.

**Implementation Notes**

- MVP can copy body HTML. Add "Copy Full HTML" later if needed.

**Test Notes**

- Paste into text editor and verify HTML.

#### MVP-803: Implement Print

- Priority: P0
- Estimate: L
- Dependencies: MVP-401, MVP-501

**Goal**

Support native print workflow.

**Scope**

- File > Print.
- Print current preview using print CSS.
- Standard macOS print panel.

**Acceptance Criteria**

- Print command opens print panel.
- Output uses print CSS.
- No app crash on cancel.
- Tables and code blocks are readable.

**Implementation Notes**

- WKWebView print APIs can be awkward. Spike early if needed.

**Test Notes**

- Manual print preview test.

#### MVP-804: Implement PDF Export

- Priority: P0
- Estimate: L
- Dependencies: MVP-803

**Goal**

Let users save a PDF from the rendered document.

**Scope**

- Save panel.
- Generate PDF using print layout.
- Respect print CSS.
- Use document title for default filename.

**Acceptance Criteria**

- PDF export produces a readable PDF.
- Output looks professional with default and minimal themes.
- Export cancellation is safe.
- Export errors are shown.

**Implementation Notes**

- If direct PDF generation from WKWebView is unreliable, use print operation or WebKit PDF data APIs available for target macOS.

**Test Notes**

- Export PDF from prose, README, and code-heavy fixtures.

#### MVP-805: Add Export Error Handling

- Priority: P0
- Estimate: M
- Dependencies: MVP-801, MVP-804

**Goal**

Make export failures understandable.

**Scope**

- Error model for export failures.
- User-facing messages.
- Retry path.
- Permission failure handling.

**Acceptance Criteria**

- Failed exports do not crash.
- User sees what went wrong.
- Cancelled exports are not treated as errors.

**Implementation Notes**

- Keep messages short and specific.

**Test Notes**

- Export to unwritable location if possible.

#### MVP-806: Add Export Smoke Tests

- Priority: P1
- Estimate: M
- Dependencies: MVP-801, MVP-804

**Goal**

Catch obvious export regressions.

**Scope**

- HTML export test for fixture document.
- Validate exported file contains expected structure.
- PDF export smoke test if stable in CI.

**Acceptance Criteria**

- HTML export test runs in CI.
- PDF export has at least manual checklist if CI is impractical.

**Implementation Notes**

- Avoid brittle visual PDF assertions in MVP.

**Test Notes**

- CI pass.

## Phase 9: Settings, Accessibility, and Polish

### Goal

Finish the MVP experience so it feels like a real Mac app.

### Exit Criteria

- Settings exist.
- Keyboard shortcuts work.
- Accessibility labels and navigation are reasonable.
- Dark mode and reduced motion are respected.
- Window/document restoration works.
- MVP docs exist.

### Tickets

#### MVP-901: Build Settings Window

- Priority: P0
- Estimate: L
- Dependencies: MVP-505, MVP-602, MVP-801

**Goal**

Let users configure MVP behavior.

**Scope**

- Default theme.
- Font scale default.
- Live updates on/off.
- Preserve scroll position on/off.
- Remote image loading default.
- Raw HTML behavior.
- HTML export CSS embedding default.

**Acceptance Criteria**

- Settings are available from app menu.
- Changes persist across relaunch.
- Settings affect new and current documents where appropriate.

**Implementation Notes**

- Use SwiftUI Settings scene if it fits.
- Keep settings minimal and understandable.

**Test Notes**

- Manual settings persistence test.

#### MVP-902: Wire All Keyboard Shortcuts

- Priority: P0
- Estimate: M
- Dependencies: MVP-103, MVP-703, MVP-801, MVP-804

**Goal**

Make the app efficient for keyboard users.

**Scope**

- Open.
- Close.
- Find.
- Find next/previous.
- Reload.
- Toggle outline.
- Export HTML.
- Export PDF.
- Copy HTML.
- Print.
- Zoom in/out/actual size.

**Acceptance Criteria**

- Shortcuts work from active document window.
- Shortcuts are discoverable in menus.
- Disabled commands do not fire.

**Implementation Notes**

- Avoid conflicting with system shortcuts.

**Test Notes**

- Manual shortcut pass.

#### MVP-903: Accessibility Pass

- Priority: P0
- Estimate: L
- Dependencies: MVP-102, MVP-107, MVP-701, MVP-703, MVP-901

**Goal**

Ensure MVP is usable with assistive technologies and keyboard-only workflows.

**Scope**

- Accessibility labels for toolbar buttons.
- VoiceOver-friendly empty and error states.
- Keyboard focus order.
- Visible focus rings.
- Sidebar/search navigation.
- Reduced motion behavior.
- Color contrast check for themes.

**Acceptance Criteria**

- Basic VoiceOver navigation identifies controls.
- User can open, search, toggle outline, and export using keyboard.
- Theme colors pass reasonable contrast checks.
- Smooth animations respect reduced motion.

**Implementation Notes**

- Accessibility is easier to fix before UI complexity grows.

**Test Notes**

- Manual VoiceOver smoke test.
- Keyboard-only checklist.

#### MVP-904: Dark Mode and Appearance QA

- Priority: P0
- Estimate: M
- Dependencies: MVP-502, MVP-503, MVP-901

**Goal**

Ensure app chrome and themes work in light and dark appearance.

**Scope**

- App chrome.
- Preview themes.
- Code highlighting.
- Search highlights.
- Outline sidebar.
- Status bar.
- Export behavior.

**Acceptance Criteria**

- Light and dark mode both look intentional.
- No unreadable text.
- PDF export remains print-friendly.

**Implementation Notes**

- Dark preview should not imply dark PDF unless explicitly selected.

**Test Notes**

- Manual screenshots in both appearances.

#### MVP-905: Window and App Restoration

- Priority: P1
- Estimate: M
- Dependencies: MVP-206, MVP-505

**Goal**

Make repeated app use feel native.

**Scope**

- Restore last open windows if enabled by system.
- Restore window size.
- Restore sidebar state.
- Restore theme and font scale.
- Handle missing files.

**Acceptance Criteria**

- Relaunch restores useful state.
- Missing files produce clean recovery UI.
- App does not open duplicate windows unexpectedly.

**Implementation Notes**

- Native restoration can be finicky. Keep behavior simple.

**Test Notes**

- Manual relaunch tests.

#### MVP-906: Add User Documentation

- Priority: P1
- Estimate: M
- Dependencies: MVP-801, MVP-901

**Goal**

Help users understand what MVP can and cannot do.

**Scope**

- README usage section.
- Supported Markdown features.
- Opening files.
- Live preview.
- Themes.
- Export.
- Known limitations.
- Privacy notes.

**Acceptance Criteria**

- New users can build and use the app from README.
- Known limitations are honest.
- Docs do not advertise deferred features.

**Implementation Notes**

- Screenshots can wait until final QA.

**Test Notes**

- Manual documentation review.

#### MVP-907: Add Issue Templates and Feedback Links

- Priority: P2
- Estimate: S
- Dependencies: MVP-006

**Goal**

Prepare for public feedback.

**Scope**

- Bug report template.
- Rendering issue template.
- Feature request template.
- Include environment fields.

**Acceptance Criteria**

- Users can report rendering bugs with fixture/source examples.
- Templates ask for macOS version and app version.

**Implementation Notes**

- Keep templates lightweight.

**Test Notes**

- Manual review.

## Phase 10: QA, Packaging, and Release

### Goal

Stabilize and ship the MVP.

### Exit Criteria

- All P0 tickets are complete.
- P1 tickets selected for MVP are complete or explicitly deferred.
- Manual QA checklist passes.
- Build artifact is available.
- Release notes are written.

### Tickets

#### MVP-1001: Create Manual QA Checklist

- Priority: P0
- Estimate: M
- Dependencies: MVP-000

**Goal**

Define the final manual test pass.

**Scope**

- Opening workflows.
- Rendering fixtures.
- File watching.
- Local images.
- Theme switching.
- Outline/search.
- Stats.
- Export HTML.
- Export PDF.
- Print.
- Settings.
- Accessibility.
- Dark mode.
- Error states.

**Acceptance Criteria**

- Checklist exists in `Docs/QA.md`.
- Checklist can be run by a contributor.
- Checklist maps to MVP acceptance criteria.

**Implementation Notes**

- Include "expected result" for each step.

**Test Notes**

- Run checklist before release.

#### MVP-1002: Run Fixture Visual QA

- Priority: P0
- Estimate: L
- Dependencies: MVP-502, MVP-503, MVP-703, MVP-801, MVP-804

**Goal**

Confirm the MVP looks good on real documents.

**Scope**

- Open all fixtures.
- Capture screenshots.
- Inspect themes.
- Inspect dark mode.
- Inspect PDF output.
- Record visual bugs.

**Acceptance Criteria**

- No obvious layout breakage in MVP fixtures.
- Tables, code blocks, images, and lists look acceptable.
- Any known visual issues are documented.

**Implementation Notes**

- This phase will produce many small polish tickets.

**Test Notes**

- Manual screenshots.

#### MVP-1003: Performance Smoke Test

- Priority: P1
- Estimate: M
- Dependencies: MVP-602, MVP-703

**Goal**

Make sure MVP feels fast enough.

**Scope**

- Measure open time for small, medium, and long fixtures.
- Measure render time.
- Measure live update latency.
- Measure search responsiveness.

**Acceptance Criteria**

- Typical documents render quickly enough to feel immediate.
- Long documents remain usable.
- No obvious UI freezes during normal save/reload.

**Implementation Notes**

- Add lightweight logging or debug metrics if helpful.

**Test Notes**

- Manual timed tests.

#### MVP-1004: Package Debug/Developer Build

- Priority: P0
- Estimate: M
- Dependencies: MVP-004

**Goal**

Produce an app artifact users can download and run.

**Scope**

- Build Release configuration.
- Sign app for local distribution if possible.
- Create ZIP or DMG.
- Document installation steps.

**Acceptance Criteria**

- Artifact launches on another Mac with compatible macOS.
- Gatekeeper behavior is documented.
- Version number is visible.

**Implementation Notes**

- Notarization can be deferred if project does not yet have signing credentials, but document the limitation.

**Test Notes**

- Test on a clean user account or second Mac if available.

#### MVP-1005: Add Versioning and About Window

- Priority: P1
- Estimate: S
- Dependencies: MVP-003

**Goal**

Make builds identifiable.

**Scope**

- App version.
- Build number.
- About window content.
- License link.
- Project website/repo link.

**Acceptance Criteria**

- About window shows app name and version.
- Release artifact version matches release notes.

**Implementation Notes**

- Keep branding temporary if name is not final.

**Test Notes**

- Manual About window check.

#### MVP-1006: Write MVP Release Notes

- Priority: P0
- Estimate: S
- Dependencies: all P0 MVP tickets

**Goal**

Explain what the first release includes.

**Scope**

- Summary.
- Key features.
- Supported Markdown features.
- Known limitations.
- Installation notes.
- How to report bugs.

**Acceptance Criteria**

- Release notes are honest and clear.
- Known limitations include deferred advanced features.
- Links to issues/docs work.

**Implementation Notes**

- Avoid overselling. The app should earn trust.

**Test Notes**

- Manual review.

#### MVP-1007: Final MVP Gate Review

- Priority: P0
- Estimate: M
- Dependencies: MVP-1001, MVP-1002, MVP-1004, MVP-1006

**Goal**

Decide whether `0.1.0` is ready.

**Scope**

- Confirm all P0 tickets complete.
- Review P1 deferrals.
- Review known issues.
- Review user docs.
- Run final QA checklist.
- Create release tag.

**Acceptance Criteria**

- Project owner approves release.
- Release tag exists.
- Public artifact and release notes are available.

**Implementation Notes**

- If major rendering, file watching, or export bugs remain, ship another beta instead.

**Test Notes**

- Full QA checklist pass.

## Cross-Cutting Technical Spikes

These should be handled early if uncertainty threatens the schedule.

### SPIKE-001: cmark-gfm Swift Integration

- Priority: P0
- Estimate: M

**Question**

Can the project integrate `cmark-gfm` cleanly through Swift Package Manager and CI?

**Success Criteria**

- Minimal Swift test renders GFM table and task list.
- CI builds dependency.
- Integration path is documented.

### SPIKE-002: WKWebView PDF Export

- Priority: P0
- Estimate: M

**Question**

Which WKWebView or print API produces the best PDF output for the chosen deployment target?

**Success Criteria**

- Simple rendered HTML exports to PDF.
- Print CSS applies.
- API limitations are documented.

### SPIKE-003: Sandboxed Local Asset Loading

- Priority: P0
- Estimate: M

**Question**

What is the most reliable way to load document-relative images in a sandboxed WKWebView?

**Success Criteria**

- Sibling and nested image assets render.
- Security-scoped access works after relaunch.
- Approach does not require broad filesystem access.

### SPIKE-004: WKWebView Search

- Priority: P1
- Estimate: S

**Question**

Should preview search use WebKit APIs or custom JavaScript?

**Success Criteria**

- Search works in current deployment target.
- Match highlighting and next/previous navigation are possible.
- Accessibility tradeoffs are understood.

## MVP Ticket Dependency Map

Critical path:

1. MVP-002
2. MVP-003
3. MVP-101
4. MVP-102
5. MVP-104
6. MVP-201
7. MVP-202
8. MVP-301
9. MVP-302
10. MVP-304
11. MVP-401
12. MVP-403
13. MVP-501
14. MVP-502
15. MVP-601
16. MVP-602
17. MVP-701
18. MVP-703
19. MVP-801
20. MVP-803
21. MVP-804
22. MVP-901
23. MVP-903
24. MVP-1001
25. MVP-1007

Highest-risk tickets:

- MVP-302: cmark-gfm integration.
- MVP-203: security-scoped bookmarks.
- MVP-402: local asset resolution.
- MVP-506: offline syntax highlighting and export behavior.
- MVP-601: reliable file watching across editor save strategies.
- MVP-803/MVP-804: print and PDF export.

Recommended early spikes:

- SPIKE-001.
- SPIKE-002.
- SPIKE-003.

## Suggested Build Order

### Alpha 1: First Render

Target: app can open a Markdown file and render it.

Tickets:

- MVP-000 through MVP-005.
- MVP-101 through MVP-104.
- MVP-201 through MVP-202.
- MVP-301 through MVP-304.
- MVP-401 and MVP-403.
- MVP-501 and MVP-502.

Exit demo:

- Open `Fixtures/Markdown/readme.md`.
- See rendered Markdown in the app with default theme.

### Alpha 2: Real Preview App

Target: app feels useful for day-to-day preview.

Tickets:

- MVP-105 through MVP-107.
- MVP-203 through MVP-206.
- MVP-305 through MVP-308.
- MVP-402 through MVP-406.
- MVP-503 through MVP-507.
- MVP-601 through MVP-604.
- MVP-701, MVP-703, MVP-704, MVP-707.

Exit demo:

- Open a Markdown file.
- Edit it in VS Code or Vim.
- Preview updates.
- Outline navigation works.
- Search works.
- Theme switching works.

### Beta 1: Export and Settings

Target: app can be used for real output.

Tickets:

- MVP-801 through MVP-805.
- MVP-901 through MVP-906.
- MVP-1001.

Exit demo:

- Export HTML.
- Export PDF.
- Print preview.
- Change settings.
- Run keyboard and accessibility smoke tests.

### MVP Release

Target: public `0.1.0`.

Tickets:

- MVP-1002 through MVP-1007.
- Remaining selected P1 polish.
- All P0 bugs from beta.

Exit demo:

- Fresh user downloads app, opens Markdown, gets a beautiful live preview, searches/navigates, exports HTML/PDF, and understands limitations.

## Backlog Beyond MVP

These can become separate epics after `0.1.0`.

### Post-MVP Epic: Rich Markdown

- Mermaid diagrams.
- KaTeX math.
- GitHub alerts/callouts.
- Better footnotes if not completed.
- Heading permalink UI.
- Local link validation.

### Post-MVP Epic: Custom Themes

- Theme manager.
- Custom CSS import.
- Theme preview gallery.
- Print CSS editor.
- Community theme directory.

### Post-MVP Epic: Publishing Formats

- EPUB export.
- DOCX export through Pandoc integration.
- RTF export.
- TextBundle support.
- Export profiles.

### Post-MVP Epic: Folder and Wiki Workflows

- Folder watching.
- Wiki links.
- Backlinks.
- Multi-file includes.
- Documentation project mode.

### Post-MVP Epic: Automation

- Command line utility.
- URL scheme.
- Shortcuts actions.
- Custom processor rules.
- External command safety model.

## Release Readiness Checklist

Before `0.1.0`, verify:

- All P0 tickets complete.
- All accepted P1 tickets complete or deferred.
- CI green.
- Fixture tests green.
- Manual QA checklist complete.
- App launches cleanly.
- No crash on invalid, missing, empty, or huge documents.
- Live preview works with at least two external editors.
- HTML export works offline for representative documents.
- PDF export looks acceptable.
- App works in light and dark mode.
- Keyboard-only basic workflow works.
- README and release notes are accurate.
