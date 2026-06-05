# Mermaid Fixture

OpenMarked 0.3.0 should detect Mermaid code fences before normal code highlighting.

## Flowchart

```mermaid
flowchart TD
    A[Open file] --> B{Has Mermaid?}
    B -->|Yes| C[Render diagram]
    B -->|No| D[Render normal Markdown]
```

## Sequence

```mermaid
sequenceDiagram
    participant User
    participant OpenMarked
    User->>OpenMarked: Open README.md
    OpenMarked-->>User: Render preview
```

## Class

```mermaid
classDiagram
    class MarkdownDocument {
        +String sourceText
        +String displayTitle
    }
    class PreviewRenderer {
        +render()
    }
    MarkdownDocument --> PreviewRenderer
```

## State

```mermaid
stateDiagram-v2
    [*] --> Loaded
    Loaded --> Rendering
    Rendering --> Ready
    Ready --> Rendering: source changed
```

## ER

```mermaid
erDiagram
    DOCUMENT ||--o{ DIAGRAM : contains
    DIAGRAM {
        string id
        string source
    }
```

## Broken Diagram

```mermaid
flowchart TD
    A --> 
```

## Ordinary Code

```swift
let language = "swift"
print(language)
```
