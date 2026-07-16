package cui.core

import sdl.{FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}

private let CHIP_H: Float32 = 28.0
private let CHIP_HPAD: Float32 = 12.0

/*
 * A selectable filter tag — a rounded pill bound to a `Bindable<Bool>`. Clicking (or Space/Enter while
 * focused) toggles it; selected it fills with the accent, unselected it is an outlined field. Use a row
 * of them as toggle filters.
 */
public class Chip <: Widget {
    private let text: String
    private let selected: Bindable<Bool>
    private let id: String
    private var frame = Rect.zero()

    public init(text: String, selected: Bindable<Bool>, key!: ?String = None) {
        this.text = text
        this.selected = selected
        this.id = resolveControlKey(key, "Chip")
        registerFocusable(this.id)
        emit(this)
    }

    public func measure(ctx: UiContext, _: Size): Size {
        Size(ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL) + 2.0 * CHIP_HPAD, CHIP_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func isFlexible(): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    public func draw(ctx: UiContext): Unit {
        let on = selected.get()
        let radius = frame.h / 2.0
        if (on) {
            ctx.renderer.fillRoundedRect(frame, radius, ctx.theme.accent)
        } else {
            let hovered = frame.contains(ctx.mouseX, ctx.mouseY)
            ctx.renderer.fillRoundedRect(frame, radius, if (hovered) {
                ctx.theme.fieldActive
            } else {
                ctx.theme.field
            })
            ctx.renderer.strokeRoundedRect(frame, radius, Pen(width: 1.0, color: ctx.theme.panelEdge))
        }
        if (ctx.showFocusRing(id)) {
            ctx.renderer.strokeRoundedRect(frame.inset(-3.0), radius, Pen(width: 1.4, color: ctx.theme.accent))
        }
        let color = if (on) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        let tw = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
        let ty = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, frame.centerX() - tw / 2.0, ty, color, pointSize: FontSizes.CONTROL)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => if (frame.contains(x, y)) {
                ctx.focus(id)
                toggle()
                return true
            }
            case UiEvent.KeyDown(Key.Space, _) => return toggleIfFocused(ctx)
            case UiEvent.KeyDown(Key.Enter, _) => return toggleIfFocused(ctx)
            case _ => ()
        }
        false
    }

    private func toggle(): Unit {
        selected.value = !selected.get()
    }

    private func toggleIfFocused(ctx: UiContext): Bool {
        if (ctx.hasFocus(id)) {
            toggle()
            return true
        }
        false
    }
}
