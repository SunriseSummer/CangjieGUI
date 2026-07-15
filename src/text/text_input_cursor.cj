package cui.text

import sdl.{FontSizes, Point, Rect}
import cui.core.{CUI_SMALL_H, UiContext, scrollLineIndex, scrollLineRemainder}

private let TEXT_CURSOR_W: Float32 = 1.5
private let TEXT_FIELD_PAD_X: Float32 = 8.0
/* Half a standard blink cycle: the caret is visible for this long, then hidden as long. */
private let TEXT_CURSOR_BLINK_MS: UInt64 = 530

internal struct TextAreaContent {
    let text: String
    let cursor: Int64
    let scroll: Float32

    init(text: String, cursor: Int64, scroll: Float32) {
        this.text = text
        this.cursor = cursor
        this.scroll = scroll
    }
}

internal func textInputViewport(frame: Rect): Rect {
    frame.inset(8.0)
}

/*
 * The caret blinks on the shared frame clock. The UI redraws every frame, so phase
 * toggling is enough; no per-control timer state is needed.
 */
internal func textCursorVisible(ctx: UiContext): Bool {
    (ctx.frame.elapsedMs / TEXT_CURSOR_BLINK_MS) % UInt64(2) == UInt64(0)
}

/*
 * Byte offset for a click at `targetX` (relative to where the line's text starts).
 * Prefix widths use the same renderer measurement as drawing, so the hit position is
 * exact for proportional and CJK glyphs alike; the midpoint rule picks the nearer
 * boundary, matching how desktop editors place the caret between characters.
 */
private func textCursorForOffset(
    ctx: UiContext,
    text: String,
    lineStart: Int64,
    lineEnd: Int64,
    targetX: Float32
): Int64 {
    var current = lineStart
    var previousWidth: Float32 = 0.0
    while (current < lineEnd) {
        let next = nextTextBoundary(text, current)
        let nextWidth = ctx.renderer.textWidth(text[lineStart..next], pointSize: FontSizes.BODY)
        if (targetX < (previousWidth + nextWidth) / 2.0) {
            return current
        }
        previousWidth = nextWidth
        current = next
    }
    lineEnd
}

// `xShift` is the field's horizontal follow offset: the text window slides left by this many
// pixels when the caret runs past the inner width, so hit-testing adds it back.
internal func textFieldCursorForPoint(ctx: UiContext, frame: Rect, text: String, x: Float32,
    xShift!: Float32 = 0.0): Int64 {
    let lineEnd = lineEndAfterOrAt(text, 0)
    textCursorForOffset(ctx, text, 0, lineEnd, x - frame.x - TEXT_FIELD_PAD_X + xShift)
}

internal func textAreaCursorForPoint(
    ctx: UiContext,
    frame: Rect,
    content: TextAreaContent,
    point: Point
): Int64 {
    let viewport = textInputViewport(frame)
    let line = Int64(max(0.0, point.y - viewport.y + content.scroll) / CUI_SMALL_H)
    let lineStart = startOfTextLine(content.text, line)
    let lineEnd = lineEndAfterOrAt(content.text, lineStart)
    textCursorForOffset(ctx, content.text, lineStart, lineEnd, point.x - viewport.x)
}

/*
 * Paints the selection band behind a single-line field's text. Both edges use the same
 * prefix-width measurement as the caret, so the band lines up with the glyphs exactly; the
 * fill is translucent so the selected text stays legible on top.
 */
internal func drawTextFieldSelection(ctx: UiContext, frame: Rect, text: String, selStart: Int64, selEnd: Int64,
    xShift!: Float32 = 0.0): Unit {
    if (selStart >= selEnd) {
        return
    }
    let startW = ctx.renderer.textWidth(text[0..selStart], pointSize: FontSizes.BODY)
    let endW = ctx.renderer.textWidth(text[0..selEnd], pointSize: FontSizes.BODY)
    let xStart = frame.x + TEXT_FIELD_PAD_X - xShift + startW
    let xEnd = frame.x + TEXT_FIELD_PAD_X - xShift + endW
    let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
    // Opaque enough to read as a selection over the focused field's tinted surface, still
    // translucent so the glyphs drawn on top stay legible.
    ctx.renderer.fill(Rect(xStart, frame.centerY() - lineHeight / 2.0, xEnd - xStart, lineHeight),
        ctx.theme.accent.withAlpha(115))
}

internal func drawTextFieldCursor(ctx: UiContext, frame: Rect, id: String, text: String, cursor: Int64,
    xShift!: Float32 = 0.0): Unit {
    if (!ctx.hasFocus(id)) {
        return
    }
    // A focused field blinks its caret on the frame clock, so keep frames flowing even while the
    // screen is otherwise idle; without this the dirty-frame loop (档 0) would freeze the blink.
    ctx.requestFrame()
    let position = normalizedTextCursor(text, cursor)
    let prefixW = ctx.renderer.textWidth(text[0..position], pointSize: FontSizes.BODY)
    let x = frame.x + TEXT_FIELD_PAD_X - xShift + prefixW
    // The caret spans exactly the glyph row: same height and vertical center as the
    // text the field draws, instead of the field's padding box.
    let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
    let caret = Rect(x, frame.centerY() - lineHeight / 2.0, TEXT_CURSOR_W, lineHeight)
    // The IME anchors its candidate window at the caret whenever the field has focus;
    // the blink phase only gates painting.
    ctx.setTextInputAnchor(caret)
    if (!textCursorVisible(ctx)) {
        return
    }
    ctx.renderer.fill(caret, ctx.theme.accent)
}

/*
 * Paints the selection across the visible lines of a text area. Each line contributes the
 * band covering its selected bytes; a line whose trailing newline is inside the selection
 * extends to the viewport's right edge, giving the familiar full-width look for interior
 * and blank lines. Offsets use the same prefix-width measurement as the caret.
 */
internal func drawTextAreaSelection(
    ctx: UiContext,
    viewport: Rect,
    content: TextAreaContent,
    selStart: Int64,
    selEnd: Int64
): Unit {
    if (selStart >= selEnd) {
        return
    }
    let text = content.text
    let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
    var lineStart = startOfTextLine(text, scrollLineIndex(content.scroll))
    var y = viewport.y - scrollLineRemainder(content.scroll)
    while (y < viewport.bottom()) {
        let lineEnd = lineEndAfterOrAt(text, lineStart)
        let a = max(selStart, lineStart)
        let b = min(selEnd, lineEnd)
        let newlineSelected = lineEnd < text.size && selStart <= lineEnd && selEnd > lineEnd
        if (a < b || newlineSelected) {
            let xA = viewport.x + ctx.renderer.textWidth(text[lineStart..a], pointSize: FontSizes.BODY)
            let xB = if (newlineSelected) {
                viewport.right()
            } else {
                viewport.x + ctx.renderer.textWidth(text[lineStart..b], pointSize: FontSizes.BODY)
            }
            if (xB > xA) {
                ctx.renderer.fill(Rect(xA, y, xB - xA, lineHeight), ctx.theme.accent.withAlpha(115))
            }
        }
        if (lineEnd >= text.size) {
            break
        }
        lineStart = nextTextBoundary(text, lineEnd)
        y += CUI_SMALL_H
    }
}

internal func drawTextAreaCursor(
    ctx: UiContext,
    viewport: Rect,
    id: String,
    content: TextAreaContent
): Unit {
    if (!ctx.hasFocus(id)) {
        return
    }
    // A focused area blinks its caret on the frame clock; keep frames flowing so the dirty-frame
    // loop (档 0) does not freeze the blink even when nothing else changes.
    ctx.requestFrame()
    let position = normalizedTextCursor(content.text, content.cursor)
    let line = textCursorLineIndex(content.text, position)
    let lineStart = lineStartBeforeOrAt(content.text, position)
    let x = viewport.x + ctx.renderer.textWidth(content.text[lineStart..position], pointSize: FontSizes.BODY)
    let y = viewport.y + Float32(line) * CUI_SMALL_H - content.scroll
    if (y + CUI_SMALL_H < viewport.y || y > viewport.bottom()) {
        return // the caret line is scrolled out of view; the last IME anchor stands
    }
    // Rows are drawn from the top of each CUI_SMALL_H cell, so the caret matches the
    // glyph row exactly rather than filling the whole cell.
    let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
    let caret = Rect(x, y, TEXT_CURSOR_W, min(lineHeight, CUI_SMALL_H))
    // The IME anchors its candidate window at the caret whenever the area has focus;
    // the blink phase only gates painting.
    ctx.setTextInputAnchor(caret)
    if (!textCursorVisible(ctx)) {
        return
    }
    ctx.renderer.fill(caret, ctx.theme.accent)
}
