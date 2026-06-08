# OpenMarked 0.5.0 QA Checklist

Use this checklist for release manual QA. Run it on macOS 13 or newer from a clean checkout after `Scripts/verify_release.sh` passes.

## Automated Gate

1. Run `Scripts/verify_release.sh`.
   Expected result: debug build, release build, verifier, performance smoke, visual snapshots, PDF/export artifacts, tests, package description, diff hygiene, ASCII scan, app bundle creation, signing, ZIP creation, and DMG creation all complete.
2. Confirm the packaged `OpenMarked.app` exists under `dist/`.
   Expected result: the app bundle launches.
3. Confirm the packaged macOS ZIP exists under `dist/`.
   Expected result: the ZIP expands to `OpenMarked.app`.
4. Confirm the packaged macOS DMG exists under `dist/`.
   Expected result: the DMG mounts and contains `OpenMarked.app`.
5. Open About OpenMarked.
   Expected result: the About panel shows OpenMarked, current version/build, license, and project URL.
6. Focus OpenMarked and inspect the macOS menu bar.
   Expected result: the top system menu bar switches to OpenMarked and includes standard app/window commands such as About, Settings, Hide, Quit, Window, and Help.

## Opening Workflows

1. Launch OpenMarked with no arguments.
   Expected result: an empty window appears with a clear open action.
2. Use File > Open to open `Fixtures/Markdown/README.md`.
   Expected result: the document renders and the window title changes to `README.md`.
3. Drag `Fixtures/Markdown/gfm.md` into the preview area.
   Expected result: the dropped document replaces the current empty/active target or opens cleanly.
4. Open multiple fixtures at once from the open panel.
   Expected result: supported files open as native tabs in one document window group when a document window is active.
5. Open an unsupported file such as `Package.swift`.
   Expected result: the app shows a readable unsupported-file error.
6. Press Command-Q.
   Expected result: OpenMarked quits through the standard macOS Quit command.

## Native Tabbed Documents

1. Launch OpenMarked and open `Fixtures/Markdown/readme.md`.
   Expected result: the first document renders in the active document window.
2. Use File > Open to select `Fixtures/Markdown/gfm.md` and `Fixtures/Markdown/rich-markdown.md` together.
   Expected result: both files open as native tabs in the active document window group.
3. Use File > Open in New Window... to open `Fixtures/Markdown/prose.md`.
   Expected result: the document opens in a separate top-level document window rather than joining the active tab group.
4. Drag `Fixtures/Markdown/links.md` and `Fixtures/Markdown/local-images.md` onto a loaded document tab.
   Expected result: both dropped files open as tabs in the drop target's native tab group.
5. Open a Markdown fixture from Finder or with `open -a OpenMarked Fixtures/Markdown/front-matter.md`.
   Expected result: the file opens into the current document tab group when OpenMarked is running, without creating a separate file window or extra empty document window.
6. Use Window > Show Next Tab and Window > Show Previous Tab, plus Control-Tab and Control-Shift-Tab.
   Expected result: the selected native tab changes and toolbar/menu commands apply to that selected document.
7. Use Window > Show Tab Bar and Window > Show All Tabs.
   Expected result: macOS shows the native tab bar or tab overview for document windows.
8. Use Window > Merge All Windows with two separate document windows open.
   Expected result: document windows merge into one native tab group.
9. Use Window > Move Tab to New Window.
   Expected result: the selected tab detaches into its own document window.
10. Close one tab in a group with live preview enabled on another tab.
    Expected result: only the closed tab is removed; the remaining tab continues to render and respond to reload/search/export commands.
11. Open Settings and About while document tabs are open.
    Expected result: utility windows do not join the document tab group.

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
- `heading-depth.md`
- `inspection-links-assets.md`
- `json-front-matter.md`
- `links.md`
- `local-images.md`
- `long-document.md`
- `malformed-front-matter.md`
- `math.md`
- `mermaid.md`
- `metadata-rich.md`
- `print-readiness.md`
- `prose.md`
- `raw-html.md`
- `rich-markdown.md`
- `statistics-rich.md`
- `wide-table.md`

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

## Document Inspector

1. Open `Fixtures/Markdown/metadata-rich.md` and show the inspector.
   Expected result: the Summary and Metadata sections show the front matter title, YAML format, standard fields, custom fields, and file facts.
2. Switch to the Statistics section with `Fixtures/Markdown/statistics-rich.md`.
   Expected result: counts include headings, sections, links, images, code blocks, tables, callouts, Mermaid, and math.
3. Switch to Links and Assets with `Fixtures/Markdown/inspection-links-assets.md`.
   Expected result: valid local references, missing references, remote references, malformed links, unsupported schemes, and local image metadata are visible.
4. Switch to Diagnostics with `Fixtures/Markdown/broken-links.md`.
   Expected result: diagnostics are readable and match the popover kinds.
5. Switch to Export with `Fixtures/Markdown/print-readiness.md`.
   Expected result: missing local image, remote image, wide table, and multi-page review notes are visible when applicable.
6. Scroll a long document with the outline visible.
   Expected result: the current outline item and status breadcrumb update as the preview section changes.

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

1. Switch through Default, GitHub, Minimal, Catppuccin, Tokyo Night, Everforest, Nord, Rose Pine, Dracula, and Gruvbox themes.
   Expected result: typography, tables, code blocks, links, callouts, diagrams, and math remain readable.
2. In Settings > Theme Manager, import `Fixtures/Themes/user-fixture.css`, preview it, apply it, rename it, reveal the managed theme folder, and delete it.
   Expected result: the user theme appears beside built-ins, drives the active preview, persists in Settings while present, reveals only app-managed CSS files, and falls back cleanly after deletion.
3. Repeat a fixture check in light appearance and dark appearance.
   Expected result: chrome and preview are readable in both appearances.
4. Enable reduced motion in System Settings.
   Expected result: preview navigation/search uses immediate scrolling instead of smooth scrolling.
5. Navigate primary controls with keyboard.
   Expected result: open, reload, outline, inspector, theme, search, source, export, and settings controls are reachable.
6. Run a VoiceOver smoke pass on the toolbar, empty state, error state, outline, inspector, find bar, and settings.
   Expected result: controls and states have meaningful labels.

## Settings

1. Change render profile in Settings.
   Expected result: the active document re-renders, heading/link behavior follows the selected profile, and the setting persists after relaunch.
2. Change default theme and font scale in Settings.
   Expected result: current and new document windows use the updated defaults where appropriate.
3. Disable Mermaid, KaTeX, and GitHub callouts.
   Expected result: the active rich fixture re-renders with readable fallback Markdown and disabled-feature diagnostics.
4. Disable local link and heading link validation.
   Expected result: link diagnostics for local files/headings disappear while image diagnostics remain independent.
5. Enable remote link reporting.
   Expected result: remote links produce informational skipped-check diagnostics without crawling the network.
6. Disable live updates.
   Expected result: file changes no longer trigger preview reloads until manual reload.
7. Disable preserve scroll position.
   Expected result: reloading returns the preview to the top.
8. Disable remote images.
   Expected result: remote image sources are blocked in preview HTML.
9. Disable raw HTML.
   Expected result: raw HTML is rendered safely as text according to cmark behavior.
10. Change print page size, margins, content width, title, heading page breaks, and print style.
   Expected result: PDF export and native Print use the selected page layout; standalone HTML includes print CSS when CSS embedding is enabled.
11. Disable HTML export CSS embedding.
   Expected result: exported HTML omits embedded style blocks.
12. Enable and disable session restoration.
   Expected result: last-opened paths are retained only while the setting is enabled.
13. With session restoration enabled, open several document tabs, close one tab, quit, and relaunch.
   Expected result: the remaining open document list is restored into native tabs where possible; missing or unsupported saved files are ignored.

## Rich Content Status

1. Open `rich-markdown.md`.
   Expected result: the status bar briefly reports rich content rendering, then rich content ready after Mermaid and KaTeX finish.
2. Open a fixture with intentionally broken Mermaid or malformed math.
   Expected result: the preview remains visible, the status bar reports a concise failure where runtime rendering fails, and the diagnostics popover contains detailed warnings/errors.

## Export And Print

1. Export standalone HTML.
   Expected result: the file writes successfully and opens in a browser.
2. Export `local-images.md` as HTML.
   Expected result: local images are embedded when the setting is enabled.
3. Export `rich-markdown.md` as standalone HTML and open it offline.
   Expected result: callouts, Mermaid diagrams, and KaTeX math render without CDN access; user-authored scripts remain inert or removed.
4. Use Export HTML Again and Export PDF Again after successful exports.
   Expected result: each command prompts for explicit replacement and writes to the previous per-document destination without reopening a save panel.
5. Copy rendered HTML.
   Expected result: pasteboard includes rendered HTML and plain text.
6. Export PDF.
   Expected result: a PDF is created, print CSS keeps the document readable, and rich content has rendered before capture.
7. Print.
   Expected result: the native print panel opens and preview output is readable, including diagrams and equations.

## Export And Print From Tabs

1. Open `Fixtures/Markdown/readme.md` and `Fixtures/Markdown/rich-markdown.md` as tabs.
   Expected result: both tabs render their own document content.
2. Select the README tab and export HTML.
   Expected result: the exported file contains README content and not rich-markdown fixture content.
3. Select the rich Markdown tab and export PDF.
   Expected result: the exported PDF contains rich Markdown content for the selected tab.
4. Use Export HTML Again or Export PDF Again from each tab after a successful export.
   Expected result: repeat export destinations remain per document and prompt before overwrite.
5. Close the README tab and export from the rich Markdown tab again.
   Expected result: export still operates on the remaining selected tab.

## Release Gate

Record the final pass in `Docs/RELEASE.md` before tagging:

- QA runner:
- Date:
- macOS version:
- Commit SHA:
- Artifact path:
- Known issues:
- Release decision:
