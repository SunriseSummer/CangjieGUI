/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.text

import sdl.{FontSizes, Point, Rect}
import cui.core.{CUI_SMALL_H, UiContext}

private let TEXT_CURSOR_W: Float32 = 1.5
private let TEXT_FIELD_PAD_X: Float32 = 8.0
private let TEXT_FIELD_PAD_Y: Float32 = 8.0

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

internal func textFieldCursorForPoint(ctx: UiContext, frame: Rect, text: String, x: Float32): Int64 {
    let cellWidth = ctx.renderer.textWidth(" ", pointSize: FontSizes.BODY)
    let column = Int64(max(0.0, x - frame.x - TEXT_FIELD_PAD_X) / cellWidth)
    textCursorAtLineColumn(text, 0, column)
}

internal func textAreaCursorForPoint(
    ctx: UiContext,
    frame: Rect,
    content: TextAreaContent,
    point: Point
): Int64 {
    let viewport = textInputViewport(frame)
    let line = Int64(max(0.0, point.y - viewport.y + content.scroll) / CUI_SMALL_H)
    let column = Int64(max(0.0, point.x - viewport.x) / ctx.renderer.textWidth(" ", pointSize: FontSizes.BODY))
    textCursorAtLineColumn(content.text, line, column)
}

internal func drawTextFieldCursor(ctx: UiContext, frame: Rect, id: String, text: String, cursor: Int64): Unit {
    if (!ctx.hasFocus(id)) {
        return
    }
    let position = normalizedTextCursor(text, cursor)
    let x = frame.x + TEXT_FIELD_PAD_X + ctx.renderer.textWidth(text[0..position], pointSize: FontSizes.BODY)
    ctx.renderer.fill(Rect(x, frame.y + TEXT_FIELD_PAD_Y, TEXT_CURSOR_W, frame.h - TEXT_FIELD_PAD_Y * 2.0),
        ctx.theme.accent)
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
    let position = normalizedTextCursor(content.text, content.cursor)
    let line = textCursorLineIndex(content.text, position)
    let lineStart = lineStartBeforeOrAt(content.text, position)
    let x = viewport.x + ctx.renderer.textWidth(content.text[lineStart..position], pointSize: FontSizes.BODY)
    let y = viewport.y + Float32(line) * CUI_SMALL_H - content.scroll
    if (y + CUI_SMALL_H < viewport.y || y > viewport.bottom()) {
        return
    }
    ctx.renderer.fill(Rect(x, y, TEXT_CURSOR_W, CUI_SMALL_H), ctx.theme.accent)
}
