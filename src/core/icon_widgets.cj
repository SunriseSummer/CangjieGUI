package cui.core

import sdl.{Color, Rect, Size, UiEvent}

/**
 * A hairline rule separating content: 1 logical pixel thick along its `axis`, stretched across the
 * cross axis by the parent stack. Color defaults to the theme's panel edge.
 */
public class Divider <: Widget {
    private var dividerAxis: Axis
    private var dividerColor: ?Color
    private var frame = Rect.zero()

    public init(axis!: Axis = Axis.Horizontal, color!: ?Color = None) {
        this.dividerAxis = axis
        this.dividerColor = color
        emit(this)
    }

    /** Sets the divider orientation. */
    public func axis(value: Axis): Divider {
        dividerAxis = value
        this
    }

    /** Overrides the theme divider color, matching Label/Icon's `foregroundColor` naming. */
    public func foregroundColor(value: Color): Divider {
        dividerColor = Some(value)
        this
    }

    /** Deprecated alias for `foregroundColor`; kept so existing call sites keep working. */
    public func color(value: Color): Divider {
        foregroundColor(value)
    }

    public func measure(_: UiContext, _: Size): Size {
        // A divider only contributes its 1px thickness to a container's content size; the
        // parent's layout stretches it along the cross axis to span its siblings.
        match (dividerAxis) {
            case Axis.Horizontal => Size(0.0, 1.0)
            case Axis.Vertical => Size(1.0, 0.0)
        }
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let c = match (dividerColor) {
            case Some(value) => value
            case None => ctx.theme.panelEdge
        }
        ctx.renderer.fill(dividerRect(), c)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }

    private func dividerRect(): Rect {
        match (dividerAxis) {
            case Axis.Horizontal => Rect(frame.x, frame.centerY(), frame.w, 1.0)
            case Axis.Vertical => Rect(frame.centerX(), frame.y + 4.0, 1.0, max(0.0, frame.h - 8.0))
        }
    }
}
