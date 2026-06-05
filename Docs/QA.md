# OpenMarked MVP QA Checklist

Use this checklist for release manual QA. Run it on macOS 13 or newer from a clean checkout after `Scripts/verify_release.sh` passes.

## Automated Gate

1. Run `Scripts/verify_release.sh`.
   Expected result: debug build, release build, verifier, performance smoke, visual snapshots, PDF/export artifacts, tests, package description, diff hygiene, ASCII scan, app bundle creation, signing, ZIP creation, and DMG creation all complete.
2. Confirm `dist/OpenMarked-0.2.0/OpenMarked.app` exists.
   Expected result: the app bundle launches.
3. Confirm `dist/OpenMarked-0.2.0-macOS.zip` exists.
   Expected result: the ZIP expands to `OpenMarked.app`.
4. Confirm `dist/OpenMarked-0.2.0-macOS.dmg` exists.
   Expected result: the DMG mounts and contains `OpenMarked.app`.
5. Open About OpenMarked.
   Expected result: the About panel shows OpenMarked, current version/build, license, and project URL.
6. Focus OpenMarked and inspect the macOS menu bar.
   Expected result: the top system menu bar switches to OpenMarked and includes standard app/window commands such as About, Settings, Hide, Quit, Window, and Help.

## Opening Workflows

1. Launch OpenMarked with no arguments.
   Expected result: an empty window appears with a clear open action.
2. Use File > Open to open `Fixtures/Markdown/readme.md`.
   Expected result: the document renders and the window title changes to `readme.md`.
3. Drag `Fixtures/Markdown/gfm.md` into the preview area.
   Expected result: the dropped document replaces the current empty/active target or opens cleanly.
4. Open multiple fixtures at once from the open panel.
   Expected result: each supported file opens in a document window.
5. Open an unsupported file such as `Package.swift`.
   Expected result: the app shows a readable unsupported-file error.
6. Press Command-Q.
   Expected result: OpenMarked quits through the standard macOS Quit command.

## Rendering Fixtures

Open every file in `Fixtures/Markdown`:

- `README.md`
- `broken-links.md`
- `callouts.md`
- `edge-cases.md`
- `footnotes.md`
- `front-matter.md`
- `gfm.md`
- `github-readme-compat.md`
- `links.md`
- `local-images.md`
- `long-document.md`
- `math.md`
- `mermaid.md`
- `prose.md`
- `raw-html.md`
- `rich-markdown.md`

Expected result: no crash, no blank preview, headings render, code blocks keep spacing, tables fit the content width, task lists show checkboxes, footnotes are usable, and front matter is hidden from the rendered body.

For `mermaid.md`, flowchart, sequence, class, state, and ER diagrams should render as SVG diagrams. The intentionally broken Mermaid block should show an inline error and a Mermaid diagnostic without blanking the rest of the preview.

For `math.md`, inline math and display math should render with KaTeX. Escaped dollar amounts, code-span dollars, and the intentionally unmatched delimiter should remain readable as literal text without creating noisy diagnostics.

For `rich-markdown.md`, GitHub callouts, Mermaid diagrams, KaTeX math, and link diagnostics should coexist without overlapping content or leaving blank placeholders.

## File Watching And Local Images

1. Open a fixture in a text editor and save a content change.
   Expected result: OpenMarked updates after a short debounce without stealing focus.
2. Save through an editor that performs atomic replacement.
   Expected result: the document still updates.
3. Open `local-images.md`.
   Expected result: the local SVG renders and no missing-image warning appears.
4. Temporarily rename the local image asset.
   Expected result: a missing-image diagnostic appears.
5. Restore the image asset.
   Expected result: the warning clears after reload/update.

## Navigation And Search

1. Toggle the outline from toolbar and menu.
   Expected result: the sidebar appears/disappears without layout overlap.
2. Filter the outline.
   Expected result: matching headings remain and indentation resets when filtering.
3. Click outline headings.
   Expected result: the preview scrolls to the heading and highlights it briefly.
4. Use Command-F, Command-G, and Shift-Command-G.
   Expected result: preview search opens, highlights matches, and navigates forward/back.
5. Use zoom in, zoom out, and actual size.
   Expected result: rendered text scales between supported bounds.

## Link Validation

1. Open `Fixtures/Markdown/links.md`.
   Expected result: no link diagnostics appear.
2. Open `Fixtures/Markdown/broken-links.md`.
   Expected result: diagnostics include missing local links, a missing heading fragment, an unsupported scheme, a malformed URL, and a missing image.
3. Open the diagnostics popover.
   Expected result: diagnostics are grouped by kind and long sources remain readable without overlapping the popover.
4. Click a valid local link or heading link.
   Expected result: the preview does not replace the document; local/external targets open through macOS behavior.

## Themes, Appearance, And Accessibility

1. Switch through Default, GitHub, and Minimal themes.
   Expected result: typography, tables, code blocks, links, callouts, diagrams, and math remain readable.
2. Repeat a fixture check in light appearance and dark appearance.
   Expected result: chrome and preview are readable in both appearances.
3. Enable reduced motion in System Settings.
   Expected result: preview navigation/search uses immediate scrolling instead of smooth scrolling.
4. Navigate primary controls with keyboard.
   Expected result: open, reload, outline, theme, search, source, export, and settings controls are reachable.
5. Run a VoiceOver smoke pass on the toolbar, empty state, error state, outline, find bar, and settings.
   Expected result: controls and states have meaningful labels.

## Settings

1. Change default theme and font scale in Settings.
   Expected result: current and new document windows use the updated defaults where appropriate.
2. Disable live updates.
   Expected result: file changes no longer trigger preview reloads until manual reload.
3. Disable preserve scroll position.
   Expected result: reloading returns the preview to the top.
4. Disable remote images.
   Expected result: remote image sources are blocked in preview HTML.
5. Disable raw HTML.
   Expected result: raw HTML is rendered safely as text according to cmark behavior.
6. Disable HTML export CSS embedding.
   Expected result: exported HTML omits embedded style blocks.
7. Enable and disable session restoration.
   Expected result: last-opened paths are retained only while the setting is enabled.

## Export And Print

1. Export standalone HTML.
   Expected result: the file writes successfully and opens in a browser.
2. Export `local-images.md` as HTML.
   Expected result: local images are embedded when the setting is enabled.
3. Copy rendered HTML.
   Expected result: pasteboard includes rendered HTML and plain text.
4. Export PDF.
   Expected result: a PDF is created, print CSS keeps the document readable, and rich content has rendered before capture.
5. Print.
   Expected result: the native print panel opens and preview output is readable, including diagrams and equations.

## Release Gate

Record the final pass in `Docs/RELEASE.md` before tagging:

- QA runner:
- Date:
- macOS version:
- Commit SHA:
- Artifact path:
- Known issues:
- Release decision:
