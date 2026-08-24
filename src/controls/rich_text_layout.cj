package cui.controls

import std.collection.ArrayList
import sdl.{Color, FontStyle, IconName}
import cui.core.{graphemeRuneBoundaries, maxRunesFitting, runeSlice}

// A span fragment placed at a position during layout: a text slice or an icon at (x, y) in content space.
enum PlacedKind {
    | PlacedText(String)
    | PlacedIcon(IconName)
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
        highlight!: ?Color
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
        highlight!: ?Color
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
    }
}

extend LaidFrag {
    // Settles this fragment at its final vertical position — the ONE place a LaidFrag becomes a
    // PlacedItem, so the two field lists are never copied across anywhere else.
    func placed(y: Float32): PlacedItem {
        PlacedItem(x: x, y: y, kind: kind, color: color, muted: muted, style: style, font: font, size: size,
            width: width, height: height, spanIndex: spanIndex, onTap: onTap, highlight: highlight)
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

/** Inline icon side length for a given line height — a touch smaller so it sits within the line. */
func richIconSize(lineHeight: Float32): Float32 {
    max(8.0, lineHeight * 0.82)
}

// A rune that belongs to an ASCII word (identifier, number, issue tag): any visible ASCII character.
// CJK and other non-ASCII scripts are excluded on purpose — they break per rune, as convention wants.
internal func isAsciiWordRune(r: Rune): Bool {
    r > r' ' && r <= r'~'
}

// The end (exclusive) of the ASCII word starting at `start`.
internal func asciiWordEnd(runes: Array<Rune>, start: Int64): Int64 {
    var end = start
    while (end < runes.size && isAsciiWordRune(runes[end])) {
        end += 1
    }
    end
}

/*
 * Lays a span list into placed fragments, wrapping to `maxWidth`. Text runs are broken at rune
 * boundaries (so CJK wraps cleanly), with two word-level refinements for scripts that use spaces:
 * a forced break inside a run backs up to fall after the run's last space, and an ASCII word that
 * starts mid-line and would otherwise split moves to the next line whole when it fits one (an
 * identifier or issue tag is never cut in half; a word wider than a full line still rune-splits so
 * nothing overflows). CJK text has no spaces and non-ASCII runes, so both refinements leave it
 * exactly as before — filling every line and breaking anywhere. Icons flow
 * inline as square boxes of `iconSize`. Each span's resolved point size comes from `spanSizes` (parallel
 * to `spans`); `widthOf` returns a run's width and `heightOf` a run's line height, both at the run's
 * size, style, and font (a face carries its own vertical metrics, so heights must come from the same
 * font the run draws with) — so the engine is pure and testable independent of the font backend.
 *
 * Two passes: the first places fragments left-to-right with wrapping, recording each line's height as
 * the tallest fragment on it; the second stacks the lines and centres every fragment within its line,
 * so runs of different sizes align on a common centre and the line grows to the largest. For a uniform
 * size this is identical to top-of-line placement. Returns the placed items, the total content height
 * (sum of line heights), and the widest line.
 */
/*
 * The mutable pen of the first layout pass: the current x, the current line index, the per-line
 * heights, the accumulated fragments and the widest line so far. Extracted so the span-kind
 * placement functions stay small and share one wrapping vocabulary (`wrapLine`, `place`).
 */
class RichFlow {
    let frags = ArrayList<LaidFrag>()
    let lineHeights = ArrayList<Float32>()
    // The wrap width and the inline-icon geometry are flow constants, carried here so the
    // per-span placement functions take only what varies per span.
    let maxWidth: Float32
    let iconSize: Float32
    let spanGap: Float32
    var x: Float32 = 0.0
    var line: Int64 = 0
    var widest: Float32 = 0.0

    init(maxWidth!: Float32, iconSize!: Float32, spanGap!: Float32) {
        this.maxWidth = maxWidth
        this.iconSize = iconSize
        this.spanGap = spanGap
        lineHeights.add(0.0)
    }

    // Starts the next line; the caller retries its current fragment there.
    func wrapLine(): Unit {
        x = 0.0
        line += 1
        lineHeights.add(0.0)
    }

    // Records a fragment at the pen, grows the line height to fit it, and advances the pen.
    func place(frag: LaidFrag): Unit {
        frags.add(frag)
        if (frag.height > lineHeights[line]) {
            lineHeights[line] = frag.height
        }
        x += frag.width
        widest = max(widest, x)
    }
}

// One span with its position and resolved point size — the per-span trio every placement
// function needs; bundled so their signatures stay within the parameter budget.
struct SpanRun {
    let span: RichSpan
    let index: Int64
    let size: Float32

    init(span: RichSpan, index: Int64, size: Float32) {
        this.span = span
        this.index = index
        this.size = size
    }
}

// Places one text run into the flow, wrapping at rune boundaries with the word-level
// refinements documented on `layoutRichSpans`.
private func flowTextSpan(
    flow: RichFlow,
    run: SpanRun,
    text: String,
    fragHeight!: Float32,
    spanMeasure!: (String) -> Float32
): Unit {
    let span = run.span
    let maxWidth = flow.maxWidth
    let runes = text.toRuneArray()
    let graphemeBoundaries = graphemeRuneBoundaries(runes)
    var i = 0
    while (i < runes.size) {
        // A wrapped continuation never starts with the space the line broke on (the
        // i > 0 guard keeps a span's own leading space, e.g. a separator span).
        if (flow.x == 0.0 && i > 0 && runes[i] == r' ') {
            i += 1
            continue
        }
        var fit = maxRunesFitting(runes, i, maxWidth - flow.x, spanMeasure)
        fit = snapToGraphemeBoundary(graphemeBoundaries, i, fit)
        if (fit == 0) {
            fit = resolveOverflowingGrapheme(flow, runes, graphemeBoundaries, i, spanMeasure)
            if (fit < 0) {
                continue
            }
        }
        if (i + fit < runes.size && runes[i + fit] != r' ') {
            // Breaking mid-run: prefer to land just after the run's last space. When no space
            // exists and the break falls inside an ASCII word, move the whole word to the next
            // line when it fits one, instead of cutting it.
            let backed = backUpToSpace(runes, i, fit)
            if (backed == fit && flow.x > 0.0 && isAsciiWordRune(runes[i]) && asciiWordWrapsWhole(runes, i, fit,
                maxWidth, spanMeasure)) {
                flow.wrapLine()
                continue
            }
            fit = backed
        }
        let segment = runeSlice(runes, i, i + fit)
        flow.place(
            LaidFrag(x: flow.x, line: flow.line, height: fragHeight, kind: PlacedKind.PlacedText(segment),
                color: span.color, muted: span.isMuted, style: span.style, font: span.fontFace, size: run.size,
                width: spanMeasure(segment), spanIndex: run.index, onTap: span.tapAction, highlight: span.highlightColor))
        i += fit
    }
}

private func resolveOverflowingGrapheme(
    flow: RichFlow,
    runes: Array<Rune>,
    boundaries: Array<Int64>,
    start: Int64,
    measure: (String) -> Float32
): Int64 {
    let clusterRunes = nextGraphemeBoundary(boundaries, start) - start
    if (measure(runeSlice(runes, start, start + clusterRunes)) <= flow.maxWidth - flow.x) {
        return clusterRunes
    }
    if (flow.x > 0.0) {
        // Retry the whole cluster on a fresh line instead of accepting a partial-rune fit.
        flow.wrapLine()
        return -1
    }
    // A whole user-perceived glyph overflows even a full line; keep it intact and make progress.
    // Layout overflow is recoverable, broken emoji/combining text is not.
    clusterRunes
}

private func snapToGraphemeBoundary(boundaries: Array<Int64>, start: Int64, count: Int64): Int64 {
    let wanted = start + count
    var answer = start
    for (boundary in boundaries) {
        if (boundary > wanted) {
            break
        }
        if (boundary >= start) {
            answer = boundary
        }
    }
    answer - start
}

private func nextGraphemeBoundary(boundaries: Array<Int64>, start: Int64): Int64 {
    for (boundary in boundaries) {
        if (boundary > start) {
            return boundary
        }
    }
    start
}

// The fit shortened to land just after the run's last space, or `fit` unchanged when none exists.
private func backUpToSpace(runes: Array<Rune>, start: Int64, fit: Int64): Int64 {
    var back = fit - 1
    while (back > 0) {
        if (runes[start + back] == r' ') {
            return back + 1
        }
        back -= 1
    }
    fit
}

// Whether the ASCII word being split extends past the fit AND fits a full line on its own.
private func asciiWordWrapsWhole(
    runes: Array<Rune>,
    start: Int64,
    fit: Int64,
    maxWidth: Float32,
    measure: (String) -> Float32
): Bool {
    let wordEnd = asciiWordEnd(runes, start)
    start + fit < wordEnd && measure(runeSlice(runes, start, wordEnd)) <= maxWidth
}

// Places one inline icon into the flow as a square box, wrapping first when it overflows.
private func flowIconSpan(flow: RichFlow, run: SpanRun, icon: IconName): Unit {
    let span = run.span
    let iconSize = flow.iconSize
    if (flow.x + iconSize > flow.maxWidth && flow.x > 0.0) {
        flow.wrapLine()
    }
    flow.place(
        LaidFrag(x: flow.x, line: flow.line, height: iconSize, kind: PlacedKind.PlacedIcon(icon), color: span.color,
            muted: false, style: span.style, font: span.fontFace, size: run.size, width: iconSize, spanIndex: run.index,
            onTap: span.tapAction, highlight: span.highlightColor))
    flow.x += flow.spanGap
}

internal func layoutRichSpans(
    spans: Array<RichSpan>,
    spanSizes: Array<Float32>,
    maxWidth: Float32,
    iconSize: Float32,
    spanGap: Float32,
    widthOf: (String, Float32, FontStyle, ?String) -> Float32,
    heightOf: (Float32, FontStyle, ?String) -> Float32
): RichLayout {
    let flow = RichFlow(maxWidth: maxWidth, iconSize: iconSize, spanGap: spanGap)
    for (si in 0..spans.size) {
        let run = SpanRun(spans[si], si, spanSizes[si])
        let span = run.span
        match (span.kind) {
            case RichSpanKind.SpanText(text) =>
                // Bind this run's size, style, and font so widths reflect the actual metrics (a bigger
                // or bolder run is wider) and wrapping breaks where the run really overflows.
                flowTextSpan(flow, run, text,
                fragHeight: heightOf(run.size, span.style, span.fontFace),
                spanMeasure: {s: String => widthOf(s, run.size, span.style, span.fontFace)})
            case RichSpanKind.SpanIcon(icon) => flowIconSpan(flow, run, icon)
        }
    }
    if (flow.frags.isEmpty()) {
        return RichLayout(Array<PlacedItem>(), 0.0, 0.0, 0)
    }
    // Second pass: stack the lines and centre each fragment within its line's height.
    let lineTops = ArrayList<Float32>()
    var acc: Float32 = 0.0
    for (h in flow.lineHeights) {
        lineTops.add(acc)
        acc += h
    }
    let placed = ArrayList<PlacedItem>()
    for (frag in flow.frags) {
        placed.add(frag.placed(lineTops[frag.line] + (flow.lineHeights[frag.line] - frag.height) / 2.0))
    }
    RichLayout(placed.toArray(), acc, flow.widest, flow.lineHeights.size)
}
