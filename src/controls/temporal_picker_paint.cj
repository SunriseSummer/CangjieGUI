package cui.controls

import cui.core.{UiContext, drawSurface}
import cui.media.{IconSource, paintIcon}
import sdl.{FontSizes, Rect}

// Two 10-unit side insets, an 18-unit icon and an 8-unit text/icon gap.
internal let TEMPORAL_FIELD_CHROME: Float32 = 46.0

// Callers choose only their own icon package; this common painter contains no resource catalog.
internal func drawTemporalPickerField(ctx: UiContext, frame: Rect, label: String, active: Bool, icon: IconSource): Unit {
    drawSurface(ctx, frame, ctx.theme.fieldSurface(active: active))
    let labelArea = Rect(frame.x + 10.0, frame.y, max(0.0, frame.w - TEMPORAL_FIELD_CHROME), frame.h)
    ctx.renderer.pushClip(labelArea)
    try {
        let size = ctx.textSize(fallback: FontSizes.CONTROL)
        ctx.text(label, labelArea.x, frame.centerY() - ctx.textHeight(pointSize: size) / 2.0, ctx.theme.text,
            pointSize: size)
    } finally {
        ctx.renderer.popClip()
    }
    ctx.renderer.pushClip(frame)
    try {
        paintIcon(ctx, icon, Rect(frame.right() - 28.0, frame.centerY() - 9.0, 18.0, 18.0), ctx.theme.mutedText)
    } finally {
        ctx.renderer.popClip()
    }
}
