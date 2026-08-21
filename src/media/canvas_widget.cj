package cui.media

import sdl.{Rect, Renderer, Size, UiEvent}
import cui.core.{UiContext, Widget, drawSurface, emit}

/*
 * A free-form drawing surface. It is flexible (fills the space it is offered), paints a themed field
 * background, clips to the frame, then hands the raw `Renderer` and the frame rect to `onDraw` —
 * coordinates are absolute, so painters offset from the rect, not from zero. Input events are
 * forwarded to `onEvent` with the same frame; return `true` to consume. Both callbacks run on the
 * per-frame rebuild's fresh instance, so any retained drawing state belongs in `State`, not fields.
 */
public class CanvasWidget <: Widget {
    private let onDraw: (Renderer, Rect) -> Unit
    private var eventHandler: (UiEvent, Rect) -> Bool
    private var frame = Rect.zero()

    public init(onDraw: (Renderer, Rect) -> Unit, onEvent!: (UiEvent, Rect) -> Bool = {_, _ => false}) {
        this.onDraw = onDraw
        this.eventHandler = onEvent
        emit(this)
    }

    /** Sets the event callback, which receives the current canvas frame. */
    public func onEvent(value: (UiEvent, Rect) -> Bool): CanvasWidget {
        eventHandler = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface())
        ctx.renderer.pushClip(frame.inset(1.0))
        onDraw(ctx.renderer, frame)
        ctx.renderer.popClip()
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        eventHandler(event, frame)
    }

    public func isFlexible(): Bool {
        true
    }
}
