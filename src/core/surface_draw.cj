/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Pen, Rect, SurfaceStyle, clampF32}

/*
 * Paints a themed surface (shadow, border, rounded fill) for a widget. It lives in the
 * GUI layer rather than with the SurfaceStyle value type because it needs the render
 * context (UiContext.renderer); the plain SurfaceStyle data stays in the SDL layer.
 */
protected func drawSurface(ctx: UiContext, rect: Rect, style: SurfaceStyle): Unit {
    if (Int64(style.shadow.a) > 0) {
        drawSoftShadow(ctx, rect, style)
    }
    ctx.renderer.fillRoundedRect(rect, style.radius, style.fill)
    if (style.borderWidth > 0.0 && Int64(style.border.a) > 0) {
        let bw = style.borderWidth
        ctx
            .renderer
            .strokeRoundedRect(rect.inset(bw / 2.0), max(0.0, style.radius - bw / 2.0),
                Pen(width: bw, color: style.border))
    }
}

/*
 * A soft drop shadow drawn as two single-pass gradient halos: each layer is a rounded rect
 * whose edge fades across a wide feather, so the falloff is a smooth ramp with no banding.
 * The wide layer is the ambient penumbra, the tight one the contact darkening; the card is
 * painted on top afterwards, so only the fading halo around it stays visible.
 */
private func drawSoftShadow(ctx: UiContext, rect: Rect, style: SurfaceStyle): Unit {
    let alpha = Int64(style.shadow.a)
    let spread = clampF32(4.0 + style.radius * 0.5, 5.0, 13.0)
    let base = rect.shift(0.0, style.shadowOffsetY)
    ctx
        .renderer
        .fillRoundedRectSoft(base.inset(-spread * 0.3), style.radius + spread * 0.3, style
            .shadow
            .withAlpha(alpha * 3 / 5), feather: spread)
    ctx.renderer.fillRoundedRectSoft(base, style.radius, style.shadow.withAlpha(alpha / 2), feather: spread * 0.5)
}
