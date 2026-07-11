/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.text

import sdl.{FontSizes, Key, MouseButton, Point, Rect, Size, UiEvent}
import cui.core.{CUI_SMALL_H, State, UiContext, Widget, clampScrollOffset, drawSurface, drawVerticalScrollBar, emit, 
    scrollLineIndex, scrollLineRemainder, scrollOffsetAfterWheel}

public class TextArea <: Widget {
    private let id: String
    private let text: State<String>
    private let scroll: State<Float32>
    private let cursor: State<Int64>
    private let editable: Bool
    private var frame = Rect.zero()

    public init(
        id: String,
        text: State<String>,
        scroll!: ?State<Float32> = None,
        cursor!: ?State<Int64> = None,
        editable!: Bool = true
    ) {
        this.id = id
        this.text = text
        this.scroll = match (scroll) {
            case Some(value) => value
            case None => State<Float32>(0.0)
        }
        this.cursor = match (cursor) {
            case Some(value) => value
            case None => State<Int64>(text.value.size)
        }
        this.editable = editable
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        TextEditState(text, cursor: Some(cursor)).normalizeCursor()
        scroll.value = clampScrollOffset(scroll.value, textContentHeight(text.value), textViewport(frame).h)
        drawTextAreaBox(ctx, frame, id, TextAreaContent(text.value, cursor.value, scroll.value))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let edit = TextEditState(text, cursor: Some(cursor))
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => return focusIfInside(ctx, edit, x, y)
            case UiEvent.MouseWheel(_, y, x, pointerY) =>
                if (frame.contains(x, pointerY)) {
                    scroll.value = scrollOffsetAfterWheel(scroll.value, y, textContentHeight(text.value),
                        textViewport(frame).h)
                    return true
                }
            case UiEvent.TextInput(value) =>
                if (ctx.hasFocus(id) && editable) {
                    edit.insert(value)
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(id) && editable) {
                    edit.insert("\n")
                    return true
                }
            case UiEvent.KeyDown(Key.Backspace, _) =>
                if (ctx.hasFocus(id) && editable) {
                    edit.backspace()
                    return true
                }
            case UiEvent.KeyDown(Key.Delete, _) => return handleTextKey(ctx, {=> edit.deleteForward()},
                enabled: editable)
            case UiEvent.KeyDown(Key.Left, _) => return handleTextKey(ctx, {=> edit.moveLeft()})
            case UiEvent.KeyDown(Key.Right, _) => return handleTextKey(ctx, {=> edit.moveRight()})
            case UiEvent.KeyDown(Key.Up, _) => return handleTextKey(ctx, {=> edit.moveLineUp()})
            case UiEvent.KeyDown(Key.Down, _) => return handleTextKey(ctx, {=> edit.moveLineDown()})
            case UiEvent.KeyDown(Key.Home, _) => return handleTextKey(ctx, {=> edit.moveToLineStart()})
            case UiEvent.KeyDown(Key.End, _) => return handleTextKey(ctx, {=> edit.moveToLineEnd()})
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    private func focusIfInside(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            ctx.focus(id)
            edit.moveTo(
                textAreaCursorForPoint(
                    ctx,
                    frame,
                    TextAreaContent(text.value, cursor.value, scroll.value),
                    Point(x, y)
                )
            )
            return true
        }
        false
    }

    private func handleTextKey(
        ctx: UiContext,
        action: () -> Unit,
        enabled!: Bool = true
    ): Bool {
        if (!ctx.hasFocus(id) || !enabled) {
            return false
        }
        action()
        true
    }
}

private func drawTextAreaBox(
    ctx: UiContext,
    frame: Rect,
    id: String,
    content: TextAreaContent
): Unit {
    drawTextBoxChrome(ctx, frame, id)
    let viewport = textViewport(frame)
    ctx.renderer.setClip(viewport)
    drawLines(ctx, viewport, content.text, content.scroll)
    drawTextAreaCursor(ctx, viewport, id, content)
    ctx.renderer.resetClip()
    drawVerticalScrollBar(ctx, frame, content.scroll, textContentHeight(content.text), viewport.h)
}

internal func drawTextBoxChrome(ctx: UiContext, frame: Rect, id: String): Unit {
    drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.hasFocus(id)))
}

private func drawLines(ctx: UiContext, rect: Rect, text: String, scroll: Float32): Unit {
    let lines = text.split("\n")
    var i = scrollLineIndex(scroll)
    var y = rect.y - scrollLineRemainder(scroll)
    while (i < lines.size && y < rect.bottom()) {
        ctx.renderer.text(lines[i], rect.x, y, ctx.theme.text, pointSize: FontSizes.BODY)
        y += CUI_SMALL_H
        i += 1
    }
}

private func textContentHeight(text: String): Float32 {
    Float32(text.split("\n").size) * CUI_SMALL_H
}

private func textViewport(frame: Rect): Rect {
    textInputViewport(frame)
}
