package cui.core

import std.collection.ArrayList
import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, SurfaceStyle, UiEvent}

private let LABEL_LINE_GAP: Float32 = 2.0
private let LABEL_ELLIPSIS = "…"

public class Label <: Widget {
    private let text: String
    private var isMuted: Bool
    private var alignment: TextAlign
    private var textColor: ?Color
    private var pointSize: Length
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

    /**
     * Allows the text to wrap onto up to `value` lines. The final line is ellipsized
     * when text remains. Throws `IllegalArgumentException` when `value` is not positive.
     */
    public func maxLines(value: Int64): Label {
        if (value <= 0) {
            throw IllegalArgumentException("Label maxLines must be greater than zero")
        }
        lineLimit = value
        this
    }

    /** Lets the text wrap onto as many lines as it needs. */
    public func wrap(): Label {
        lineLimit = Int64.Max
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
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
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
        if (lineLimit == 1) {
            // Reuse the cached full-text width for the fit test: ellipsize (a binary search) runs
            // only when the text overflows, so a fitting single-line label re-measures nothing.
            let fitted = if (singleLineWidth(ctx, ps) <= frame.w) {
                text
            } else {
                ellipsize(ctx, text, frame.w, ps)
            }
            ctx.renderer.text(fitted, lineX(ctx, fitted, ps), frame.centerY() - lineHeight / 2.0, color, pointSize: ps)
            return
        }
        let lines = linesFor(ctx, frame.w, ps)
        let textBlock = Float32(lines.size) * lineHeight + Float32(max(0, lines.size - 1)) * LABEL_LINE_GAP
        var y = frame.centerY() - textBlock / 2.0
        for (line in lines) {
            ctx.renderer.text(line, lineX(ctx, line, ps), y, color, pointSize: ps)
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
        if (cachedTextWidthPointSize != ps) {
            cachedTextWidth = ctx.renderer.textWidth(text, pointSize: ps)
            cachedTextWidthPointSize = ps
        }
        cachedTextWidth
    }

    private func linesFor(ctx: UiContext, width: Float32, ps: Float32): Array<String> {
        match (cachedLines) {
            case Some(lines) where cachedLinesWidth == width && cachedLinesPointSize == ps => lines
            case _ =>
                let lines = wrapText(ctx, text, width, ps, lineLimit)
                var widest: Float32 = 0.0
                for (line in lines) {
                    widest = max(widest, ctx.renderer.textWidth(line, pointSize: ps))
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
                let lineW = ctx.renderer.textWidth(line, pointSize: ps)
                frame.x + max(0.0, frame.w - lineW) / 2.0
            case TextAlign.Trailing =>
                let lineW = ctx.renderer.textWidth(line, pointSize: ps)
                frame.right() - lineW
        }
    }
}

/*
 * Text fitting shared by single-line ellipsis and multi-line wrapping. Prefix widths are
 * found with binary search over the rune array, so the cost per line is O(log n) renderer
 * measurements instead of one per character.
 */

/** Returns `text` unchanged when it fits, otherwise the widest `prefix + …` that fits. */
protected func ellipsize(ctx: UiContext, text: String, maxWidth: Float32, ps: Float32): String {
    if (ctx.renderer.textWidth(text, pointSize: ps) <= maxWidth) {
        return text
    }
    if (ctx.renderer.textWidth(LABEL_ELLIPSIS, pointSize: ps) > maxWidth) {
        return ""
    }
    let runes = text.toRuneArray()
    var low: Int64 = 0
    var high = runes.size - 1
    while (low < high) {
        let mid = (low + high + 1) / 2
        let candidate = runeSlice(runes, 0, mid) + LABEL_ELLIPSIS
        if (ctx.renderer.textWidth(candidate, pointSize: ps) <= maxWidth) {
            low = mid
        } else {
            high = mid - 1
        }
    }
    runeSlice(runes, 0, low) + LABEL_ELLIPSIS
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
    maxLines: Int64
): Array<String> {
    let runes = text.toRuneArray()
    let lines = ArrayList<String>()
    var start: Int64 = 0
    while (start < runes.size && lines.size < maxLines) {
        if (lines.size == maxLines - 1) {
            lines.add(ellipsize(ctx, runeSlice(runes, start, runes.size), maxWidth, ps))
            return lines.toArray()
        }
        var take = maxFittingRunes(ctx, runes, start, maxWidth, ps)
        // Prefer breaking after the last space inside the fitted range.
        if (start + take < runes.size && runes[start + take] != r' ') {
            var back = take - 1
            while (back > 0) {
                if (runes[start + back] == r' ') {
                    take = back + 1
                    break
                }
                back -= 1
            }
        }
        var lineEnd = start + take
        while (lineEnd > start && runes[lineEnd - 1] == r' ') {
            lineEnd -= 1
        }
        lines.add(runeSlice(runes, start, lineEnd))
        start += take
        // Consume the space the break landed on so lines never start blank.
        while (start < runes.size && runes[start] == r' ') {
            start += 1
        }
    }
    if (lines.isEmpty()) {
        lines.add("")
    }
    lines.toArray()
}

/** The largest rune count from `start` whose text fits `maxWidth`; at least one. */
private func maxFittingRunes(
    ctx: UiContext,
    runes: Array<Rune>,
    start: Int64,
    maxWidth: Float32,
    ps: Float32
): Int64 {
    let remaining = runes.size - start
    if (ctx.renderer.textWidth(runeSlice(runes, start, runes.size), pointSize: ps) <= maxWidth) {
        return remaining
    }
    var low: Int64 = 1
    var high = remaining - 1
    while (low < high) {
        let mid = (low + high + 1) / 2
        if (ctx.renderer.textWidth(runeSlice(runes, start, start + mid), pointSize: ps) <= maxWidth) {
            low = mid
        } else {
            high = mid - 1
        }
    }
    max(1, low)
}

private func runeSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var i = start
    while (i < end) {
        builder.append(runes[i])
        i += 1
    }
    builder.toString()
}

public class Spacer <: Widget {
    public init() {
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        true
    }
}

public class Button <: Widget {
    private let title: String
    private let onClick: () -> Unit
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private var pointSize: Length
    private var controlId: String
    private var frame = Rect.zero()

    public init(
        title: String,
        onClick: () -> Unit,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        fontSize!: Length = Length(FontSizes.CONTROL, LengthUnit.Fp)
    ) {
        this.title = title
        this.onClick = onClick
        this.buttonRole = role
        this.customStyle = style
        this.pointSize = fontSize
        this.controlId = focusableControlIdentity("Button:${title}")
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity. Defaults are already unique per build;
     * set one when identity must survive tree reshapes (for example a button that moves
     * between containers). Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): Button {
        requireControlId(value, "Button")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Applies semantic button coloring. */
    public func role(value: ButtonRole): Button {
        buttonRole = value
        this
    }

    /** Overrides the theme-derived button surface. */
    public func style(value: SurfaceStyle): Button {
        customStyle = Some(value)
        this
    }

    /** Sets the label font size, e.g. `.fontSize(15.fp)`. */
    public func fontSize(value: Length): Button {
        pointSize = value
        this
    }

    /** Sets the label font size in font pixels. */
    public func fontSize(value: Float32): Button {
        fontSize(Length(value, LengthUnit.Fp))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = max(1.0, ctx.resolve(pointSize))
        Size(min(available.w, max(72.0, ctx.renderer.textWidth(title, pointSize: ps) + 24.0)), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, buttonStyle(ctx))
        let textColor = match (buttonRole) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
        ctx.renderer.textCenter(title, frame, textColor, pointSize: max(1.0, ctx.resolve(pointSize)))
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, frame, ctx.theme.controlRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    ctx.press(controlId)
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (ctx.isPressed(controlId)) {
                    if (frame.contains(x, y)) {
                        onClick()
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    onClick()
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    onClick()
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func buttonStyle(ctx: UiContext): SurfaceStyle {
        match (customStyle) {
            case Some(value) => value
            case None =>
                let base = ctx.theme.buttonSurface(buttonRole)
                match (buttonRole) {
                    case ButtonRole.Normal =>
                        var style = base
                        if (ctx.isPressed(controlId)) {
                            style = style.withFill(ctx.theme.accentSoft)
                        } else if (ctx.isHovered(controlId)) {
                            // Single-winner hover: in overlapping layouts only the visually
                            // top-most claimant highlights (same protocol as the cursor shape).
                            style = style.withFill(ctx.theme.fieldActive)
                        }
                        // The focus ring (drawn in draw() on keyboard focus) shows where
                        // Enter/Space will land — no need to also recolour the border.
                        style
                    case _ => base
                }
        }
    }
}
