package cui.controls

import sdl.{Color, Key, Rect, Size, SurfaceStyle, UiEvent}
import sdl.input.Keyboard
import cui.core.{Bindable, Overlay, UiContext, Widget, buildChild, controlIdentity, drawSurface, emit,
    focusableCountNow, focusablesSince}

private let MODAL_PADDING: Float32 = 22.0
private let MODAL_MAX_W: Float32 = 460.0

/*
 * A modal dialog. While `presented` is true it floats a centred panel over a dimming backdrop
 * via the interactive overlay — but unlike a dropdown or context menu (which draw their body by
 * hand), a Modal hosts a real widget subtree: its `body` widgets are laid out inside the panel
 * and receive events routed through the overlay, so a dialog can hold buttons, text fields, or
 * anything else with normal state — including controls that open popups of their own (Dropdown,
 * ComboBox, ContextMenu), which register above the dialog on the overlay stack, paint on top,
 * and see events first.
 *
 * Being modal, it swallows every event (nothing reaches the backdrop tree); a press outside the
 * panel or Escape dismisses it. The body is built only while presented, so a hidden dialog costs
 * nothing and registers no focusables. It takes no space in the tree — place it anywhere (a
 * `ZStack` at the root is typical) and it centres itself against the viewport.
 */
public class Modal <: Widget {
    private let presented: Bindable<Bool>
    private let content: ?Widget
    // The focus stops declared inside the dialog body, in build order. A modal is a focus
    // trap: Tab cycles these and never escapes to the controls under the backdrop (which
    // stay in the global ring but cannot receive events while the dialog is open).
    private let contentFocusables: Array<String>
    private let onDismiss: ?() -> Unit
    // Identifies this dialog's overlay registration across per-frame rebuilds, so dismissing
    // removes exactly this dialog from the overlay stack (never a popup opened above it).
    private let overlayOwner: String
    private var dialogRect = Rect.zero()

    public init(presented: Bindable<Bool>, onDismiss!: ?() -> Unit = None, body!: () -> Unit) {
        this.presented = presented
        this.onDismiss = onDismiss
        this.overlayOwner = controlIdentity("Modal")
        if (presented.value) {
            let focusStart = focusableCountNow()
            this.content = Some(buildChild(body))
            this.contentFocusables = focusablesSince(focusStart)
        } else {
            this.content = None
            this.contentFocusables = []
        }
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        match (content) {
            case Some(body) =>
                // Centre the panel against the viewport, sizing it to the body plus padding but
                // never wider/taller than most of the window.
                let maxContentW = max(0.0, min(ctx.viewportWidth * 0.85, MODAL_MAX_W) - MODAL_PADDING * 2.0)
                let maxContentH = max(0.0, ctx.viewportHeight * 0.85 - MODAL_PADDING * 2.0)
                let size = body.measure(ctx, Size(maxContentW, maxContentH))
                let w = size.w + MODAL_PADDING * 2.0
                let h = size.h + MODAL_PADDING * 2.0
                dialogRect = Rect((ctx.viewportWidth - w) / 2.0, (ctx.viewportHeight - h) / 2.0, w, h)
                body.layout(ctx, dialogRect.inset(MODAL_PADDING))
            case None => ()
        }
    }

    public func draw(ctx: UiContext): Unit {
        // Register only once the body exists. `presented` can flip true during this frame's event
        // phase — after init already built `content` as None — and painting then would flash an
        // empty panel for one frame; instead the dialog appears next frame, when the body is built.
        if (presented.value) {
            match (content) {
                case Some(_) =>
                    ctx.setOverlay(Overlay(handleEvent: {c, e => handleModal(c, e)}, render: {c => drawModal(c)},
                        owner: overlayOwner))
                case None => ()
            }
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // Input reaches the dialog subtree through the overlay (`handleModal`); only the
        // per-frame tick is dispatched to the tree directly, so it is forwarded by hand —
        // otherwise timed behaviours inside the dialog (a field's autofocus, an application
        // Frame hook) would never run.
        match (event) {
            case UiEvent.Frame(_) => routeToContent(ctx, event)
            case _ => ()
        }
        false
    }

    public func focusableIds(): Array<String> {
        contentFocusables // the stops the dialog's own focus trap cycles (empty while hidden)
    }

    private func handleModal(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.KeyDown(Key.Escape, _) => dismiss(ctx)
            case UiEvent.KeyDown(Key.Tab, _) =>
                cycleDialogFocus(ctx, if (Keyboard.modifiers().shift) {
                    -1
                } else {
                    1
                })
            case UiEvent.MouseDown(_, x, y) =>
                if (dialogRect.contains(x, y)) {
                    routeToContent(ctx, event)
                } else {
                    dismiss(ctx) // a press on the backdrop dismisses
                }
            case _ => routeToContent(ctx, event)
        }
        true // modal: an event never reaches the backdrop tree
    }

    // Moves keyboard focus by `step` through the dialog's own focus stops, wrapping at the
    // ends; from no (or an outside) focus, forward enters at the first stop and backward at
    // the last — the same entry rule as the shell's window-level traversal.
    private func cycleDialogFocus(ctx: UiContext, step: Int64): Unit {
        let count = contentFocusables.size
        if (count == 0) {
            return
        }
        var current = -1
        for (i in 0..count) {
            if (contentFocusables[i] == ctx.focusId) {
                current = i
                break
            }
        }
        let next = if (current < 0) {
            if (step > 0) {
                0
            } else {
                count - 1
            }
        } else {
            (((current + step) % count) + count) % count
        }
        ctx.focus(contentFocusables[next], viaKeyboard: true)
    }

    private func routeToContent(ctx: UiContext, event: UiEvent): Unit {
        match (content) {
            case Some(body) => let _ = body.handle(ctx, event)
            case None => ()
        }
    }

    private func drawModal(ctx: UiContext): Unit {
        ctx.renderer.fill(Rect(0.0, 0.0, ctx.viewportWidth, ctx.viewportHeight), Color.rgba(12, 14, 20, 130))
        drawSurface(ctx, dialogRect, modalSurface(ctx))
        match (content) {
            case Some(body) => body.draw(ctx)
            case None => ()
        }
    }

    private func dismiss(ctx: UiContext): Unit {
        presented.value = false
        ctx.removeOverlay(overlayOwner)
        match (onDismiss) {
            case Some(callback) => callback()
            case None => ()
        }
    }

    private func modalSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 8.0)
    }
}
