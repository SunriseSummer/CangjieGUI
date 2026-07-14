package cui.core

import sdl.{Rect, Size, UiEvent}

public class VStack <: Widget {
    private let stack: Stack

    public init(
        spacing!: Length = vpLength(CUI_GAP),
        padding!: LengthInsets = LengthInsets.zero(),
        flexible!: Bool = true,
        body!: () -> Unit
    ) {
        stack = Stack(Axis.Vertical, buildChildren(body), spacing: spacing, padding: padding, flexible: flexible)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        stack.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        stack.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        stack.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        stack.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        stack.isFlexible()
    }

    public func focusableIds(): Array<String> {
        stack.focusableIds()
    }

    /** Sets the gap between adjacent children, e.g. `.spacing(12.vp)`. */
    public func spacing(value: Length): VStack {
        stack.setSpacing(value)
        this
    }

    /** Sets the gap between adjacent children in virtual pixels. */
    public func spacing(value: Float32): VStack {
        spacing(vpLength(value))
    }

    /** Positions children along the vertical axis when unused space remains. */
    public func mainAxisAlignment(value: MainAxisAlignment): VStack {
        stack.setMainAlignment(value)
        this
    }

    /** Positions children along the horizontal axis. */
    public func crossAxisAlignment(value: CrossAxisAlignment): VStack {
        stack.setCrossAlignment(value)
        this
    }

    /** Controls whether this stack itself participates in its parent's flex pass. */
    public func flexible(value: Bool): VStack {
        stack.setFlexible(value)
        this
    }

    /**
     * Sizes this stack to its content along the parent's main axis rather than filling the offered
     * space — the intent-revealing name for the common `.flexible(false)` (a card or toolbar that
     * should be exactly as tall as what it holds).
     */
    public func hug(): VStack {
        stack.setFlexible(false)
        this
    }
}

public class HStack <: Widget {
    private let stack: Stack

    public init(
        spacing!: Length = vpLength(CUI_GAP),
        padding!: LengthInsets = LengthInsets.zero(),
        flexible!: Bool = true,
        body!: () -> Unit
    ) {
        stack = Stack(Axis.Horizontal, buildChildren(body), spacing: spacing, padding: padding, flexible: flexible)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        stack.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        stack.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        stack.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        stack.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        stack.isFlexible()
    }

    public func focusableIds(): Array<String> {
        stack.focusableIds()
    }

    /** Sets the gap between adjacent children, e.g. `.spacing(12.vp)`. */
    public func spacing(value: Length): HStack {
        stack.setSpacing(value)
        this
    }

    /** Sets the gap between adjacent children in virtual pixels. */
    public func spacing(value: Float32): HStack {
        spacing(vpLength(value))
    }

    /** Positions children along the horizontal axis when unused space remains. */
    public func mainAxisAlignment(value: MainAxisAlignment): HStack {
        stack.setMainAlignment(value)
        this
    }

    /** Positions children along the vertical axis. */
    public func crossAxisAlignment(value: CrossAxisAlignment): HStack {
        stack.setCrossAlignment(value)
        this
    }

    /** Controls whether this stack itself participates in its parent's flex pass. */
    public func flexible(value: Bool): HStack {
        stack.setFlexible(value)
        this
    }

    /**
     * Sizes this stack to its content along the parent's main axis rather than filling the offered
     * space — the intent-revealing name for the common `.flexible(false)` (a card or toolbar that
     * should be exactly as wide as what it holds).
     */
    public func hug(): HStack {
        stack.setFlexible(false)
        this
    }
}

/**
 * Opts its content into the enclosing stack's space-sharing pass. A Flexible child is
 * stretched to `weight` shares of the leftover space instead of hugging its content, so
 * equal-weight cells form aligned columns and a heavier cell spans several of them:
 *
 *     HStack(spacing: 10.vp) {
 *         Flexible(weight: 2.0) { Button("0", onZero) }   // twice as wide as the others
 *         Flexible { Button(".", onDot) }
 *         Flexible { Button("=", onEquals) }
 *     }
 *
 * An empty block (`Flexible {}`) reserves a blank cell, which is how grids keep their
 * column rhythm through missing entries.
 */
public class Flexible <: Widget {
    private let child: Widget
    private let weight: Float32

    public init(weight!: Float32 = 1.0, body!: () -> Unit) {
        this.child = buildChild(body)
        this.weight = max(0.0, weight)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        true
    }

    public func flexWeight(): Float32 {
        weight
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}
