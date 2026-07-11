/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Insets, Rect, Size, UiEvent}

/*
 * Flex layout engine shared by VStack and HStack. Internal on purpose: it takes a
 * ready-made child array and never registers itself with a builder block, so callers
 * (the stack facades and buildChild) stay in control of what is emitted.
 */
class Stack <: Widget {
    private let axis: Axis
    private let children: Array<Widget>
    private let spacing: Float32
    private let padding: Insets
    private let flexible: Bool

    init(
        axis: Axis,
        children: Array<Widget>,
        spacing!: Float32 = CUI_GAP,
        padding!: Insets = Insets(0.0),
        flexible!: Bool = true
    ) {
        this.axis = axis
        this.children = children
        this.spacing = spacing
        this.padding = padding
        this.flexible = flexible
    }

    // Content size along the main axis is the sum of child extents; the cross axis hugs
    // the tallest/widest child. This lets a container opt out of filling (flexible: false)
    // and be laid out at exactly the size of what it holds, e.g. a compact toolbar row.
    public func measure(ctx: UiContext, available: Size): Size {
        let inner = Size(max(0.0, available.w - padding.horizontal()), max(0.0, available.h - padding.vertical()))
        var along: Float32 = 0.0
        var cross: Float32 = 0.0
        for (child in children) {
            let size = child.measure(ctx, inner)
            match (axis) {
                case Axis.Horizontal =>
                    along += size.w
                    cross = max(cross, size.h)
                case Axis.Vertical =>
                    along += size.h
                    cross = max(cross, size.w)
            }
        }
        along += spacingTotal()
        match (axis) {
            case Axis.Horizontal => Size(along + padding.horizontal(), cross + padding.vertical())
            case Axis.Vertical => Size(cross + padding.horizontal(), along + padding.vertical())
        }
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let inner = rect.inset(padding)
        match (axis) {
            case Axis.Vertical => layoutVertical(ctx, inner)
            case Axis.Horizontal => layoutHorizontal(ctx, inner)
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (child in children) {
            child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) => return broadcast(ctx, event)
            case _ => ()
        }
        var i = children.size - 1
        while (i >= 0) {
            if (children[i].handle(ctx, event)) {
                return true
            }
            i -= 1
        }
        false
    }

    public func isFlexible(): Bool {
        flexible
    }

    private func layoutVertical(ctx: UiContext, rect: Rect): Unit {
        let fixed = fixedHeight(ctx, Size(rect.w, rect.h))
        let unit = flexUnit(max(0.0, rect.h - fixed - spacingTotal()))
        var y = rect.y
        for (child in children) {
            let h = if (child.isFlexible()) {
                flexExtent(child, unit)
            } else {
                child.measure(ctx, Size(rect.w, rect.h)).h
            }
            child.layout(ctx, Rect(rect.x, y, rect.w, h))
            y += h + spacing
        }
    }

    private func layoutHorizontal(ctx: UiContext, rect: Rect): Unit {
        let fixed = fixedWidth(ctx, Size(rect.w, rect.h))
        let unit = flexUnit(max(0.0, rect.w - fixed - spacingTotal()))
        var x = rect.x
        for (child in children) {
            let w = if (child.isFlexible()) {
                flexExtent(child, unit)
            } else {
                child.measure(ctx, Size(rect.w, rect.h)).w
            }
            child.layout(ctx, Rect(x, rect.y, w, rect.h))
            x += w + spacing
        }
    }

    /*
     * Size of one weight unit. Leftover space is shared among flexible children in
     * proportion to flexWeight. A child of weight w also absorbs the (w - 1) gaps it
     * spans (see flexExtent), so those gaps are removed from the shared pool first —
     * that keeps a weight-2 cell exactly aligned with two single cells plus their gap.
     */
    private func flexUnit(remaining: Float32): Float32 {
        var weightTotal: Float32 = 0.0
        var flexCount: Int64 = 0
        for (child in children) {
            if (child.isFlexible()) {
                weightTotal += child.flexWeight()
                flexCount += 1
            }
        }
        if (weightTotal <= 0.0) {
            return 0.0
        }
        let absorbedGaps = spacing * (weightTotal - Float32(flexCount))
        max(0.0, remaining - absorbedGaps) / weightTotal
    }

    private func flexExtent(child: Widget, unit: Float32): Float32 {
        let weight = child.flexWeight()
        max(0.0, unit * weight + spacing * (weight - 1.0))
    }

    private func spacingTotal(): Float32 {
        if (children.size <= 1) {
            0.0
        } else {
            Float32(children.size - 1) * spacing
        }
    }

    private func fixedHeight(ctx: UiContext, available: Size): Float32 {
        var total: Float32 = 0.0
        for (child in children) {
            if (!child.isFlexible()) {
                total += child.measure(ctx, available).h
            }
        }
        total
    }

    private func fixedWidth(ctx: UiContext, available: Size): Float32 {
        var total: Float32 = 0.0
        for (child in children) {
            if (!child.isFlexible()) {
                total += child.measure(ctx, available).w
            }
        }
        total
    }

    private func broadcast(ctx: UiContext, event: UiEvent): Bool {
        for (child in children) {
            let _ = child.handle(ctx, event)
        }
        false
    }
}
