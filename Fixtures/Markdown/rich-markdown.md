# Rich Markdown Fixture

This fixture combines the 0.3.0 Markdown Power Pack features in one small document.

> [!NOTE]
> OpenMarked should render GitHub callouts as polished document elements.

## Architecture Diagram

```mermaid
flowchart LR
    Source[Markdown Source] --> Renderer[cmark-gfm]
    Renderer --> Preview[WKWebView Preview]
    Preview --> Export[HTML and PDF Export]
```

## Math

Inline math should render in prose: $a^2 + b^2 = c^2$.

Display math should render as its own block:

$$
\int_0^1 x^2 dx = \frac{1}{3}
$$

## Links

- Jump to [the math section](#math).
- Open the [README fixture](README.md).
- Show the [sample image](../Assets/sample-mark.svg).

![Sample Mark](../Assets/sample-mark.svg)

