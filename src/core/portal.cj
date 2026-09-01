package cui.core

import sdl.{Rect, Size, UiEvent}

/**
 * Declaratively mounts a real Widget subtree into the application overlay plane. Portal content
 * participates in normal State, focus, semantics, event, and retained-layout protocols, but takes
 * no space in its declaration-site layout. `placement` returns absolute viewport coordinates.
 */
public class Portal <: Widget {
    private let owner: String
    private let child: Widget
    private let placement: (UiContext) -> Rect
    private let blocksInput: Bool
    private let open: Bool

    public init(
        owner: String,
        open: Bool,
        placement: (UiContext) -> Rect,
        blocksInput!: Bool = false,
        body!: () -> Unit
    ) {
        requireControlId(owner, "Portal")
        this.owner = owner
        this.open = open
        this.placement = placement
        this.blocksInput = blocksInput
        this.child = if (open) {
            buildChild("Portal", body)
        } else {
            EmptyView()
        }
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        if (!open) {
            return
        }
        child.layout(ctx, placement(ctx))
        ctx.setOverlay(makeOverlay())
    }

    public func draw(ctx: UiContext): Unit {
        // Custom shells that only bracket draw still get idempotent registration; DesktopApp's
        // stable layout path already registered the same owner and replaces it in place.
        if (open) {
            ctx.setOverlay(makeOverlay())
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func participatesInLayout(): Bool {
        false
    }

    public func needsDetachedLayout(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    private func makeOverlay(): Overlay {
        Overlay(handleEvent: {ctx, event => child.handle(ctx, event) || blocksInput}, render: {ctx => child.draw(ctx)},
            owner: owner)
    }
}
