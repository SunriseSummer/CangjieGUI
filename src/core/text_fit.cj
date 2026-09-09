package cui.core

import std.collection.ArrayList
import sdl.{FontStyle, TextMeasureSession}

private let TEXT_ELLIPSIS = "…"
private let HAN_BMP_START: UInt32 = UInt32(0x3400)
private let HAN_BMP_END: UInt32 = UInt32(0x9FFF)
private let HAN_SUPPLEMENTARY_START: UInt32 = UInt32(0x20000)
private let HAN_SUPPLEMENTARY_END: UInt32 = UInt32(0x323AF)
private let UTF8_ASCII_LIMIT: UInt8 = UInt8(0x80)
private let UTF8_TWO_BYTE_LIMIT: UInt8 = UInt8(0xE0)
private let UTF8_THREE_BYTE_LIMIT: UInt8 = UInt8(0xF0)
private let UTF8_TWO_BYTE_MASK: UInt8 = UInt8(0x1F)
private let UTF8_THREE_BYTE_MASK: UInt8 = UInt8(0x0F)
private let UTF8_FOUR_BYTE_MASK: UInt8 = UInt8(0x07)
private let UTF8_CONTINUATION_MASK: UInt8 = UInt8(0x3F)
private let UTF8_CONTINUATION_SHIFT: UInt32 = UInt32(6)
private let UTF8_THREE_BYTE_SHIFT: UInt32 = UInt32(12)
private let UTF8_FOUR_BYTE_SHIFT: UInt32 = UInt32(18)
private let UTF8_ONE_BYTE_LENGTH: Int64 = 1
private let UTF8_TWO_BYTE_LENGTH: Int64 = 2
private let UTF8_THREE_BYTE_LENGTH: Int64 = 3
private let UTF8_FOUR_BYTE_LENGTH: Int64 = 4

protected struct ParagraphLayout {
    let lines: Array<String>
    let widest: Float32

    init(lines: Array<String>, widest: Float32) {
        this.lines = lines
        this.widest = widest
    }
}

private enum EllipsisPolicy {
    | WhenNeeded
    | Required
}

private struct ParagraphFormat {
    let maxWidth: Float32
    let pointSize: Float32
    let maxLines: Int64
    let style: FontStyle
    let font: ?String

    init(maxWidth: Float32, pointSize: Float32, maxLines: Int64, style: FontStyle, font: ?String) {
        this.maxWidth = maxWidth
        this.pointSize = pointSize
        this.maxLines = maxLines
        this.style = style
        this.font = font
    }
}

private struct ParagraphMeasureInput {
    let ctx: UiContext
    let text: String
    let clusters: Array<GraphemeCluster>
    let session: TextMeasureSession
    let format: ParagraphFormat

    init(
        ctx: UiContext,
        text: String,
        clusters: Array<GraphemeCluster>,
        session: TextMeasureSession,
        format: ParagraphFormat
    ) {
        this.ctx = ctx
        this.text = text
        this.clusters = clusters
        this.session = session
        this.format = format
    }
}

private class GenericParagraphBuilder {
    private let input: ParagraphMeasureInput
    private let lines = ArrayList<String>()
    private var widest: Float32 = 0.0
    private var start: Int64 = 0
    private var hardEnd: Int64

    init(input: ParagraphMeasureInput) {
        this.input = input
        this.hardEnd = nextMandatoryBreak(input.clusters, 0)
    }

    func build(): ParagraphLayout {
        while (start < input.clusters.size && lines.size < input.format.maxLines) {
            if (isMandatoryBreak(input.clusters[start])) {
                appendMandatoryBreak()
                continue
            }
            if (lines.size == input.format.maxLines - 1) {
                return appendLastLine()
            }
            appendFittedLine()
        }
        if (isMandatoryBreak(input.clusters[input.clusters.size - 1]) && lines.size < input.format.maxLines) {
            lines.add("")
        }
        finish()
    }

    private func appendMandatoryBreak(): Unit {
        lines.add("")
        start += 1
        hardEnd = nextMandatoryBreak(input.clusters, start)
    }

    private func appendLastLine(): ParagraphLayout {
        let policy = if (hardEnd < input.clusters.size) {
            EllipsisPolicy.Required
        } else {
            EllipsisPolicy.WhenNeeded
        }
        let line = ellipsizeRange(input, start, hardEnd, policy)
        lines.add(line)
        widest = max(widest,
            input
                .ctx
                .textWidth(line, pointSize: input.format.pointSize, style: input.format.style, font: input.format.font))
        ParagraphLayout(lines.toArray(), widest)
    }

    private func appendFittedLine(): Unit {
        let fit = input.session.fit(input.clusters[start].start, input.format.maxWidth)
        let measuredEnd = input.clusters[start].start + fit.byteLength
        var fitExclusive = start
        while (fitExclusive < hardEnd && input.clusters[fitExclusive].end <= measuredEnd) {
            fitExclusive += 1
        }
        // A grapheme wider than the line deliberately overflows intact: splitting a user-perceived
        // glyph or emitting invalid UTF-8 would be a correctness regression.
        if (fitExclusive == start) {
            fitExclusive = start + 1
        }
        let takeExclusive = if (fitExclusive >= hardEnd) {
            hardEnd
        } else {
            preferredBreak(input.clusters, start, fitExclusive)
        }
        appendVisibleRange(takeExclusive)
        advance(takeExclusive)
    }

    private func appendVisibleRange(takeExclusive: Int64): Unit {
        var visibleEnd = takeExclusive
        while (visibleEnd > start && isBreakSpace(input.clusters[visibleEnd - 1].first)) {
            visibleEnd -= 1
        }
        let lineStart = input.clusters[start].start
        let lineEnd = if (visibleEnd > start) {
            input.clusters[visibleEnd - 1].end
        } else {
            lineStart
        }
        lines.add(input.text[lineStart..lineEnd])
        widest = max(widest, input.session.measure(lineStart, lineEnd - lineStart))
    }

    private func advance(takeExclusive: Int64): Unit {
        let hasFollowingParagraph = hardEnd < input.clusters.size
        start = takeExclusive
        while (start < hardEnd && isBreakSpace(input.clusters[start].first)) {
            start += 1
        }
        if (start == hardEnd && hasFollowingParagraph) {
            start += 1
            hardEnd = nextMandatoryBreak(input.clusters, start)
        }
    }

    private func finish(): ParagraphLayout {
        if (lines.isEmpty()) {
            lines.add("")
        }
        ParagraphLayout(lines.toArray(), widest)
    }
}

/*
 * Text fitting shared by single-line ellipsis and multi-line wrapping. SDL_ttf finds a measured
 * UTF-8 prefix in one native call; the framework then snaps that prefix to an extended grapheme
 * boundary and selects a legal line-break opportunity. Width fitting, grapheme segmentation and
 * line breaking are deliberately separate concerns.
 */

/** Returns `text` unchanged when it fits, otherwise the widest `prefix + …` that fits. */
protected func ellipsize(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    style!: ?FontStyle = None,
    font!: ?String = None
): String {
    let clusters = segmentGraphemes(text)
    let session = ctx.textMeasureSession(text, pointSize: ps, style: style, font: font)
    let format = ParagraphFormat(maxWidth, ps, 1, ctx.effectiveFontStyle(style: style), font)
    var result = ""
    try (resource = session) {
        let input = ParagraphMeasureInput(ctx, text, clusters, resource, format)
        result = ellipsizeRange(input, 0, clusters.size, EllipsisPolicy.WhenNeeded)
    }
    result
}

/**
 * Breaks `text` into at most `maxLines` display lines that fit `maxWidth`, preferring
 * space boundaries and falling back to per-rune breaks (which suits CJK text). The last
 * line is ellipsized when text remains.
 */
protected func wrapText(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    maxLines: Int64,
    style!: ?FontStyle = None,
    font!: ?String = None
): Array<String> {
    layoutParagraph(ctx, text, maxWidth, ps, maxLines, style: style, font: font).lines
}

protected func layoutParagraph(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    maxLines: Int64,
    style!: ?FontStyle = None,
    font!: ?String = None
): ParagraphLayout {
    let effectiveStyle = ctx.effectiveFontStyle(style: style)
    let format = ParagraphFormat(maxWidth, ps, maxLines, effectiveStyle, font)
    ctx.cachedParagraphLayout(text, maxWidth, ps, maxLines, effectiveStyle, font,
        {=> buildParagraphLayout(ctx, text, format)})
}

private func buildParagraphLayout(ctx: UiContext, text: String, format: ParagraphFormat): ParagraphLayout {
    if (isSimpleHanParagraph(text)) {
        return buildSimpleHanParagraph(ctx, text, format)
    }
    let clusters = segmentGraphemes(text)
    if (clusters.isEmpty()) {
        return ParagraphLayout([""], 0.0)
    }
    let session = ctx.textMeasureSession(text, pointSize: format.pointSize, style: format.style, font: format.font)
    var result = ParagraphLayout([""], 0.0)
    try (resource = session) {
        let input = ParagraphMeasureInput(ctx, text, clusters, resource, format)
        result = GenericParagraphBuilder(input).build()
    }
    result
}

/*
 * Unified Han text is the dominant long-document path in CJK applications. Every scalar is one
 * grapheme and UAX #14 permits a break between adjacent ideographs, so building a 20k-entry cluster
 * array only to read it sequentially is pure allocation. This streaming path preserves the exact
 * same fit/ellipsis contract while keeping memory O(lines) rather than O(code points).
 */
private func buildSimpleHanParagraph(
    ctx: UiContext,
    text: String,
    format: ParagraphFormat
): ParagraphLayout {
    if (text.isEmpty()) {
        return ParagraphLayout([""], 0.0)
    }
    let lines = ArrayList<String>()
    let session = ctx.textMeasureSession(text, pointSize: format.pointSize, style: format.style, font: format.font)
    var widest: Float32 = 0.0
    try (resource = session) {
        var start: Int64 = 0
        while (start < text.size && lines.size < format.maxLines) {
            if (lines.size == format.maxLines - 1) {
                return finishSimpleHanParagraph(ctx, text, format, resource, start, lines, widest)
            }
            let fit = resource.fit(start, format.maxWidth)
            let take = if (fit.byteLength > 0) {
                fit.byteLength
            } else {
                utf8RuneByteLengthAt(text, start)
            }
            lines.add(text[start..start + take])
            let width = if (fit.byteLength == take) {
                fit.width
            } else {
                resource.measure(start, take)
            }
            widest = max(widest, width)
            start += take
        }
    }
    ParagraphLayout(lines.toArray(), widest)
}

private func finishSimpleHanParagraph(
    ctx: UiContext,
    text: String,
    format: ParagraphFormat,
    session: TextMeasureSession,
    start: Int64,
    lines: ArrayList<String>,
    widest: Float32
): ParagraphLayout {
    let remainingFit = session.fit(start, format.maxWidth)
    if (remainingFit.byteLength == text.size - start) {
        lines.add(text[start..text.size])
        return ParagraphLayout(lines.toArray(), max(widest, remainingFit.width))
    }
    let ellipsisWidth = ctx.textWidth(TEXT_ELLIPSIS, pointSize: format.pointSize, style: format.style, font: format.font)
    if (ellipsisWidth > format.maxWidth) {
        lines.add("")
    } else {
        let fit = session.fit(start, format.maxWidth - ellipsisWidth)
        lines.add(text[start..start + fit.byteLength] + TEXT_ELLIPSIS)
    }
    let last = lines[lines.size - 1]
    let lastWidth = ctx.textWidth(last, pointSize: format.pointSize, style: format.style, font: format.font)
    ParagraphLayout(lines.toArray(), max(widest, lastWidth))
}

private func isSimpleHanParagraph(text: String): Bool {
    if (text.isEmpty()) {
        return false
    }
    var index: Int64 = 0
    while (index < text.size) {
        let codePoint = utf8CodePointAt(text, index)
        if (!((codePoint >= HAN_BMP_START && codePoint <= HAN_BMP_END) || (codePoint >= HAN_SUPPLEMENTARY_START &&
            codePoint <= HAN_SUPPLEMENTARY_END))) {
            return false
        }
        index += utf8RuneByteLengthAt(text, index)
    }
    true
}

private func utf8RuneByteLengthAt(text: String, index: Int64): Int64 {
    let lead = text[index]
    if (lead < UTF8_ASCII_LIMIT) {
        UTF8_ONE_BYTE_LENGTH
    } else if (lead < UTF8_TWO_BYTE_LIMIT) {
        UTF8_TWO_BYTE_LENGTH
    } else if (lead < UTF8_THREE_BYTE_LIMIT) {
        UTF8_THREE_BYTE_LENGTH
    } else {
        UTF8_FOUR_BYTE_LENGTH
    }
}

private func utf8CodePointAt(text: String, index: Int64): UInt32 {
    let length = utf8RuneByteLengthAt(text, index)
    if (length == UTF8_ONE_BYTE_LENGTH) {
        return UInt32(text[index])
    }
    if (length == UTF8_TWO_BYTE_LENGTH) {
        return (UInt32(text[index] & UTF8_TWO_BYTE_MASK) << UTF8_CONTINUATION_SHIFT) | UInt32(text[index + 1] &
            UTF8_CONTINUATION_MASK)
    }
    if (length == UTF8_THREE_BYTE_LENGTH) {
        return (UInt32(text[index] & UTF8_THREE_BYTE_MASK) << UTF8_THREE_BYTE_SHIFT) | (UInt32(text[index + 1] &
            UTF8_CONTINUATION_MASK) << UTF8_CONTINUATION_SHIFT) | UInt32(text[index + 2] & UTF8_CONTINUATION_MASK)
    }
    (UInt32(text[index] & UTF8_FOUR_BYTE_MASK) << UTF8_FOUR_BYTE_SHIFT) | (UInt32(text[index + 1] &
        UTF8_CONTINUATION_MASK) << UTF8_THREE_BYTE_SHIFT) | (UInt32(text[index + 2] & UTF8_CONTINUATION_MASK) <<
        UTF8_CONTINUATION_SHIFT) | UInt32(text[index + 3] & UTF8_CONTINUATION_MASK)
}

private func ellipsizeRange(
    input: ParagraphMeasureInput,
    start: Int64,
    end: Int64,
    policy: EllipsisPolicy
): String {
    let startByte = if (start < input.clusters.size) {
        input.clusters[start].start
    } else {
        input.text.size
    }
    let endByte = if (end > start) {
        input.clusters[end - 1].end
    } else {
        startByte
    }
    let measureWholeRange = match (policy) {
        case EllipsisPolicy.WhenNeeded => true
        case EllipsisPolicy.Required => false
    }
    if (measureWholeRange) {
        let fullFit = input.session.fit(startByte, input.format.maxWidth)
        if (fullFit.byteLength >= endByte - startByte) {
            return input.text[startByte..endByte]
        }
    }
    let ellipsisWidth = input
        .ctx
        .textWidth(TEXT_ELLIPSIS, pointSize: input.format.pointSize, style: input.format.style, font: input.format.font)
    if (ellipsisWidth > input.format.maxWidth) {
        return ""
    }
    let fit = input.session.fit(startByte, input.format.maxWidth - ellipsisWidth)
    let measuredEnd = startByte + fit.byteLength
    var fittedEnd = start
    while (fittedEnd < end && input.clusters[fittedEnd].end <= measuredEnd) {
        fittedEnd += 1
    }
    let prefixEnd = if (fittedEnd > start) {
        input.clusters[fittedEnd - 1].end
    } else {
        startByte
    }
    input.text[startByte..prefixEnd] + TEXT_ELLIPSIS
}
