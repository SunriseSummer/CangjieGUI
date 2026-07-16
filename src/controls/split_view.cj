package cui.controls

import std.collection.ArrayList
import sdl.{Color, Key, MouseButton, Rect, Size, UiEvent, clampF32}
import cui.core.{Axis, Bindable, CursorShape, State, UiContext, Widget, resolveControlKey, buildChild, drawFocusRing,
    emit, localState, registerFocusable}

// The hit area of the divider is widened by this many logical pixels on each side of its
// visual strip, so a thin divider stays easy to grab without enlarging the seam on screen.
private let SPLIT_HANDLE_HIT_PAD: Float32 = 3.0

// How far one arrow-key press nudges the divider (logical pixels) once it holds focus.
private let SPLIT_KEY_STEP: Float32 = 24.0

/**
 * A container that divides its space between two panes with a draggable divider, so the user can
 * trade room between them: a sidebar and a document, a list and its detail, a source view and a
 * preview. `axis` chooses the split direction — `Horizontal` lays the panes side by side with a
 * vertical divider (drag left/right), `Vertical` stacks them with a horizontal divider (drag
 * up/down).
 *
 * The divider position is a fraction of the content extent (the space left after the divider's own
 * thickness) given to the first pane. It is retained by the view's stable identity, or owned
 * externally through `ratio` for persistence or coordinated animation. `minFirst` and `minSecond`
 * are the smallest logical-pixel extents each pane may shrink to; the divider stops at those bounds
 * while dragging. When the container is too small to honour both minimums the split falls back to a
 * proportional one so neither pane collapses to nothing.
 *
 * The divider is a keyboard focus stop between the two panes: once focused, the arrow keys along the
 * split axis nudge it, and it requests the resize pointer shape while hovered or dragged. Each pane
 * is an independent builder block, so a pane may declare any number of widgets (they stack) without
 * a wrapping container.
 *
 * ```
 * SplitView(axis: Axis.Horizontal, minFirst: 160.0, minSecond: 320.0,
 *     first: { navigator() }) { editor() }
 * ```
 */
public class SplitView <: Widget {
    private let axis: Axis
    private let first: Widget
    private let second: Widget
    private let ratio: Bindable<Float32>
    private let minFirst: Float32
    private let minSecond: Float32
    private let dividerThickness: Float32
    private let dividerId: String
    private var frame = Rect.zero()
    // Offset from the pointer to the divider's leading edge at the moment of grab, so the divider
    // tracks the pointer without jumping the seam under the cursor to the pointer position. Retained
    // via localState because a drag spans frames and the widget is rebuilt fresh on every one.
    private let grabOffset: State<Float32>

    public init(
        axis!: Axis = Axis.Horizontal,
        ratio!: ?Bindable<Float32> = None,
        initialRatio!: Float32 = 0.5,
        minFirst!: Float32 = 96.0,
        minSecond!: Float32 = 96.0,
        dividerThickness!: Float32 = 8.0,
        key!: ?String = None,
        first!: () -> Unit,
        second!: () -> Unit
    ) {
        let ident = resolveControlKey(key, "SplitView")
        this.dividerId = "SplitView:${ident}:divider"
        this.axis = axis
        this.minFirst = max(0.0, minFirst)
        this.minSecond = max(0.0, minSecond)
        this.dividerThickness = max(1.0, dividerThickness)
        this.ratio = match (ratio) {
            case Some(external) => external
            case None => localState<Float32>("SplitView:${ident}:ratio") {clampF32(initialRatio, 0.0, 1.0)}
        }
        this.grabOffset = localState<Float32>("SplitView:${ident}:grab") {0.0}
        // Build the first pane, then register the divider, then the second pane, so the divider
        // takes its natural place between the panes in Tab order.
        this.first = buildChild(first)
        registerFocusable(this.dividerId)
        this.second = buildChild(second)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let available = mainOf(rect.w, rect.h)
        let firstExtent = splitFirstExtent(ratio.value, available, dividerThickness, minFirst, minSecond)
        match (axis) {
            case Axis.Horizontal =>
                first.layout(ctx, Rect(rect.x, rect.y, firstExtent, rect.h))
                let secondX = rect.x + firstExtent + dividerThickness
                second.layout(ctx, Rect(secondX, rect.y, max(0.0, rect.right() - secondX), rect.h))
            case Axis.Vertical =>
                first.layout(ctx, Rect(rect.x, rect.y, rect.w, firstExtent))
                let secondY = rect.y + firstExtent + dividerThickness
                second.layout(ctx, Rect(rect.x, secondY, rect.w, max(0.0, rect.bottom() - secondY)))
        }
    }

    public func draw(ctx: UiContext): Unit {
        first.draw(ctx)
        second.draw(ctx)
        drawDivider(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let hit = dividerHitRect()
        // Claim the resize shape whenever the pointer is over the seam, or throughout a live drag
        // even as it strays past the seam. The first claim per move wins, so this beats a pane
        // control that also sits under the pointer in the widened hit band.
        match (event) {
            case UiEvent.MouseMove(x, y) => if (hit.contains(x, y) || ctx.isDragging(dividerId)) {
                ctx.claimHover(dividerId, resizeShape())
            }
            case _ => ()
        }
        match (event) {
            case UiEvent.Frame(_) =>
                let _ = first.handle(ctx, event)
                let _ = second.handle(ctx, event)
                return false
            case UiEvent.MouseDown(MouseButton.Left, x, y) => if (hit.contains(x, y)) {
                ctx.focus(dividerId)
                ctx.beginDrag(dividerId)
                grabOffset.value = mainOf(x, y) - dividerStart()
                return true
            }
            case UiEvent.MouseMove(x, y) => if (ctx.isDragging(dividerId) && ctx.leftMouseDown) {
                ratio.value = ratioForPointer(mainOf(x, y))
                return true
            }
            case UiEvent.MouseUp(MouseButton.Left, x, y) => if (ctx.isDragging(dividerId)) {
                ratio.value = ratioForPointer(mainOf(x, y))
                return true
            }
            case UiEvent.KeyDown(key, _) => if (ctx.hasFocus(dividerId) && nudge(key)) {
                return true
            }
            case _ => ()
        }
        // Panes are disjoint, so dispatch order is a formality; follow the reverse-declaration
        // convention used by the other containers.
        if (second.handle(ctx, event)) {
            return true
        }
        first.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (id in first.focusableIds()) {
            ids.add(id)
        }
        ids.add(dividerId)
        for (id in second.focusableIds()) {
            ids.add(id)
        }
        ids.toArray()
    }

    private func drawDivider(ctx: UiContext): Unit {
        let strip = dividerRect()
        let active = ctx.isDragging(dividerId) || ctx.isHovered(dividerId)
        // A hairline down the centre of the seam, brightening to the accent while active, plus a
        // short grip of three dots so the divider reads as draggable at rest.
        let lineColor = if (active) {
            ctx.theme.accent
        } else {
            ctx.theme.panelEdge
        }
        let gripColor = if (active) {
            ctx.theme.accent
        } else {
            ctx.theme.mutedText
        }
        let lineW = max(1.0, ctx.theme.borderWidth)
        match (axis) {
            case Axis.Horizontal =>
                ctx.renderer.fill(Rect(strip.centerX() - lineW / 2.0, strip.y, lineW, strip.h), lineColor)
                drawGrip(ctx, strip.centerX(), strip.centerY(), false, gripColor)
            case Axis.Vertical =>
                ctx.renderer.fill(Rect(strip.x, strip.centerY() - lineW / 2.0, strip.w, lineW), lineColor)
                drawGrip(ctx, strip.centerX(), strip.centerY(), true, gripColor)
        }
        if (ctx.showFocusRing(dividerId)) {
            drawFocusRing(ctx, strip, ctx.theme.smallRadius)
        }
    }

    // Three dots centred on the seam, laid along its length (down a vertical divider, across a
    // horizontal one), marking where to grab.
    private func drawGrip(ctx: UiContext, cx: Float32, cy: Float32, along: Bool, color: Color): Unit {
        let gap: Float32 = 4.0
        var i: Int64 = -1
        while (i <= 1) {
            let offset = Float32(i) * gap
            let (dotX, dotY) = if (along) {
                (cx + offset, cy)
            } else {
                (cx, cy + offset)
            }
            ctx.renderer.fillCircle(dotX, dotY, 1.1, color)
            i += 1
        }
    }

    // The visual seam between the panes.
    private func dividerRect(): Rect {
        let firstExtent = currentFirstExtent()
        match (axis) {
            case Axis.Horizontal => Rect(frame.x + firstExtent, frame.y, dividerThickness, frame.h)
            case Axis.Vertical => Rect(frame.x, frame.y + firstExtent, frame.w, dividerThickness)
        }
    }

    // The seam widened along the split axis for a forgiving grab target.
    private func dividerHitRect(): Rect {
        let strip = dividerRect()
        match (axis) {
            case Axis.Horizontal => Rect(strip.x - SPLIT_HANDLE_HIT_PAD, strip.y,
                strip.w + SPLIT_HANDLE_HIT_PAD * 2.0, strip.h)
            case Axis.Vertical => Rect(strip.x, strip.y - SPLIT_HANDLE_HIT_PAD, strip.w,
                strip.h + SPLIT_HANDLE_HIT_PAD * 2.0)
        }
    }

    private func currentFirstExtent(): Float32 {
        splitFirstExtent(ratio.value, mainOf(frame.w, frame.h), dividerThickness, minFirst, minSecond)
    }

    private func dividerStart(): Float32 {
        mainOf(frame.x, frame.y) + currentFirstExtent()
    }

    // Maps a pointer position on the split axis back to a stored ratio, honouring the grab offset
    // and the pane minimums.
    private func ratioForPointer(pointerMain: Float32): Float32 {
        let available = mainOf(frame.w, frame.h)
        let content = max(0.0, available - dividerThickness)
        let desired = pointerMain - grabOffset.value - mainOf(frame.x, frame.y)
        let clamped = clampSplitExtent(desired, content, minFirst, minSecond)
        splitRatioForExtent(clamped, available, dividerThickness)
    }

    // Applies an arrow-key nudge along the split axis; returns whether the key belonged to us.
    private func nudge(key: Key): Bool {
        let delta = match ((axis, key)) {
            case (Axis.Horizontal, Key.Left) => -SPLIT_KEY_STEP
            case (Axis.Horizontal, Key.Right) => SPLIT_KEY_STEP
            case (Axis.Vertical, Key.Up) => -SPLIT_KEY_STEP
            case (Axis.Vertical, Key.Down) => SPLIT_KEY_STEP
            case _ => return false
        }
        let available = mainOf(frame.w, frame.h)
        let content = max(0.0, available - dividerThickness)
        let clamped = clampSplitExtent(currentFirstExtent() + delta, content, minFirst, minSecond)
        ratio.value = splitRatioForExtent(clamped, available, dividerThickness)
        true
    }

    private func resizeShape(): CursorShape {
        match (axis) {
            case Axis.Horizontal => CursorShape.ResizeH
            case Axis.Vertical => CursorShape.ResizeV
        }
    }

    private func mainOf(horizontal: Float32, vertical: Float32): Float32 {
        match (axis) {
            case Axis.Horizontal => horizontal
            case Axis.Vertical => vertical
        }
    }
}

/*
 * Clamps a first-pane extent to the pane minimums within `content` (the space left after the
 * divider). When the two minimums cannot both fit, the constraint is dropped and the extent is only
 * bounded by the content, so a shrinking window scales the panes down together instead of pinning
 * one at its minimum and driving the other negative.
 */
internal func clampSplitExtent(extent: Float32, content: Float32, minFirst: Float32, minSecond: Float32): Float32 {
    if (content <= 0.0) {
        return 0.0
    }
    let lo = max(0.0, minFirst)
    let hi = content - max(0.0, minSecond)
    if (lo > hi) {
        return clampF32(extent, 0.0, content)
    }
    clampF32(extent, lo, hi)
}

/** The first pane's main-axis extent for `ratio` of the content within `available` main pixels. */
internal func splitFirstExtent(
    ratio: Float32,
    available: Float32,
    dividerThickness: Float32,
    minFirst: Float32,
    minSecond: Float32
): Float32 {
    let content = max(0.0, available - max(0.0, dividerThickness))
    clampSplitExtent(clampF32(ratio, 0.0, 1.0) * content, content, minFirst, minSecond)
}

/** The ratio placing the divider so the first pane spans `firstExtent` of `available` main pixels. */
internal func splitRatioForExtent(firstExtent: Float32, available: Float32, dividerThickness: Float32): Float32 {
    let content = max(0.0, available - max(0.0, dividerThickness))
    if (content <= 0.0) {
        return 0.0
    }
    clampF32(firstExtent / content, 0.0, 1.0)
}
