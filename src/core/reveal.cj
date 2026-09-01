package cui.core

import sdl.{Rect, Size, UiEvent, clampF32}

/*
 * An animated disclosure container: it eases its own height between zero and its content's natural
 * height whenever `shown` flips, so content slides open and closed instead of snapping. This is the
 * declarative-transition counterpart to a plain conditional — drop a `Reveal` around any subtree and
 * toggling `shown` animates it.
 *
 * The reveal fraction is held in a persistent `Animator` (via `localState`, keyed by identity) so it
 * survives the per-frame rebuild, exactly as the animated controls keep their `Spring`. The child is
 * laid out at its full height and clipped to the revealed portion, so it wipes in from the top rather
 * than squashing. While in motion the animator requests the next frame, so the dirty-frame loop keeps
 * rendering; a settled reveal costs nothing and leaves a static first frame (snapshot) unchanged.
 */
public class Reveal <: Widget {
    private let child: Widget
    private let shown: Bool
    private let animator: Animator
    private var frame = Rect.zero()
    private var contentHeight: Float32 = 0.0

    public init(
        shown!: Bool,
        key!: ?String = None,
        duration!: UInt64 = 220,
        easing!: Easing = Easing.EaseInOutQuad,
        delay!: UInt64 = 0,
        content!: () -> Unit
    ) {
        this.child = buildChild("Reveal", content)
        this.shown = shown
        let id = resolveControlKey(key, "Reveal")
        // Start at the current disclosure state so a first frame that is already open (or closed) is
        // settled and does not animate — only a later toggle eases. `duration`, `easing` and `delay` are
        // read when the animator is first created, so vary the `key` to re-create one with new timing.
        this.animator = localState<Animator>("${id}:reveal") {
            Animator(if (shown) {
                1.0
            } else {
                0.0
            }, duration: duration, easing: easing, delay: delay)
        }.value
        emit(this)
    }

    // The current disclosure fraction in [0, 1] (EaseOutBack can overshoot past 1 mid-flight).
    private func fraction(): Float32 {
        clampF32(animator.value, 0.0, 1.0)
    }

    // Fully shut with no animation pending: nothing is visible, so nothing may interact either.
    private func isFullyCollapsed(): Bool {
        !shown && fraction() <= 0.0
    }

    // The revealed height is the current animated fraction of the child's natural height. Measure reads
    // the fraction the last frame's draw ticked, so the reported height tracks the animation.
    public func measure(ctx: UiContext, available: Size): Size {
        let full = child.measure(ctx, Size(available.w, LAYOUT_UNBOUNDED))
        contentHeight = full.h
        Size(full.w, contentHeight * fraction())
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // Lay the child out at its full natural height, anchored to the top; drawing clips it to the
        // revealed portion so it slides in from the top instead of squashing.
        let visible = Rect(rect.x, rect.y, rect.w, min(contentHeight * fraction(), rect.h))
        ctx.withSpatialClip(verticalViewportSpatialClip(visible, child.paintOutset())) {
            => child.layout(ctx, Rect(rect.x, rect.y, rect.w, contentHeight))
        }
    }

    public func draw(ctx: UiContext): Unit {
        let f = clampF32(animator.animate(ctx, target: if (shown) {
            1.0
        } else {
            0.0
        }), 0.0, 1.0)
        // Clip to the revealed portion, but never past this frame's allocated height: the tick above
        // has already advanced beyond the fraction measure() reported, and painting that extra band
        // would overdraw whatever the parent laid out directly below. The lost sliver is repainted
        // next frame once measure catches up.
        let visible = min(contentHeight * f, frame.h)
        if (visible <= 0.5) {
            return
        }
        ctx.drawWithinSpatialClip(
            verticalViewportSpatialClip(Rect(frame.x, frame.y, frame.w, visible), child.paintOutset())) {
            => child.draw(ctx)
        }
    }

    /*
     * Input follows visibility. The child is laid out at its full natural height (so it wipes rather
     * than squashes), which leaves it a live full-size frame even when this Reveal is collapsed —
     * containers broadcast events to every child, so without gating a hidden button would still absorb
     * clicks in the space now occupied by whatever is drawn below. Frame ticks always flow (animations
     * and polling in a hidden subtree keep running); pointer events must land inside the revealed,
     * clipped portion; and a fully collapsed Reveal swallows nothing and offers no focus stops.
     */
    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) => return child.handle(ctx, event)
            case _ => ()
        }
        if (isFullyCollapsed()) {
            return false
        }
        let visible = Rect(frame.x, frame.y, frame.w, min(contentHeight * fraction(), frame.h))
        match (event) {
            case UiEvent.MouseDown(_, x, y) where !visible.contains(x, y) => return false
            case UiEvent.MouseUp(_, x, y) where !visible.contains(x, y) => return false
            case UiEvent.MouseMove(x, y) where !visible.contains(x, y) => return false
            case UiEvent.MouseWheel(_, _, x, y) where !visible.contains(x, y) => return false
            case _ => ()
        }
        child.handle(ctx, event)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func needsDetachedLayout(): Bool {
        !isFullyCollapsed() && child.needsDetachedLayout()
    }

    public func paintOutset(): PaintOutset {
        if (isFullyCollapsed()) {
            PaintOutset()
        } else {
            child.paintOutset().horizontalOnly()
        }
    }

    public func focusableIds(): Array<String> {
        // Hidden content is not reachable by Tab: keyboard access follows visibility, like pointer input.
        if (isFullyCollapsed()) {
            return Array<String>()
        }
        child.focusableIds()
    }
}
