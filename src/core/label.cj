package cui.core

import sdl.{Color, FontSizes, FontStyle, Rect, Size, UiEvent}

private let LABEL_LINE_GAP: Float32 = 2.0

/*
 * Single- or multi-line text. Defaults to one line with overflow ellipsized; `maxLines(n)` allows
 * wrapping onto up to `n` lines (the last is ellipsized when text remains) and `wrap()` removes the
 * cap. The builders (`bold`, `fontSize`, `fontFamily`, ...) mutate and return `this` for chaining.
 * Width and wrap results are cached and shared between measure and draw for the same width and point
 * size; builders that change measurement inputs (style, face, line limit) drop those caches.
 */
public class Label <: Widget {
    private let text: String
    private var isMuted: Bool
    private var alignment: TextAlign
    private var textColor: ?Color
    private var pointSize: Length
    private var textStyle: FontStyle = FontStyle.regular
    private var fontFace: ?String = None
    private var lineLimit: Int64 = 1
    private var frame = Rect.zero()
    // Wrapping runs several renderer measurements; measure and draw reuse the result
    // for the same width and point size instead of re-breaking the text each pass.
    private var cachedLines: ?Array<String> = None
    private var cachedLinesWidth: Float32 = -1.0
    private var cachedLinesPointSize: Float32 = -1.0
    // The widest wrapped line, cached with the lines it derives from so a warm multi-line measure
    // re-measures nothing instead of re-scanning every line each measure pass.
    private var cachedLinesWidest: Float32 = 0.0
    private var cachedTextWidth: Float32 = -1.0
    private var cachedTextWidthPointSize: Float32 = -1.0

    public init(
        text: String,
        muted!: Bool = false,
        align!: TextAlign = TextAlign.Leading,
        color!: ?Color = None,
        fontSize!: Length = Length(FontSizes.BODY, LengthUnit.Fp)
    ) {
        this.text = text
        this.isMuted = muted
        this.alignment = align
        this.textColor = color
        this.pointSize = fontSize
        emit(this)
    }

    /** Uses the theme's secondary text color. */
    public func muted(): Label {
        isMuted = true
        this
    }

    /** Controls whether the theme's secondary text color is used. */
    public func muted(value: Bool): Label {
        isMuted = value
        this
    }

    /** Sets horizontal text alignment inside the assigned frame. */
    public func textAlign(value: TextAlign): Label {
        alignment = value
        this
    }

    /** Overrides the theme-derived text color. */
    public func foregroundColor(value: Color): Label {
        textColor = Some(value)
        this
    }

    /** Sets the font size, e.g. `.fontSize(15.fp)`. */
    public func fontSize(value: Length): Label {
        pointSize = value
        this
    }

    /** Sets the font size in font pixels. */
    public func fontSize(value: Float32): Label {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Replaces the whole text style (weight, slant, and decorations) at once. */
    public func fontStyle(value: FontStyle): Label {
        textStyle = value
        dropMetricsCaches()
        this
    }

    /** Draws the text bold (or sets bold to `value`). */
    public func bold(value!: Bool = true): Label {
        textStyle = textStyle.withBold(value: value)
        dropMetricsCaches()
        this
    }

    /** Draws the text italic (or sets italic to `value`). */
    public func italic(value!: Bool = true): Label {
        textStyle = textStyle.withItalic(value: value)
        dropMetricsCaches()
        this
    }

    /** Underlines the text (or sets the underline to `value`). */
    public func underline(value!: Bool = true): Label {
        textStyle = textStyle.withUnderline(value: value)
        dropMetricsCaches()
        this
    }

    /** Strikes through the text (or sets the strikethrough to `value`). */
    public func strikethrough(value!: Bool = true): Label {
        textStyle = textStyle.withStrikethrough(value: value)
        dropMetricsCaches()
        this
    }

    /**
     * Draws the text in a registered application font (see `Fonts.register`). An unknown name, or a
     * font file that fails to load, falls back to the platform UI font.
     */
    public func fontFamily(name: String): Label {
        fontFace = Some(name)
        dropMetricsCaches()
        this
    }

    // Style and font are measurement inputs (bold is wider, a face has its own metrics) that the
    // width/wrap caches do not key on, so a builder that changes them must drop what was measured
    // under the old ones — otherwise a widget measured before restyling keeps stale fit decisions.
    private func dropMetricsCaches(): Unit {
        cachedTextWidthPointSize = -1.0
        cachedLines = None
        cachedLinesWidth = -1.0
        cachedLinesPointSize = -1.0
    }

    /**
     * Allows the text to wrap onto up to `value` lines. The final line is ellipsized
     * when text remains. Throws `IllegalArgumentException` when `value` is not positive.
     */
    public func maxLines(value: Int64): Label {
        if (value <= 0) {
            throw IllegalArgumentException("Label maxLines must be greater than zero")
        }
        lineLimit = value
        // The line limit is a wrap input the lines cache does not key on (same rule as the
        // style builders): a stored, re-emitted Label changing its limit must re-wrap.
        dropMetricsCaches()
        this
    }

    /** Lets the text wrap onto as many lines as it needs. */
    public func wrap(): Label {
        lineLimit = Int64.Max
        dropMetricsCaches()
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps, style: textStyle, font: fontFace)
        if (lineLimit == 1) {
            return Size(min(available.w, singleLineWidth(ctx, ps)), max(CUI_SMALL_H, lineHeight + 6.0))
        }
        let lines = linesFor(ctx, available.w, ps)
        let count = max(1, lines.size)
        let textBlock = Float32(count) * lineHeight + Float32(count - 1) * LABEL_LINE_GAP
        // widest was measured when the lines were wrapped and cached; a warm pass reuses it.
        Size(min(available.w, cachedLinesWidest), max(CUI_SMALL_H, textBlock + 6.0))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let ps = resolvedPointSize(ctx)
        let color = drawColor(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps, style: textStyle, font: fontFace)
        if (lineLimit == 1) {
            // Reuse the cached full-text width for the fit test: ellipsize (a binary search) runs
            // only when the text overflows, so a fitting single-line label re-measures nothing.
            let fitted = if (singleLineWidth(ctx, ps) <= frame.w) {
                text
            } else {
                ellipsize(ctx, text, frame.w, ps, style: textStyle, font: fontFace)
            }
            ctx.renderer.text(
                fitted,
                lineX(ctx, fitted, ps),
                frame.centerY() - lineHeight / 2.0,
                color,
                pointSize: ps,
                style: textStyle,
                font: fontFace
            )
            return
        }
        let lines = linesFor(ctx, frame.w, ps)
        let textBlock = Float32(lines.size) * lineHeight + Float32(max(0, lines.size - 1)) * LABEL_LINE_GAP
        var y = frame.centerY() - textBlock / 2.0
        for (line in lines) {
            ctx.renderer.text(line, lineX(ctx, line, ps), y, color, pointSize: ps, style: textStyle, font: fontFace)
            y += lineHeight + LABEL_LINE_GAP
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func drawColor(ctx: UiContext): Color {
        match (textColor) {
            case Some(value) => value
            case None =>
                if (isMuted) {
                    ctx.theme.mutedText
                } else {
                    ctx.theme.text
                }
        }
    }

    private func resolvedPointSize(ctx: UiContext): Float32 {
        max(1.0, ctx.resolve(pointSize))
    }

    // Exact float comparison is deliberate in both caches: the keys are reused values,
    // not computed approximations, so equality means "same inputs as last time".
    private func singleLineWidth(ctx: UiContext, ps: Float32): Float32 {
        if (cachedTextWidthPointSize != ps) { // cjcheck-ignore: float-equal # cache-key identity; miss only costs a re-measure
            cachedTextWidth = ctx.renderer.textWidth(text, pointSize: ps, style: textStyle, font: fontFace)
            cachedTextWidthPointSize = ps
        }
        cachedTextWidth
    }

    private func linesFor(ctx: UiContext, width: Float32, ps: Float32): Array<String> {
        match (cachedLines) {
            case Some(lines) where cachedLinesWidth == width && cachedLinesPointSize == ps => lines // cjcheck-ignore: float-equal # cache-key identity; miss only costs a re-wrap
            case _ =>
                let lines = wrapText(ctx, text, width, ps, lineLimit, style: textStyle, font: fontFace)
                var widest: Float32 = 0.0
                for (line in lines) {
                    widest = max(widest, ctx.renderer.textWidth(line, pointSize: ps, style: textStyle, font: fontFace))
                }
                cachedLines = Some(lines)
                cachedLinesWidth = width
                cachedLinesPointSize = ps
                cachedLinesWidest = widest
                lines
        }
    }

    private func lineX(ctx: UiContext, line: String, ps: Float32): Float32 {
        // Leading (the default) does not need the line width, so the common case skips the measure.
        match (alignment) {
            case TextAlign.Leading => frame.x
            case TextAlign.Center =>
                let lineW = ctx.renderer.textWidth(line, pointSize: ps, style: textStyle, font: fontFace)
                frame.x + max(0.0, frame.w - lineW) / 2.0
            case TextAlign.Trailing =>
                let lineW = ctx.renderer.textWidth(line, pointSize: ps, style: textStyle, font: fontFace)
                frame.right() - lineW
        }
    }
}
