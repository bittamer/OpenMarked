# Rich Content Dependencies

OpenMarked 0.3.0 renders Mermaid diagrams and KaTeX math using bundled local assets. The preview, export, print, and snapshot flows must not load these assets from a CDN.

## Pinned Packages

These pins were checked against the npm registry on 2026-06-05.

| Package | Version | License | Source |
| --- | --- | --- | --- |
| `mermaid` | `11.15.0` | MIT | `https://github.com/mermaid-js/mermaid` |
| `katex` | `0.17.0` | MIT | `https://github.com/KaTeX/KaTeX` |

## Vendoring Policy

- Runtime assets must be copied into SwiftPM resources before implementation ships.
- CI and normal app builds must not download Mermaid or KaTeX.
- License files must be copied with the vendored assets.
- Version files must record the package name, version, source URL, registry tarball URL, and date vendored.
- Use package-prefixed metadata filenames because SwiftPM processed resources cannot contain duplicate leaf names.
- Updates must be deliberate commits, not floating version ranges.
- Release ASCII checks intentionally exclude the upstream minified Mermaid/KaTeX payloads so those assets remain byte-for-byte vendored from npm.
- KaTeX CSS font references are rewritten through `RichContentAssetStore` so packaged builds load fonts from bundled local files.
- `Scripts/package_release.sh` verifies the packaged app bundle contains OpenMarked rich CSS/runtime, Mermaid runtime/license, KaTeX runtime/CSS/license, and KaTeX WOFF2 fonts.

## Vendored Resource Layout

```text
Sources/OpenMarkedCore/Resources/RichContent/
  Mermaid/
    mermaid.min.js
    Mermaid-LICENSE
    Mermaid-VERSION
  KaTeX/
    katex.min.js
    katex.min.css
    fonts/
      KaTeX_*.ttf
      KaTeX_*.woff
      KaTeX_*.woff2
    KaTeX-LICENSE
    KaTeX-VERSION
  OpenMarked/
    rich-content.css
    rich-content-runtime.js
```

SwiftPM may flatten these files in the generated resource bundle. Runtime code must resolve them through `RichContentAssetStore`, which first checks the source-style relative path and then falls back to unique bundled filenames.

## Verification Commands

Use these commands when refreshing the pins:

```sh
npm view mermaid version license dist.tarball homepage repository.url --json
npm view katex version license dist.tarball homepage repository.url --json
```

The selected versions for 0.3.0 are:

```text
mermaid 11.15.0 MIT
katex 0.17.0 MIT
```

## Security Notes

- Mermaid runs from the bundled asset with `startOnLoad: false`, strict security mode, deterministic IDs, and no CDN dependency.
- KaTeX runs from the bundled asset with `trust: false`, `htmlAndMathml` output, and no CDN dependency.
- OpenMarked preflights empty or obviously malformed math sources in Swift, then keeps runtime parse failures visible with inline fallbacks instead of blanking the preview.
- User-authored `<script>` tags and inline event handlers must remain blocked by the existing preview sanitizer.
- Remote link validation remains disabled by default and must be manual or opt-in if implemented.
