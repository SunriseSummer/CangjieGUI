package cui.core

import sdl.{Rect, clampF32}

internal let CUI_SCROLL_W: Float32 = 6.0
internal let CUI_SCROLL_MARGIN: Float32 = 2.0
internal let CUI_SCROLL_MIN_THUMB_H: Float32 = 18.0
internal let CUI_SCROLL_WHEEL_STEP: Float32 = 72.0

/**
 * Viewport width a scrollable container reserves for the bar once content overflows,
 * so the bar rides in its own lane instead of covering the content's right edge.
 * Module-visible: popup lists (Dropdown/ComboBox) reserve the same lane.
 */
protected func scrollBarGutter(): Float32 {
    CUI_SCROLL_W + CUI_SCROLL_MARGIN * 2.0
}

protected func scrollOffsetAfterWheel(
    current: Float32,
    wheelY: Float32,
    contentH: Float32,
    viewportH: Float32
): Float32 {
    clampF32(current - wheelY * CUI_SCROLL_WHEEL_STEP, 0.0, maxScrollOffset(contentH, viewportH))
}

internal func maxScrollOffset(contentH: Float32, viewportH: Float32): Float32 {
    max(0.0, contentH - viewportH)
}

protected func clampScrollOffset(current: Float32, contentH: Float32, viewportH: Float32): Float32 {
    clampF32(current, 0.0, maxScrollOffset(contentH, viewportH))
}

protected func scrollLineIndex(offset: Float32): Int64 {
    Int64(max(0.0, offset) / CUI_SMALL_H)
}

protected func scrollLineRemainder(offset: Float32): Float32 {
    max(0.0, offset) - Float32(scrollLineIndex(offset)) * CUI_SMALL_H
}

/** The scrollbar track rectangle: a fixed-width lane inset from the frame's right edge. */
internal func scrollBarTrackRect(frame: Rect): Rect {
    Rect(frame.right() - CUI_SCROLL_W - CUI_SCROLL_MARGIN, frame.y + CUI_SCROLL_MARGIN, CUI_SCROLL_W,
        max(0.0, frame.h - CUI_SCROLL_MARGIN * 2.0))
}

/** Thumb length, proportional to how much of the content is visible, with a floor. */
internal func scrollThumbHeight(track: Rect, contentH: Float32, viewportH: Float32): Float32 {
    if (contentH <= 0.0) {
        return track.h
    }
    max(CUI_SCROLL_MIN_THUMB_H, track.h * viewportH / contentH)
}

/** Thumb top for a given scroll offset. */
internal func scrollThumbTop(
    track: Rect,
    thumbH: Float32,
    offset: Float32,
    contentH: Float32,
    viewportH: Float32
): Float32 {
    let maxOffset = maxScrollOffset(contentH, viewportH)
    if (maxOffset <= 0.0) {
        return track.y
    }
    track.y + max(0.0, track.h - thumbH) * clampF32(offset / maxOffset, 0.0, 1.0)
}

/** The thumb rectangle, or `None` when the content fits and no bar is shown. */
internal func scrollThumbRect(frame: Rect, offset: Float32, contentH: Float32, viewportH: Float32): ?Rect {
    if (contentH <= viewportH || frame.h <= 0.0) {
        return None
    }
    let track = scrollBarTrackRect(frame)
    let thumbH = scrollThumbHeight(track, contentH, viewportH)
    Some(Rect(track.x, scrollThumbTop(track, thumbH, offset, contentH, viewportH), track.w, thumbH))
}

/** Inverse of `scrollThumbTop`: maps a dragged thumb top back to a scroll offset. */
internal func scrollOffsetForThumbTop(
    thumbTop: Float32,
    track: Rect,
    thumbH: Float32,
    contentH: Float32,
    viewportH: Float32
): Float32 {
    let scrollableTrack = max(0.0, track.h - thumbH)
    if (scrollableTrack <= 0.0) {
        return 0.0
    }
    clampF32((thumbTop - track.y) / scrollableTrack, 0.0, 1.0) * maxScrollOffset(contentH, viewportH)
}

/*
 * Shared thumb-drag controller for any vertical scroll surface. A widget owns one keyed by
 * a stable drag id and forwards its bar presses and moves here, so ScrollView, ListView and
 * TextArea get identical draggable-thumb and track-paging behavior from one implementation.
 */
public class ScrollBar {
    private let dragId: String
    private var grabDy: Float32 = 0.0

    public init(dragId: String) {
        this.dragId = dragId
    }

    /** Whether the thumb is being dragged right now (drives the active highlight). */
    public func dragging(ctx: UiContext): Bool {
        ctx.isDragging(dragId)
    }

    /*
     * Consumes a primary press on the bar: grabs the thumb (recording the grab point so the
     * drag tracks the pointer without jumping) or pages the view when the track is clicked
     * beside the thumb. Returns whether the press belonged to the bar.
     */
    public func press(
        ctx: UiContext,
        frame: Rect,
        offset: State<Float32>,
        contentH: Float32,
        viewportH: Float32,
        x: Float32,
        y: Float32
    ): Bool {
        match (scrollThumbRect(frame, offset.value, contentH, viewportH)) {
            case Some(thumb) =>
                if (thumb.contains(x, y)) {
                    ctx.beginDrag(dragId)
                    grabDy = y - thumb.y
                    return true
                }
                if (scrollBarTrackRect(frame).contains(x, y)) {
                    let direction: Float32 = if (y < thumb.y) {
                        -1.0
                    } else {
                        1.0
                    }
                    offset.value = clampScrollOffset(offset.value + direction * viewportH * Float32(0.9), contentH,
                        viewportH)
                    return true
                }
                false
            case None => false
        }
    }

    /** Continues an in-progress thumb drag, mapping the pointer to a scroll offset. */
    public func drag(
        ctx: UiContext,
        frame: Rect,
        offset: State<Float32>,
        contentH: Float32,
        viewportH: Float32,
        y: Float32
    ): Bool {
        if (ctx.isDragging(dragId) && ctx.leftMouseDown) {
            let track = scrollBarTrackRect(frame)
            let thumbH = scrollThumbHeight(track, contentH, viewportH)
            offset.value = scrollOffsetForThumbTop(y - grabDy, track, thumbH, contentH, viewportH)
            return true
        }
        false
    }
}

protected func drawVerticalScrollBar(
    ctx: UiContext,
    frame: Rect,
    offset: Float32,
    contentH: Float32,
    viewportH: Float32,
    active!: Bool = false
): Unit {
    if (contentH <= viewportH || frame.h <= 0.0) {
        return
    }
    let track = scrollBarTrackRect(frame)
    let thumbH = scrollThumbHeight(track, contentH, viewportH)
    let thumbTop = scrollThumbTop(track, thumbH, offset, contentH, viewportH)
    ctx.renderer.fill(track, ctx.theme.panelEdge.withAlpha(80))
    let thumbAlpha = if (active) {
        230
    } else {
        180
    }
    ctx.renderer.fill(Rect(track.x, thumbTop, track.w, thumbH), ctx.theme.accent.withAlpha(thumbAlpha))
}

/*
 * Horizontal counterparts of the scroll-bar geometry above, for surfaces that scroll along x (LazyRow).
 * The offset math (clampScrollOffset, maxScrollOffset, scrollOffsetAfterWheel) is axis-neutral and shared;
 * only the bar's rectangle and thumb differ, so these mirror the vertical helpers along the other axis.
 */

/** The horizontal scrollbar track: a fixed-height lane inset from the frame's bottom edge. */
internal func scrollBarTrackRectH(frame: Rect): Rect {
    Rect(frame.x + CUI_SCROLL_MARGIN, frame.bottom() - CUI_SCROLL_W - CUI_SCROLL_MARGIN,
        max(0.0, frame.w - CUI_SCROLL_MARGIN * 2.0), CUI_SCROLL_W)
}

/** Thumb length along x, proportional to how much of the content is visible, with a floor. */
internal func scrollThumbWidth(track: Rect, contentW: Float32, viewportW: Float32): Float32 {
    if (contentW <= 0.0) {
        return track.w
    }
    max(CUI_SCROLL_MIN_THUMB_H, track.w * viewportW / contentW)
}

/** Thumb left edge for a given scroll offset. */
internal func scrollThumbLeft(
    track: Rect,
    thumbW: Float32,
    offset: Float32,
    contentW: Float32,
    viewportW: Float32
): Float32 {
    let maxOffset = maxScrollOffset(contentW, viewportW)
    if (maxOffset <= 0.0) {
        return track.x
    }
    track.x + max(0.0, track.w - thumbW) * clampF32(offset / maxOffset, 0.0, 1.0)
}

/** The horizontal thumb rectangle, or `None` when the content fits and no bar is shown. */
internal func scrollThumbRectH(frame: Rect, offset: Float32, contentW: Float32, viewportW: Float32): ?Rect {
    if (contentW <= viewportW || frame.w <= 0.0) {
        return None
    }
    let track = scrollBarTrackRectH(frame)
    let thumbW = scrollThumbWidth(track, contentW, viewportW)
    Some(Rect(scrollThumbLeft(track, thumbW, offset, contentW, viewportW), track.y, thumbW, track.h))
}

/** Inverse of `scrollThumbLeft`: maps a dragged thumb left back to a scroll offset. */
internal func scrollOffsetForThumbLeft(
    thumbLeft: Float32,
    track: Rect,
    thumbW: Float32,
    contentW: Float32,
    viewportW: Float32
): Float32 {
    let scrollableTrack = max(0.0, track.w - thumbW)
    if (scrollableTrack <= 0.0) {
        return 0.0
    }
    clampF32((thumbLeft - track.x) / scrollableTrack, 0.0, 1.0) * maxScrollOffset(contentW, viewportW)
}

protected func drawHorizontalScrollBar(
    ctx: UiContext,
    frame: Rect,
    offset: Float32,
    contentW: Float32,
    viewportW: Float32,
    active!: Bool = false
): Unit {
    if (contentW <= viewportW || frame.w <= 0.0) {
        return
    }
    let track = scrollBarTrackRectH(frame)
    let thumbW = scrollThumbWidth(track, contentW, viewportW)
    let thumbLeft = scrollThumbLeft(track, thumbW, offset, contentW, viewportW)
    ctx.renderer.fill(track, ctx.theme.panelEdge.withAlpha(80))
    let thumbAlpha = if (active) {
        230
    } else {
        180
    }
    ctx.renderer.fill(Rect(thumbLeft, track.y, thumbW, track.h), ctx.theme.accent.withAlpha(thumbAlpha))
}

/*
 * Horizontal thumb-drag controller, mirroring `ScrollBar` along x for surfaces that scroll horizontally.
 * A widget owns one keyed by a stable drag id and forwards its bar presses and moves here.
 */
public class HScrollBar {
    private let dragId: String
    private var grabDx: Float32 = 0.0

    public init(dragId: String) {
        this.dragId = dragId
    }

    /** Whether the thumb is being dragged right now (drives the active highlight). */
    public func dragging(ctx: UiContext): Bool {
        ctx.isDragging(dragId)
    }

    /*
     * Consumes a primary press on the bar: grabs the thumb (recording the grab point) or pages the view
     * when the track is clicked beside the thumb. Returns whether the press belonged to the bar.
     */
    public func press(
        ctx: UiContext,
        frame: Rect,
        offset: State<Float32>,
        contentW: Float32,
        viewportW: Float32,
        x: Float32,
        y: Float32
    ): Bool {
        match (scrollThumbRectH(frame, offset.value, contentW, viewportW)) {
            case Some(thumb) =>
                if (thumb.contains(x, y)) {
                    ctx.beginDrag(dragId)
                    grabDx = x - thumb.x
                    return true
                }
                if (scrollBarTrackRectH(frame).contains(x, y)) {
                    let direction: Float32 = if (x < thumb.x) {
                        -1.0
                    } else {
                        1.0
                    }
                    offset.value = clampScrollOffset(offset.value + direction * viewportW * Float32(0.9), contentW,
                        viewportW)
                    return true
                }
                false
            case None => false
        }
    }

    /** Continues an in-progress thumb drag, mapping the pointer to a scroll offset. */
    public func drag(
        ctx: UiContext,
        frame: Rect,
        offset: State<Float32>,
        contentW: Float32,
        viewportW: Float32,
        x: Float32
    ): Bool {
        if (ctx.isDragging(dragId) && ctx.leftMouseDown) {
            let track = scrollBarTrackRectH(frame)
            let thumbW = scrollThumbWidth(track, contentW, viewportW)
            offset.value = scrollOffsetForThumbLeft(x - grabDx, track, thumbW, contentW, viewportW)
            return true
        }
        false
    }
}
