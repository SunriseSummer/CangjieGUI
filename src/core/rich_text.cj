package cui.core

import std.collection.ArrayList
import sdl.{Color, FontSizes, IconName, Rect, Size, UiEvent, drawIcon}

// Gap after an inline icon before the next span.
private let RICH_SPAN_GAP: Float32 = 3.0

// What a span carries: a run of text, or an inline icon.
enum RichSpanKind {
    | SpanText(String)
    | SpanIcon(IconName)
}

/**
 * One styled run in a `RichText`: a run of text or an inline icon, each optionally coloured. Build them
 * with the factories — `RichSpan.text` (default or explicit colour), `RichSpan.muted` (secondary text
 * colour) and `RichSpan.icon`. All text shares the `RichText`'s single point size (the renderer has no
 * bold/italic or per-run baseline metrics), so runs vary by colour and by mixing in icons, not by size.
 */
public struct RichSpan {
    let kind: RichSpanKind
    let color: ?Color
    let isMuted: Bool

    private init(kind: RichSpanKind, color: ?Color, isMuted: Bool) {
        this.kind = kind
        this.color = color
        this.isMuted = isMuted
    }

    /** A run of text in the default text colour, or an explicit `color`. */
    public static func text(text: String, color!: ?Color = None): RichSpan {
        RichSpan(RichSpanKind.SpanText(text), color, false)
    }

    /** A run of text in the theme's secondary (muted) text colour. */
    public static func muted(text: String): RichSpan {
        RichSpan(RichSpanKind.SpanText(text), None, true)
    }

    /** An inline icon, sized to the line and optionally coloured. */
    public static func icon(icon: IconName, color!: ?Color = None): RichSpan {
        RichSpan(RichSpanKind.SpanIcon(icon), color, false)
    }
}

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

    init(x: Float32, y: Float32, kind: PlacedKind, color: ?Color, muted: Bool) {
        this.x = x
        this.y = y
        this.kind = kind
        this.color = color
        this.muted = muted
    }
}

// The result of laying spans out: the placed fragments, the total content height, and the widest line.
struct RichLayout {
    let items: Array<PlacedItem>
    let height: Float32
    let width: Float32

    init(items: Array<PlacedItem>, height: Float32, width: Float32) {
        this.items = items
        this.height = height
        this.width = width
    }
}

/**
 * Inline styled text: a sequence of `RichSpan`s (coloured text runs and inline icons) laid out on one
 * line, wrapping to the available width across as many lines as needed. Text runs share a single point
 * size and vary by colour; icons flow inline with the text. This is the multi-style, text-with-icons
 * counterpart to the single-style `Label`.
 *
 * ```
 * RichText([
 *     RichSpan.icon(IconName.Save, color: ok),
 *     RichSpan.text(" 已保存 ", color: ok),
 *     RichSpan.muted("09:24  "),
 *     RichSpan.text("report.md")
 * ])
 * ```
 */
public class RichText <: Widget {
    private let spans: Array<RichSpan>
    private var pointSize: Length
    private var frame = Rect.zero()
    // The layout is reused across measure and draw for the same width and point size, so wrapping (which
    // runs several renderer measurements) is not redone each pass.
    private var cached: ?RichLayout = None
    private var cachedWidthKey: Float32 = -1.0
    private var cachedPointSize: Float32 = -1.0

    public init(spans: Array<RichSpan>, fontSize!: Length = Length(FontSizes.BODY, LengthUnit.Fp)) {
        this.spans = spans
        this.pointSize = fontSize
        emit(this)
    }

    /** Sets the point size shared by all text runs. */
    public func fontSize(value: Length): RichText {
        pointSize = value
        this
    }

    /** Sets the point size in font pixels. */
    public func fontSize(value: Float32): RichText {
        fontSize(Length(value, LengthUnit.Fp))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
        let layout = layoutFor(ctx, available.w, ps, lineHeight)
        // Hug a single line so inline use in a row sizes to its content; fill the width once it wraps.
        if (layout.height <= lineHeight) {
            Size(min(available.w, layout.width), max(CUI_SMALL_H, lineHeight + 6.0))
        } else {
            Size(available.w, layout.height + 6.0)
        }
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
        let layout = layoutFor(ctx, frame.w, ps, lineHeight)
        let iconSize = richIconSize(lineHeight)
        // Centre the content block vertically, matching Label, so a RichText and a Label in the same
        // row share a baseline instead of the RichText riding measure()'s extra headroom.
        let offsetY = max(0.0, (frame.h - layout.height) / 2.0)
        for (item in layout.items) {
            let px = frame.x + item.x
            let py = frame.y + offsetY + item.y
            let color = colorFor(ctx, item)
            match (item.kind) {
                case PlacedKind.PlacedText(text) => ctx.renderer.text(text, px, py, color, pointSize: ps)
                case PlacedKind.PlacedIcon(icon) =>
                    let iconY = py + (lineHeight - iconSize) / 2.0
                    drawIcon(ctx.renderer, icon, Rect(px, iconY, iconSize, iconSize), color)
            }
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func colorFor(ctx: UiContext, item: PlacedItem): Color {
        match (item.color) {
            case Some(value) => value
            case None =>
                if (item.muted) {
                    ctx.theme.mutedText
                } else {
                    ctx.theme.text
                }
        }
    }

    private func resolvedPointSize(ctx: UiContext): Float32 {
        max(1.0, ctx.resolve(pointSize))
    }

    // Exact float comparison is deliberate: the keys are reused values, so equality means same inputs.
    // A cached single-line layout is also reused for any width it still fits in — measure() hugs a
    // single line to its content width, so draw() asks for exactly layout.width and would otherwise
    // miss the cache (and re-wrap) every frame in the inline-row case.
    private func layoutFor(ctx: UiContext, width: Float32, ps: Float32, lineHeight: Float32): RichLayout {
        match (cached) {
            case Some(layout) where cachedPointSize == ps && (cachedWidthKey == width ||
                (layout.height <= lineHeight && layout.width <= width)) => layout
            case _ =>
                let layout = layoutRichSpans(spans, width, lineHeight, richIconSize(lineHeight), RICH_SPAN_GAP,
                    {text => ctx.renderer.textWidth(text, pointSize: ps)})
                cached = Some(layout)
                cachedWidthKey = width
                cachedPointSize = ps
                layout
        }
    }
}

/** Inline icon side length for a given line height — a touch smaller so it sits within the line. */
func richIconSize(lineHeight: Float32): Float32 {
    max(8.0, lineHeight * 0.82)
}

/*
 * Lays a span list into placed fragments, wrapping to `maxWidth`. Text runs are broken at rune
 * boundaries (so CJK wraps cleanly and long Latin words still break rather than overflow); icons flow
 * inline as square boxes of `iconSize`. `measure` returns a run's width at the target point size, so the
 * engine is pure and testable independent of the font backend. Returns the placed items, the total
 * content height (line count times `lineHeight`), and the widest line.
 */
internal func layoutRichSpans(
    spans: Array<RichSpan>,
    maxWidth: Float32,
    lineHeight: Float32,
    iconSize: Float32,
    spanGap: Float32,
    measure: (String) -> Float32
): RichLayout {
    let placed = ArrayList<PlacedItem>()
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var widest: Float32 = 0.0
    var anyPlaced = false
    for (span in spans) {
        match (span.kind) {
            case RichSpanKind.SpanText(text) =>
                let runes = text.toRuneArray()
                var i = 0
                while (i < runes.size) {
                    var fit = maxRunesFitting(runes, i, maxWidth - x, measure)
                    if (fit == 0) {
                        if (x > 0.0) {
                            // Nothing more fits on this line; wrap and retry the same rune.
                            x = 0.0
                            y += lineHeight
                            continue
                        }
                        // A single rune overflows even a full line; place it anyway to make progress.
                        fit = 1
                    }
                    let segment = richRuneSlice(runes, i, i + fit)
                    placed.add(PlacedItem(x, y, PlacedKind.PlacedText(segment), span.color, span.isMuted))
                    x += measure(segment)
                    widest = max(widest, x)
                    anyPlaced = true
                    i += fit
                }
            case RichSpanKind.SpanIcon(icon) =>
                if (x + iconSize > maxWidth && x > 0.0) {
                    x = 0.0
                    y += lineHeight
                }
                placed.add(PlacedItem(x, y, PlacedKind.PlacedIcon(icon), span.color, false))
                x += iconSize
                widest = max(widest, x)
                x += spanGap
                anyPlaced = true
        }
    }
    let totalHeight: Float32 = if (anyPlaced) {
        y + lineHeight
    } else {
        0.0
    }
    RichLayout(placed.toArray(), totalHeight, widest)
}

// The largest rune count k in [1, remaining] with measure(runes[start..start+k]) <= maxW; 0 if even one
// rune does not fit (or there is no width / no runes left).
private func maxRunesFitting(runes: Array<Rune>, start: Int64, maxW: Float32, measure: (String) -> Float32): Int64 {
    let n = runes.size - start
    if (n <= 0 || maxW <= 0.0) {
        return 0
    }
    // The common case is the whole remaining run fitting; probe it once before binary searching.
    if (measure(richRuneSlice(runes, start, start + n)) <= maxW) {
        return n
    }
    var lo = 1
    var hi = n - 1
    var answer = 0
    while (lo <= hi) {
        let mid = (lo + hi) / 2
        if (measure(richRuneSlice(runes, start, start + mid)) <= maxW) {
            answer = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    answer
}

private func richRuneSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var i = start
    while (i < end) {
        builder.append(runes[i])
        i += 1
    }
    builder.toString()
}
