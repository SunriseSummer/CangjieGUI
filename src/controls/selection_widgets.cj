/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.controls

import sdl.{Color, FontSizes, MouseButton, Rect, Size, UiEvent}
import cui.core.{CUI_CONTROL_H, CUI_SMALL_H, State, UiContext, Widget, clampScrollOffset, drawSurface, 
    drawVerticalScrollBar, emit, scrollLineIndex, scrollLineRemainder, scrollOffsetAfterWheel}

public class Checkbox <: Widget {
    private let label: String
    private let checked: State<Bool>
    private var frame = Rect.zero()

    public init(label: String, checked: State<Bool>) {
        this.label = label
        this.checked = checked
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, ctx.renderer.textWidth(label) + 34.0), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let box = Rect(frame.x, frame.y + 7.0, 18.0, 18.0)
        drawSurface(ctx, box, ctx.theme.fieldSurface(false).withBorder(if (checked.value) {
            ctx.theme.accent
        } else {
            ctx.theme.panelEdge
        }))
        if (checked.value) {
            ctx.renderer.fillRoundedRect(box.inset(4.0), ctx.theme.smallRadius, ctx.theme.accent)
        }
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, frame.x + 26.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    checked.value = !checked.value
                    return true
                }
            case _ => ()
        }
        false
    }
}

public class ListView <: Widget {
    private let items: Array<String>
    private let selected: State<Int64>
    private let scroll: State<Float32>
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: State<Int64>, scroll!: ?State<Float32> = None) {
        this.items = items
        this.selected = selected
        this.scroll = match (scroll) {
            case Some(value) => value
            case None => State<Float32>(0.0)
        }
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        scroll.value = clampScrollOffset(scroll.value, listContentHeight(items), listViewport(frame).h)
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))

        let viewport = listViewport(frame)
        ctx.renderer.setClip(viewport)
        var i = scrollLineIndex(scroll.value)
        var y = viewport.y - scrollLineRemainder(scroll.value)
        while (i < items.size && y < viewport.bottom()) {
            drawRow(ctx, i, Rect(viewport.x, y, viewport.w, CUI_SMALL_H))
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.resetClip()
        drawVerticalScrollBar(ctx, frame, scroll.value, listContentHeight(items), viewport.h)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    let idx = Int64((y - listViewport(frame).y + scroll.value) / CUI_SMALL_H)
                    if (idx >= 0 && idx < items.size) {
                        selected.value = idx
                    }
                    return true
                }
            case UiEvent.MouseWheel(_, y, x, pointerY) =>
                if (frame.contains(x, pointerY)) {
                    scroll.value = scrollOffsetAfterWheel(scroll.value, y, listContentHeight(items),
                        listViewport(frame).h)
                    return true
                }
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    private func drawRow(ctx: UiContext, i: Int64, row: Rect): Unit {
        if (i == selected.value) {
            ctx.renderer.fillRoundedRect(row.inset(2.0), ctx.theme.smallRadius, ctx.theme.accent)
            drawRowText(ctx, items[i], row, ctx.theme.accentText)
        } else {
            drawRowText(ctx, items[i], row, ctx.theme.text)
        }
    }
}

private func drawRowText(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
    let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
    ctx.renderer.text(text, row.x + 6.0, textY, color, pointSize: FontSizes.BODY)
}

private func listContentHeight(items: Array<String>): Float32 {
    Float32(items.size) * CUI_SMALL_H
}

private func listViewport(frame: Rect): Rect {
    Rect(frame.x + 4.0, frame.y + 6.0, max(0.0, frame.w - 12.0), max(0.0, frame.h - 12.0))
}
