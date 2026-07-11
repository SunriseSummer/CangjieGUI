/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Rect, clampF32}

internal let CUI_SCROLL_W: Float32 = 6.0
internal let CUI_SCROLL_MIN_THUMB_H: Float32 = 18.0
internal let CUI_SCROLL_WHEEL_STEP: Float32 = 72.0

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

protected func drawVerticalScrollBar(
    ctx: UiContext,
    frame: Rect,
    offset: Float32,
    contentH: Float32,
    viewportH: Float32
): Unit {
    if (contentH <= viewportH || frame.h <= 0.0) {
        return
    }
    let track = Rect(frame.right() - CUI_SCROLL_W - 2.0, frame.y + 2.0, CUI_SCROLL_W, max(0.0, frame.h - 4.0))
    let thumbH = max(CUI_SCROLL_MIN_THUMB_H, track.h * viewportH / contentH)
    let scrollableTrack = max(0.0, track.h - thumbH)
    let thumbY = track.y + scrollableTrack * clampF32(offset / maxScrollOffset(contentH, viewportH), 0.0, 1.0)

    ctx.renderer.fill(track, ctx.theme.panelEdge.withAlpha(80))
    ctx.renderer.fill(Rect(track.x, thumbY, track.w, thumbH), ctx.theme.accent.withAlpha(180))
}
