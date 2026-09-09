package cui.controls

import cui.media.IconSource
import std.collection.ArrayList
import cui.core.{graphemeRuneBoundaries, maxRunesFitting, runeSlice}

/** Inline icon side length for a given line height — a touch smaller so it sits within the line. */
func richIconSize(lineHeight: Float32): Float32 {
    max(8.0, lineHeight * 0.82)
}

// A rune that belongs to an ASCII word (identifier, number, issue tag): any visible ASCII character.
// CJK and other non-ASCII scripts use grapheme boundaries instead of this ASCII word rule.
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
 * Lays a span list into placed fragments, wrapping to `maxWidth`. Text runs are broken at grapheme
 * boundaries (so CJK wraps cleanly), with two word-level refinements for scripts that use spaces:
 * a forced break inside a run backs up to fall after the run's last space, and an ASCII word that
 * starts mid-line and would otherwise split moves to the next line whole when it fits one (an
 * identifier or issue tag is never cut in half; a word wider than a full line still splits at
 * grapheme boundaries). Mandatory breaks preserve blank lines, including CRLF across spans. Icons flow
 * inline as square boxes of `iconSize`. Each span's resolved point size comes from `spanSizes` (parallel
 * to `spans`); `widthOf` returns a run's width and `heightOf` a run's line height, both at the run's
 * size, style, and font (a face carries its own vertical metrics, so heights must come from the same
 * font the run draws with) — so the engine is pure and testable independent of the font backend.
 *
 * Two passes: the first places fragments left-to-right with wrapping, recording each line's height as
 * the tallest fragment on it; the second aligns baselines and includes each run's descent. When
 * no ascent provider is supplied, it centres the fragments instead. Returns the placed items, the total content height
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
    var pendingCr: Bool = false

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
    let sourceEnds: Array<Int64>

    init(span: RichSpan, index: Int64, size: Float32, sourceEnds!: Array<Int64> = []) {
        this.span = span
        this.index = index
        this.sourceEnds = sourceEnds
        this.size = size
    }
}

// Places one text run into the flow, wrapping at grapheme boundaries with the word-level
// refinements documented on `layoutRichSpans`.
internal func flowWrappedText(
    flow: RichFlow,
    run: SpanRun,
    text: String,
    byteOffset!: Int64 = 0,
    fragHeight!: Float32,
    spanMeasure!: (String) -> Float32
): Unit {
    let maxWidth = flow.maxWidth
    let runes = text.toRuneArray()
    let graphemeBoundaries = graphemeRuneBoundaries(runes)
    var i = 0
    var byteStart = byteOffset
    while (i < runes.size) {
        // A wrapped continuation never starts with the space the line broke on (the
        // i > 0 guard keeps a span's own leading space, e.g. a separator span).
        if (flow.x == 0.0 && i > 0 && runes[i] == r' ') {
            byteStart += 1
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
            let backed = backUpWholeWord(runes, i, backUpToSpace(runes, i, fit), maxWidth, spanMeasure)
            if (backed == fit && flow.x > 0.0 && isAsciiWordRune(runes[i]) && asciiWordWrapsWhole(runes, i, fit,
                maxWidth, spanMeasure)) {
                flow.wrapLine()
                continue
            }
            fit = backed
        }
        let segment = runeSlice(runes, i, i + fit)
        placeRichSegment(flow, run, segment, byteStart, fragHeight, spanMeasure)
        byteStart += segment.size
        i += fit
    }
}

// A joined line is painted once, while its source fragments keep their original span identities.
private func placeRichSegment(flow: RichFlow, run: SpanRun, text: String, byteStart: Int64, height: Float32,
    measure: (String) -> Float32): Unit {
    let ends = if (run.sourceEnds.isEmpty()) {
        [byteStart + text.size]
    } else {
        run.sourceEnds
    }
    let origin = flow.x
    var sourceStart: Int64 = 0
    var painted = false
    for (i in 0..ends.size) {
        let begin = max(byteStart, sourceStart)
        let end = min(byteStart + text.size, ends[i])
        sourceStart = ends[i]
        if (begin >= end) {
            continue
        }
        let prefix = if (begin == byteStart) {
            Float32(0.0)
        } else {
            measure(text[0..begin - byteStart])
        }
        let right = measure(text[0..end - byteStart])
        let span = run.span
        let paint: String = if (painted) {
            ""
        } else {
            text
        }
        painted = true
        flow.place(
            LaidFrag(x: origin + prefix, line: flow.line, height: height,
                kind: PlacedKind.PlacedText(text[begin - byteStart..end - byteStart]), color: span.color,
                muted: span.isMuted, style: span.style, font: span.fontFace, size: run.size,
                width: max(0.0, right - prefix), spanIndex: run.index + i, onTap: span.tapAction,
                highlight: span.highlightColor, paintText: paint))
    }
    flow.x = origin + measure(text)
}

// Coalescing can put an ASCII word after a CJK prefix inside one run. Preserve the word when
// it fits a full line, just as the old per-span start-of-word rule did.
private func backUpWholeWord(runes: Array<Rune>, start: Int64, fit: Int64, maxWidth: Float32,
    measure: (String) -> Float32): Int64 {
    if (start + fit >= runes.size || !isAsciiWordRune(runes[start + fit])) {
        return fit
    }
    var wordStart = start + fit
    while (wordStart > start && isAsciiWordRune(runes[wordStart - 1])) {
        wordStart -= 1
    }
    if (wordStart > start && measure(runeSlice(runes, wordStart, asciiWordEnd(runes, wordStart))) <= maxWidth) {
        wordStart - start
    } else {
        fit
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
private func flowIconSpan(flow: RichFlow, run: SpanRun, icon: IconSource): Unit {
    flow.pendingCr = false
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

internal func layoutRichSpans(spans: Array<RichSpan>, spanSizes: Array<Float32>, maxWidth: Float32, iconSize: Float32,
    spanGap: Float32, metrics: RichTextMeasurements): RichLayout {
    let widthOf = metrics.widthOf
    let heightOf = metrics.heightOf
    let flow = RichFlow(maxWidth: maxWidth, iconSize: iconSize, spanGap: spanGap)
    var si: Int64 = 0
    while (si < spans.size) {
        let run = SpanRun(spans[si], si, spanSizes[si])
        let span = run.span
        match (span.kind) {
            case RichSpanKind.SpanText(text) =>
                let (joined, next, sourceEnds) = coalesceRichText(spans, spanSizes, si, text)
                let textRun = SpanRun(span, si, run.size, sourceEnds: sourceEnds)
                si = next - 1
                // Bind this run's size, style, and font so widths reflect the actual metrics (a bigger
                // or bolder run is wider) and wrapping breaks where the run really overflows.
                flowTextSpan(flow, textRun, joined, fragHeight: heightOf(run.size, span.style, span.fontFace),
                    spanMeasure: {s: String => widthOf(s, run.size, span.style, span.fontFace)})
            case RichSpanKind.SpanIcon(icon) => flowIconSpan(flow, run, icon)
        }
        si += 1
    }
    placeRichLines(flow, metrics)
}

private func placeRichLines(flow: RichFlow, metrics: RichTextMeasurements): RichLayout {
    if (flow.frags.isEmpty() && flow.lineHeights[0] <= 0.0) {
        return RichLayout(Array<PlacedItem>(), 0.0, 0.0, 0)
    }
    let ascents = Array<Float32>(flow.frags.size, repeat: 0.0)
    let lineAscents = Array<Float32>(flow.lineHeights.size, repeat: 0.0)
    let lineDescents = Array<Float32>(flow.lineHeights.size, repeat: 0.0)
    if (let Some(ascentOf) <- metrics.ascentOf) {
        for (i in 0..flow.frags.size) {
            let frag = flow.frags[i]
            let ascent = match (frag.kind) {
                case PlacedKind.PlacedText(_) => max(0.0, min(frag.height, ascentOf(frag.size, frag.style, frag.font)))
                case _ => frag.height * 0.8
            }
            ascents[i] = ascent
            lineAscents[frag.line] = max(lineAscents[frag.line], ascent)
            lineDescents[frag.line] = max(lineDescents[frag.line], frag.height - ascent)
        }
        for (i in 0..flow.lineHeights.size) {
            flow.lineHeights[i] = max(flow.lineHeights[i], lineAscents[i] + lineDescents[i])
        }
    }
    // Stack lines after their common baseline and below-baseline extents are known.
    let lineTops = ArrayList<Float32>()
    var acc: Float32 = 0.0
    for (h in flow.lineHeights) {
        lineTops.add(acc)
        acc += h
    }
    let placed = ArrayList<PlacedItem>()
    for (i in 0..flow.frags.size) {
        let frag = flow.frags[i]
        let offset = if (metrics.ascentOf.isSome()) {
            lineAscents[frag.line] - ascents[i]
        } else {
            (flow.lineHeights[frag.line] - frag.height) / 2.0
        }
        placed.add(frag.placed(lineTops[frag.line] + offset))
    }
    RichLayout(placed.toArray(), acc, flow.widest, flow.lineHeights.size)
}
