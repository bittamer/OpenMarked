# OpenMarked Fixture README

OpenMarked is a native macOS Markdown previewer.

## Goals

- Render CommonMark and GitHub Flavored Markdown.
- Provide beautiful themes.
- Follow edits from external editors.
- Export HTML and PDF.

## Code

```swift
struct PreviewDocument {
    var title: String
    var bodyHTML: String
}
```

## Table

| Feature | MVP |
| --- | --- |
| Live preview | Yes |
| DOCX export | No |
| Custom processors | No |

## Links

See [the design document](../../DESIGN.md).

