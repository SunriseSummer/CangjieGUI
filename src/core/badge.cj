package cui.core

import sdl.{Color, FontSizes, Rect, Size, UiEvent}

private let BADGE_H: Float32 = 22.0
private let BADGE_HPAD: Float32 = 9.0

/** Semantic color of a `Badge`: neutral, the theme accent, or an info/success/warning/danger status. */
public enum BadgeKind {
    | Neutral
    | Accent
    | Info
    | Success
    | Warning
    | Danger
}

/*
 * A compact status label — a rounded pill with a soft tinted background and same-hue text. Pure display
 * (no interaction); use it for statuses, categories, counts and tags. The color follows `kind`; the pill
 * hugs its text.
 */
public class Badge <: Widget {
    private let text: String
    private let kind: BadgeKind
    private var frame = Rect.zero()

    public init(text: String, kind!: BadgeKind = BadgeKind.Neutral) {
        this.text = text
        this.kind = kind
        emit(this)
    }

    public func measure(ctx: UiContext, _: Size): Size {
        Size(ctx.renderer.textWidth(text, pointSize: FontSizes.CAPTION) + 2.0 * BADGE_HPAD, BADGE_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func isFlexible(): Bool {
        false
    }

    public func draw(ctx: UiContext): Unit {
        let base = badgeColor(ctx, kind)
        ctx.renderer.fillRoundedRect(frame, frame.h / 2.0, base.withAlpha(36))
        let tw = ctx.renderer.textWidth(text, pointSize: FontSizes.CAPTION)
        let ty = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) / 2.0
        ctx.renderer.text(text, frame.centerX() - tw / 2.0, ty, base, pointSize: FontSizes.CAPTION)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

// The base color for a badge kind: neutral/accent/danger track the theme; info/success/warning are a
// fixed semantic palette that reads on both light and dark surfaces through the soft tint.
internal func badgeColor(ctx: UiContext, kind: BadgeKind): Color {
    match (kind) {
        case BadgeKind.Neutral => ctx.theme.mutedText
        case BadgeKind.Accent => ctx.theme.accent
        case BadgeKind.Info => Color.rgb(56, 118, 214)
        case BadgeKind.Success => Color.rgb(34, 158, 92)
        case BadgeKind.Warning => Color.rgb(198, 142, 36)
        case BadgeKind.Danger => ctx.theme.danger
    }
}
