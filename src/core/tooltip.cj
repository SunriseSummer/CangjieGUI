package cui.core

import sdl.{FontSizes, Rect, Size, UiEvent, clampF32}

private let TOOLTIP_DELAY_MS: UInt64 = 500
private let TOOLTIP_PAD_X: Float32 = 9.0
private let TOOLTIP_PAD_Y: Float32 = 5.0
private let TOOLTIP_GAP: Float32 = 6.0
private let TOOLTIP_MARGIN: Float32 = 4.0

/*
 * Wraps a control with a hover tooltip. Once the pointer has rested on the child for
 * `TOOLTIP_DELAY_MS`, the child registers its text with the shell, which paints it above the
 * whole tree (a minimal single-slot overlay). Otherwise a transparent wrapper: it forwards
 * measure, layout, draw and events straight to the child.
 */
public class Tooltip <: Widget {
    private let child: Widget
    private let text: String
    private let hoverStart: State<UInt64>
    private var frame = Rect.zero()

    public init(text!: String, body!: () -> Unit) {
        this.child = buildChild(body)
        this.text = text
        // UInt64.Max is the "not hovering" sentinel, so a hover starting at t=0 still counts.
        let key = controlIdentity("Tooltip")
        this.hoverStart = localState<UInt64>("Tooltip:${key}") {UInt64.Max}
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
        let now = ctx.frame.elapsedMs
        if (frame.contains(ctx.mouseX, ctx.mouseY)) {
            if (hoverStart.value == UInt64.Max) {
                hoverStart.value = now
            } else if (now >= hoverStart.value && now - hoverStart.value >= TOOLTIP_DELAY_MS) {
                ctx.showTooltip(text, frame)
            } else {
                // Still counting down to the reveal: request the next frame so the clock keeps
                // advancing while the pointer rests, otherwise the dirty-frame loop (档 0) would idle
                // here and the tooltip would never appear.
                ctx.requestFrame()
            }
        } else if (hoverStart.value != UInt64.Max) {
            hoverStart.value = UInt64.Max // reset once; a per-frame write would be wasted churn
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}

/*
 * Paints the frame's registered tooltip above everything else. Prefers a bubble just below
 * the anchored control, flipping above when it would leave the window, and clamps it inside
 * the window horizontally. The bubble is theme-inverted (dark on light themes, light on dark).
 */
protected func drawTooltip(ctx: UiContext, windowWidth: Float32, windowHeight: Float32): Unit {
    if (ctx.tooltipText.isEmpty()) {
        return
    }
    let text = ctx.tooltipText
    let anchor = ctx.tooltipAnchor
    let width = ctx.renderer.textWidth(text, pointSize: FontSizes.CAPTION) + TOOLTIP_PAD_X * 2.0
    let height = ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) + TOOLTIP_PAD_Y * 2.0

    var y = anchor.bottom() + TOOLTIP_GAP
    if (y + height > windowHeight) {
        y = anchor.y - TOOLTIP_GAP - height
    }
    let x = clampF32(anchor.centerX() - width / 2.0, TOOLTIP_MARGIN, max(TOOLTIP_MARGIN, windowWidth - width - TOOLTIP_MARGIN))
    let bubble = Rect(x, y, width, height)

    ctx.renderer.fillRoundedRect(bubble, ctx.theme.smallRadius, ctx.theme.text.withAlpha(240))
    ctx.renderer.textCenter(text, bubble, ctx.theme.bg, pointSize: FontSizes.CAPTION)
}
