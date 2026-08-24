package cui.core

import sdl.{Rect, UiEvent}

/*
 * An interactive overlay — a dropdown, menu popup, or dialog — that floats above the whole
 * tree. The shell gives the open overlays events *before* the tree, so their clicks and keys
 * are not stolen by controls underneath, and paints them *last*, on top. A control registers
 * one during stable layout (and idempotently during draw for custom-shell compatibility) for as
 * long as it is open; the shell clears the stack before each layout pass. Contrast the tooltip,
 * which is a simpler draw-only overlay.
 *
 * Overlays stack: registration order is z-order, events walk the stack top-down and drawing
 * bottom-up, so a popup opened inside a dialog floats above it and sees events first. `owner`
 * identifies who registered the overlay across frames (controls are rebuilt every frame);
 * a closing control removes exactly its own registration with `UiContext.removeOverlay`.
 */
public class Overlay {
    private let onEvent: (UiContext, UiEvent) -> Bool
    private let onRender: (UiContext) -> Unit
    let owner: String

    public init(handleEvent!: (UiContext, UiEvent) -> Bool, render!: (UiContext) -> Unit, owner!: String = "") {
        this.onEvent = handleEvent
        this.onRender = render
        this.owner = owner
    }

    func dispatch(ctx: UiContext, event: UiEvent): Bool {
        onEvent(ctx, event)
    }

    func render(ctx: UiContext): Unit {
        onRender(ctx)
    }
}

/** Registers a lazily constructed overlay only while its owner is open. */
protected func registerOverlayWhen(ctx: UiContext, open: Bool, overlay: () -> Overlay): Unit {
    if (open) {
        ctx.setOverlay(overlay())
    }
}

/** Shared rectangular-popup registration used by picker-like controls. */
protected func registerRectOverlayWhen(
    ctx: UiContext,
    open: Bool,
    popup: () -> Rect,
    handle: (UiContext, UiEvent, Rect) -> Bool,
    render: (UiContext, Rect) -> Unit,
    owner: String
): Unit {
    registerOverlayWhen(
        ctx,
        open,
        {
            =>
                let rect = popup()
                Overlay(handleEvent: {c, e => handle(c, e, rect)}, render: {c => render(c, rect)}, owner: owner)
        }
    )
}
