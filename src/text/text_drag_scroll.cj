package cui.text

import sdl.Rect
import cui.core.{State, UiContext, clampScrollOffset}

private let DRAG_SCROLL_INTERVAL_MS: UInt64 = UInt64(32)
private let DRAG_SCROLL_MAX_STEP_MS: UInt64 = UInt64(64)
private let DRAG_SCROLL_MAX_SPEED: Float32 = 900.0
private let DRAG_SCROLL_MIN_SPEED: Float32 = 80.0
private let DRAG_SCROLL_DISTANCE_GAIN: Float32 = 6.0
private let MILLISECONDS_PER_SECOND: Float32 = 1000.0

// Retained only while the editor exists; subscribes to frames only during an outside drag.
internal class TextDragScroll {
    let active = State<Bool>(false)
    private var pointerX: Float32 = 0.0
    private var pointerY: Float32 = 0.0
    private var lastTick: UInt64 = UInt64(0)
    private var horizontal = true

    func update(ctx: UiContext, viewport: Rect, x: Float32, y: Float32, multiline!: Bool, wrap!: Bool): Unit {
        pointerX = x
        pointerY = y
        horizontal = !wrap
        let outside = (!wrap && (x < viewport.x || x > viewport.right())) || (multiline && (y < viewport.y || y >
            viewport.bottom()))
        active.value = outside && !x.isNaN() && !y.isNaN() && !x.isInf() && !y.isInf()
        lastTick = ctx.frame.elapsedMs
        requestNext(ctx)
    }

    func step(ctx: UiContext, id: String, view: TextEditorView, requireFocus!: Bool = true): Bool {
        if (!active.value) {
            return false
        }
        if (!ctx.isDragging(id) || !ctx.leftMouseDown || (requireFocus && !ctx.hasFocus(id)) || !ctx.textWindowActive()) {
            active.value = false
            return false
        }
        let now = ctx.frame.elapsedMs
        let elapsed = if (now >= lastTick) {
            min(DRAG_SCROLL_MAX_STEP_MS, now - lastTick)
        } else {
            UInt64(0)
        }
        lastTick = now
        if (elapsed == 0) {
            requestNext(ctx);
            return false
        }
        let oldY = view.scroll;
        let oldX = view.xShift
        if (view.multiline) {
            view.scroll = clampScrollOffset(oldY + delta(pointerY, view.viewport.y, view.viewport.bottom(), elapsed),
                view.contentHeight(), view.viewport.h)
        }
        if (horizontal) {
            let row = view.layout.rowAt(view.hit(view.viewport.x, pointerY)[0])
            let limit = max(0.0, view.layout.width(ctx, row) - view.viewport.w + view.caretWidth)
            view.xShift = max(0.0, min(limit, oldX + delta(pointerX, view.viewport.x, view.viewport.right(), elapsed)))
        }
        let changed = view.scroll != oldY || view.xShift != oldX
        if (!changed) {
            active.value = false
        }
        requestNext(ctx)
        changed
    }

    func target(view: TextEditorView): (Int64, Bool) {
        view.hit(max(view.viewport.x, min(pointerX, view.viewport.right() - view.caretWidth)),
            max(view.viewport.y, min(pointerY, view.viewport.bottom() - 1.0)))
    }

    private func requestNext(ctx: UiContext): Unit {
        if (active.value && UInt64.Max - ctx.frame.elapsedMs >= DRAG_SCROLL_INTERVAL_MS) {
            ctx.requestFrameAt(ctx.frame.elapsedMs + DRAG_SCROLL_INTERVAL_MS)
        }
    }

    private func delta(value: Float32, start: Float32, end: Float32, elapsed: UInt64): Float32 {
        let distance = if (value < start) {
            value - start
        } else if (value > end) {
            value - end
        } else {
            Float32(0.0)
        }
        if (distance == 0.0) {
            return 0.0
        }
        let magnitude = if (distance < 0.0) {
            -distance
        } else {
            distance
        }
        let speed = min(DRAG_SCROLL_MAX_SPEED, DRAG_SCROLL_MIN_SPEED + magnitude * DRAG_SCROLL_DISTANCE_GAIN)
        (if (distance < 0.0) {
            -speed
        } else {
            speed
        }) * Float32(elapsed) / MILLISECONDS_PER_SECOND
    }
}
