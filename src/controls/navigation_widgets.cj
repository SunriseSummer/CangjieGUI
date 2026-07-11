/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.controls

import sdl.{MouseButton, Rect, Size, UiEvent}
import cui.core.{CUI_CONTROL_H, CUI_GAP, State, UiContext, Widget, buildChildren, drawSurface, emit}

public class SegmentedControl <: Widget {
    private let items: Array<String>
    private let selected: State<Int64>
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: State<Int64>) {
        this.items = items
        this.selected = selected
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        let desired = max(96.0, Float32(items.size) * 96.0)
        Size(min(available.w, desired), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (items.size == 0) {
            return
        }
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))
        let segmentW = frame.w / Float32(items.size)
        var i: Int64 = 0
        while (i < items.size) {
            drawSegment(ctx, i, Rect(frame.x + Float32(i) * segmentW, frame.y, segmentW, frame.h))
            i += 1
        }
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y) && items.size > 0) {
                    let segmentW = frame.w / Float32(items.size)
                    selected.value = clampIndex(Int64((x - frame.x) / segmentW), items.size)
                    return true
                }
            case _ => ()
        }
        false
    }

    private func drawSegment(ctx: UiContext, i: Int64, rect: Rect): Unit {
        if (i == clampIndex(selected.value, items.size)) {
            let pill = rect.inset(3.0)
            drawSurface(ctx, pill, ctx.theme.selectedSurface())
            ctx.renderer.textCenter(items[i], rect, ctx.theme.accentText)
        } else {
            ctx.renderer.textCenter(items[i], rect, ctx.theme.text)
        }
    }
}

public class TabView <: Widget {
    private let labels: Array<String>
    private let selected: State<Int64>
    private let pages: Array<Widget>
    private var frame = Rect.zero()
    private var laidOutPage: Int64 = -1

    public init(labels: Array<String>, selected: State<Int64>, body!: () -> Unit) {
        this.labels = labels
        this.selected = selected
        this.pages = buildChildren(body)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        layoutActivePage(ctx)
    }

    public func draw(ctx: UiContext): Unit {
        drawTabs(ctx)
        if (pages.size > 0) {
            ensureActivePageLayout(ctx)
            pages[pageIndex()].draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (handleTabs(event)) {
            ensureActivePageLayout(ctx)
            return true
        }
        if (pages.size > 0) {
            ensureActivePageLayout(ctx)
            return pages[pageIndex()].handle(ctx, event)
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    private func pageIndex(): Int64 {
        clampIndex(selected.value, pages.size)
    }

    private func layoutActivePage(ctx: UiContext): Unit {
        if (pages.size == 0) {
            return
        }
        let index = pageIndex()
        pages[index].layout(ctx, pageFrame())
        laidOutPage = index
    }

    /*
     * The selected tab can change between a frame's layout pass and its draw/handle
     * passes — a click switches pages mid event drain, or code drives the State. The
     * incoming page is laid out again on demand so it is never drawn or handled with a
     * stale (or never assigned) frame.
     */
    private func ensureActivePageLayout(ctx: UiContext): Unit {
        if (pages.size > 0) {
            if (pageIndex() != laidOutPage) {
                layoutActivePage(ctx)
            }
        }
    }

    private func pageFrame(): Rect {
        Rect(frame.x, frame.y + CUI_CONTROL_H + CUI_GAP, frame.w, max(0.0, frame.h - CUI_CONTROL_H - CUI_GAP))
    }

    private func drawTabs(ctx: UiContext): Unit {
        if (labels.size == 0) {
            return
        }
        let header = Rect(frame.x, frame.y, frame.w, CUI_CONTROL_H)
        drawSurface(ctx, header, ctx.theme.fieldSurface(false))
        let tabW = frame.w / Float32(labels.size)
        var i: Int64 = 0
        while (i < labels.size) {
            let rect = Rect(frame.x + Float32(i) * tabW, frame.y, tabW, CUI_CONTROL_H)
            if (i == clampIndex(selected.value, labels.size)) {
                drawSurface(ctx, rect.inset(3.0), ctx.theme.selectedSurface())
                ctx.renderer.textCenter(labels[i], rect, ctx.theme.accentText)
            } else {
                ctx.renderer.textCenter(labels[i], rect, ctx.theme.text)
            }
            i += 1
        }
    }

    private func handleTabs(event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let header = Rect(frame.x, frame.y, frame.w, CUI_CONTROL_H)
                if (header.contains(x, y) && labels.size > 0) {
                    let tabW = frame.w / Float32(labels.size)
                    selected.value = clampIndex(Int64((x - frame.x) / tabW), labels.size)
                    return true
                }
            case _ => ()
        }
        false
    }
}

private func clampIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0 || index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
