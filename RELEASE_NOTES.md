# OpenMarked 0.3.0

OpenMarked 0.3.0 adds the Markdown Power Pack: GitHub callouts, Mermaid diagrams, KaTeX math, and local link diagnostics in a native macOS Markdown viewer.

## Highlights

- GitHub alert/callout rendering for `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, and `CAUTION` blockquotes.
- Offline Mermaid diagram rendering for fenced `mermaid` blocks.
- Offline KaTeX math rendering for inline `$...$` and display `$$...$$` delimiters.
- Local link diagnostics for missing files, missing heading fragments, unsupported schemes, and malformed URLs.
- Cross-document Markdown heading checks for readable local Markdown files.
- Render profile groundwork, including an OpenMarked profile and a GitHub README compatibility profile for heading slug behavior.
- Settings controls for Mermaid, KaTeX, GitHub callouts, local/heading link diagnostics, and remote link reporting.
- Rich-content status feedback in the status bar with detailed diagnostics in the diagnostics popover.
- Standalone HTML export that can embed local images, theme CSS, and the trusted bundled rich-content runtime.
- PDF export, Print, and visual snapshots wait for Mermaid and KaTeX rendering before capture.
- Visual QA now covers rich Markdown in light and dark appearances plus link-diagnostic fixtures.
- Packaging verifies that Mermaid, KaTeX, OpenMarked rich runtime/CSS, licenses, and KaTeX fonts are present in the app bundle.

## Supported Rich Markdown

The focused user guide is `Docs/RICH_MARKDOWN.md`.

At a high level:

- Callouts use GitHub-style blockquote markers such as `> [!NOTE]`.
- Mermaid diagrams use fenced code blocks with the `mermaid` language.
- Math uses inline `$...$` and display `$$...$$` delimiters.
- Link validation is local-first and runs during rendering.

## Privacy And Network Behavior

OpenMarked remains local-first:

- Document contents are not sent to a service.
- Mermaid `11.15.0` and KaTeX `0.17.0` are bundled local assets, not CDN dependencies.
- Remote scripts and inline event handlers are stripped from preview/export HTML.
- Remote HTTP(S) links are parsed but not crawled during normal rendering.
- Optional remote link reporting produces an informational skipped-check diagnostic instead of contacting the network.
- Remote images load only when the remote image setting is enabled.

## Dependency Attributions

Bundled rich-content dependency details are recorded in `Docs/RICH_CONTENT_DEPENDENCIES.md`.

- Mermaid `11.15.0`, MIT license.
- KaTeX `0.17.0`, MIT license.

License and version metadata are bundled with the app resources.

## Installation

Developer artifacts are created by:

```sh
Scripts/package_release.sh
```

The resulting files are `dist/OpenMarked-0.3.0-macOS.zip` and `dist/OpenMarked-0.3.0-macOS.dmg`.

These developer artifacts are ad hoc signed by default but not notarized unless Apple signing credentials are supplied. On macOS, Gatekeeper may require opening them from Finder's context menu. Only run local developer artifacts from sources you trust.

## Known Limitations

- The app is not notarized by default and does not yet ship as a Homebrew Cask.
- Native print panel behavior should be checked manually before publishing public release artifacts.
- Mermaid and KaTeX coverage follows the bundled upstream runtimes, but OpenMarked does not yet expose advanced per-document runtime configuration.
- Remote link checking does not crawl the network automatically.
- GitHub README compatibility is profile groundwork, not a complete clone of every GitHub rendering edge case.
- Custom themes, plugin processors, DOCX/EPUB export, RTF/RTFD import, Scrivener project rendering, browser integrations, grammar tools, and AI features are deferred.
- Exact visual hash regression checks are optional because OS font and WebKit rendering can vary by environment.

## Reporting Issues

Use the GitHub issue templates for bug reports, rendering issues, and feature requests. Rendering bugs are most useful with a minimal Markdown sample and any local assets needed to reproduce the output.
