package cui.controls

import cui.media.IconSource
import sdl.{Color, FontStyle}

// A span fragment placed at a position during layout: a text slice or an icon at (x, y) in content space.
enum PlacedKind {
    | PlacedText(String)
    | PlacedIcon(IconSource)
}

struct PlacedItem {
    let x: Float32
    let y: Float32
    let kind: PlacedKind
    let color: ?Color
    let muted: Bool
    let style: FontStyle
    let font: ?String
    // The resolved point size this text fragment draws at (ignored for icons, which use the icon box).
    let size: Float32
    // The fragment's advance width and box height (the icon box for icons; the run's line height at
    // its own size/style/font for text). Together with (x, y) they are the fragment's box — the
    // highlight, the focus ring, and the link hit rect all use it. `spanIndex` is the source span,
    // `onTap` its link action (None for an ordinary fragment).
    let width: Float32
    let height: Float32
    let spanIndex: Int64
    let onTap: ?() -> Unit
    // Some paints a rounded highlight box behind this fragment (carried from the source span).
    let highlight: ?Color
    let paintText: ?String

    // All-named construction: several fields share a type (three Float32 metrics, two ?Color), so
    // positional building would let a silent transposition compile — named arguments make it a
    // compile error instead.
    init(
        x!: Float32,
        y!: Float32,
        kind!: PlacedKind,
        color!: ?Color,
        muted!: Bool,
        style!: FontStyle,
        font!: ?String,
        size!: Float32,
        width!: Float32,
        height!: Float32,
        spanIndex!: Int64,
        onTap!: ?() -> Unit,
        highlight!: ?Color,
        paintText!: ?String = None
    ) {
        this.x = x
        this.y = y
        this.kind = kind
        this.color = color
        this.muted = muted
        this.style = style
        this.font = font
        this.size = size
        this.width = width
        this.height = height
        this.spanIndex = spanIndex
        this.onTap = onTap
        this.highlight = highlight
        this.paintText = paintText
    }
}

// An in-progress fragment during the first layout pass: its x and line index are known, but its final
// y waits until the line's height (the tallest fragment on it) is settled in the second pass.
struct LaidFrag {
    let x: Float32
    let line: Int64
    let height: Float32
    let kind: PlacedKind
    let color: ?Color
    let muted: Bool
    let style: FontStyle
    let font: ?String
    let size: Float32
    let width: Float32
    let spanIndex: Int64
    let onTap: ?() -> Unit
    let highlight: ?Color
    let paintText: ?String

    // All-named for the same reason as PlacedItem: same-typed neighbours must not be transposable.
    init(
        x!: Float32,
        line!: Int64,
        height!: Float32,
        kind!: PlacedKind,
        color!: ?Color,
        muted!: Bool,
        style!: FontStyle,
        font!: ?String,
        size!: Float32,
        width!: Float32,
        spanIndex!: Int64,
        onTap!: ?() -> Unit,
        highlight!: ?Color,
        paintText!: ?String = None
    ) {
        this.x = x
        this.line = line
        this.height = height
        this.kind = kind
        this.color = color
        this.muted = muted
        this.style = style
        this.font = font
        this.size = size
        this.width = width
        this.spanIndex = spanIndex
        this.onTap = onTap
        this.highlight = highlight
        this.paintText = paintText
    }
}

extend LaidFrag {
    // Settles this fragment at its final vertical position — the ONE place a LaidFrag becomes a
    // PlacedItem, so the two field lists are never copied across anywhere else.
    func placed(y: Float32): PlacedItem {
        PlacedItem(x: x, y: y, kind: kind, color: color, muted: muted, style: style, font: font, size: size,
            width: width, height: height, spanIndex: spanIndex, onTap: onTap, highlight: highlight, paintText: paintText)
    }
}

// The result of laying spans out: the placed fragments, the total content height, the widest line,
// and the line count (what "single line" means for hugging — a line's height varies with its runs, so
// comparing heights cannot answer it).
struct RichLayout {
    let items: Array<PlacedItem>
    let height: Float32
    let width: Float32
    let lines: Int64

    init(items: Array<PlacedItem>, height: Float32, width: Float32, lines: Int64) {
        this.items = items
        this.height = height
        this.width = width
        this.lines = lines
    }
}
