package cui.core

import sdl.{Pen, Rect, SurfaceStyle, clampF32}

/*
 * Maximum fallback overflow for theme-dependent built-in surfaces whose concrete SurfaceStyle is
 * resolved only during draw. Generic containers no longer apply this value to every child: static
 * modifiers and custom widgets publish a precise PaintOutset, while Panel/ReorderableList use this
 * bound only for their late-bound theme surface.
 */
protected let CUI_SHADOW_CLEARANCE: Float32 = 16.0

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
 * A keyboard focus ring: an accent rounded outline hugging the control, drawn a couple of pixels
 * outside its bounds so it reads as a halo distinct from the control's own edge. Every focusable
 * control paints one (gated on `showFocusRing`, so it shows for keyboard focus only), giving Tab
 * navigation a uniform, visible indicator across buttons, toggles and fields alike. Public so
 * application-defined widgets draw the same ring as built-in controls.
 */
public func drawFocusRing(ctx: UiContext, rect: Rect, radius: Float32): Unit {
    ctx.renderer.strokeRoundedRect(rect.inset(-2.0), radius + 2.0, Pen(width: 1.6, color: ctx.theme.accent))
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
