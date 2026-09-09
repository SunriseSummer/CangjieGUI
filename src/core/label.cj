package cui.core

import sdl.{Color, FontStyle, FontWeight, FontVariations, Rect, Size, UiEvent}

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
    private let semanticId: String
    private var isMuted: Bool
    private var alignment: TextAlign
    private var textColor: ?Color
    private var pointSize: ?Length
    private var localStyleMask: Int32 = 0
    private var localFontStyle: ?FontStyle = None
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
    private var cachedMeasurementEnvironment: ?UiEnvironmentKey = None

    public init(
        text: String,
        muted!: Bool = false,
        align!: TextAlign = TextAlign.Leading,
        color!: ?Color = None,
        fontSize!: ?Length = None
    ) {
        this.text = text
        this.semanticId = controlIdentity("Label:${text}")
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
        pointSize = Some(value)
        this
    }

    /** Sets the font size in font pixels. */
    public func fontSize(value: Float32): Label {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Replaces the whole text style (weight, slant, and decorations) at once. */
    public func fontStyle(value: FontStyle): Label {
        localStyleMask = 31
        localFontStyle = Some(value)
        dropMetricsCaches()
        this
    }

    /** Draws the text bold (or sets bold to `value`). */
    public func bold(value!: Bool = true): Label {
        localStyleMask |= 1
        localFontStyle = Some(baseFontStyle().withBold(value: value))
        dropMetricsCaches()
        this
    }

    /** Draws the text italic (or sets italic to `value`). */
    public func italic(value!: Bool = true): Label {
        localStyleMask |= 2
        localFontStyle = Some(baseFontStyle().withItalic(value: value))
        dropMetricsCaches()
        this
    }

    /** Underlines the text (or sets the underline to `value`). */
    public func underline(value!: Bool = true): Label {
        localStyleMask |= 4
        localFontStyle = Some(baseFontStyle().withUnderline(value: value))
        dropMetricsCaches()
        this
    }

    /** Strikes through the text (or sets the strikethrough to `value`). */
    public func strikethrough(value!: Bool = true): Label {
        localStyleMask |= 8
        localFontStyle = Some(baseFontStyle().withStrikethrough(value: value))
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
        cachedMeasurementEnvironment = None
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
        let lineHeight = ctx.textHeight(pointSize: ps, style: resolvedFontStyle(ctx), font: fontFace)
        if (lineLimit == 1) {
            return Size(min(available.w, singleLineWidth(ctx, ps)), max(CUI_SMALL_H, lineHeight + 6.0))
        }
        let lines = linesFor(ctx, available.w, ps)
        let count = max(1, lines.size)
        let textBlock = Float32(count) * lineHeight + Float32(count - 1) * LABEL_LINE_GAP
        // widest was measured when the lines were wrapped and cached; a warm pass reuses it.
        Size(min(available.w, cachedLinesWidest), max(CUI_SMALL_H, textBlock + 6.0))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        ctx.registerSemantics(SemanticsNode(semanticId, Semantics(label: text, role: SemanticsRole.Text), rect))
    }

    public func draw(ctx: UiContext): Unit {
        let ps = resolvedPointSize(ctx)
        let color = drawColor(ctx)
        let lineHeight = ctx.textHeight(pointSize: ps, style: resolvedFontStyle(ctx), font: fontFace)
        if (lineLimit == 1) {
            // Reuse the cached full-text width for the fit test: ellipsize (a binary search) runs
            // only when the text overflows, so a fitting single-line label re-measures nothing.
            let fitted = if (singleLineWidth(ctx, ps) <= frame.w) {
                text
            } else {
                ellipsize(ctx, text, frame.w, ps, style: resolvedFontStyle(ctx), font: fontFace)
            }
            ctx.text(
                fitted,
                lineX(ctx, fitted, ps),
                frame.centerY() - lineHeight / 2.0,
                color,
                pointSize: ps,
                style: resolvedFontStyle(ctx),
                font: fontFace
            )
            return
        }
        let lines = linesFor(ctx, frame.w, ps)
        let textBlock = Float32(lines.size) * lineHeight + Float32(max(0, lines.size - 1)) * LABEL_LINE_GAP
        var y = frame.centerY() - textBlock / 2.0
        for (line in lines) {
            ctx.text(line, lineX(ctx, line, ps), y, color, pointSize: ps, style: resolvedFontStyle(ctx), font: fontFace)
            y += lineHeight + LABEL_LINE_GAP
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
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

    /** Selects a numeric weight while inheriting other style fields. */
    public func fontWeight(value: FontWeight): Label {
        localStyleMask |= 1
        localFontStyle = Some(baseFontStyle().withWeight(value))
        dropMetricsCaches()
        this
    }

    /** Overrides variable design coordinates while inheriting other text style fields. */
    public func fontVariations(value: FontVariations): Label {
        localStyleMask |= 16
        localFontStyle = Some(baseFontStyle().withVariations(value))
        dropMetricsCaches()
        this
    }

    private func resolvedFontStyle(ctx: UiContext): FontStyle {
        mergeFontStyle(ctx.effectiveFontStyle(), baseFontStyle(), localStyleMask)
    }

    private func baseFontStyle(): FontStyle {
        match (localFontStyle) {
            case Some(value) => value
            case None => FontStyle.regular
        }
    }

    private func resolvedPointSize(ctx: UiContext): Float32 {
        ctx.textSize(override: pointSize)
    }

    // Exact float comparison is deliberate in both caches: the keys are reused values,
    // not computed approximations, so equality means "same inputs as last time".
    private func singleLineWidth(ctx: UiContext, ps: Float32): Float32 {
        prepareMeasurementEnvironment(ctx)
        if (cachedTextWidthPointSize != ps) { // cjcheck-ignore: float-equal # cache-key identity; miss only costs a re-measure
            cachedTextWidth = ctx.textWidth(text, pointSize: ps, style: resolvedFontStyle(ctx), font: fontFace)
            cachedTextWidthPointSize = ps
        }
        cachedTextWidth
    }

    private func linesFor(ctx: UiContext, width: Float32, ps: Float32): Array<String> {
        prepareMeasurementEnvironment(ctx)
        match (cachedLines) {
            case Some(lines) where cachedLinesWidth == width && cachedLinesPointSize == ps => lines // cjcheck-ignore: float-equal # cache-key identity; miss only costs a re-wrap
            case _ =>
                let layout = layoutParagraph(ctx, text, width, ps, lineLimit, style: resolvedFontStyle(ctx),
                    font: fontFace)
                cachedLines = Some(layout.lines)
                cachedLinesWidth = width
                cachedLinesPointSize = ps
                cachedLinesWidest = layout.widest
                layout.lines
        }
    }

    private func prepareMeasurementEnvironment(ctx: UiContext): Unit {
        let environment = ctx.uiEnvironmentKey()
        match (cachedMeasurementEnvironment) {
            case Some(value) where sameUiEnvironment(value, environment) => return
            case _ =>
                dropMetricsCaches()
                cachedMeasurementEnvironment = Some(environment)
        }
    }

    private func lineX(ctx: UiContext, line: String, ps: Float32): Float32 {
        // Leading (the default) does not need the line width, so the common case skips the measure.
        match (alignment) {
            case TextAlign.Leading => frame.x
            case TextAlign.Center =>
                let lineW = ctx.textWidth(line, pointSize: ps, style: resolvedFontStyle(ctx), font: fontFace)
                frame.x + max(0.0, frame.w - lineW) / 2.0
            case TextAlign.Trailing =>
                let lineW = ctx.textWidth(line, pointSize: ps, style: resolvedFontStyle(ctx), font: fontFace)
                frame.right() - lineW
        }
    }
}
