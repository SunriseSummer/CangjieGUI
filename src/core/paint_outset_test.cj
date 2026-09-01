package cui.core

import sdl.{Color, Rect, Size, UiEvent}

private class PaintOutsetLeaf <: Widget {
    private let overflow: PaintOutset

    init(overflow: PaintOutset) {
        this.overflow = overflow
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func paintOutset(): PaintOutset {
        overflow
    }
}

@Test
func paintOutsetJoinIsACommutativeIdempotentBound(): Unit {
    let a = PaintOutset(left: 3.0, top: 7.0, right: 2.0, bottom: 5.0)
    let b = PaintOutset(left: 8.0, top: 1.0, right: 4.0, bottom: 6.0)
    let ab = a.join(b)
    let ba = b.join(a)
    @Expect(ab.left, Float32(8.0))
    @Expect(ab.top, Float32(7.0))
    @Expect(ab.right, Float32(4.0))
    @Expect(ab.bottom, Float32(6.0))
    @Expect(ab.left, ba.left)
    @Expect(ab.top, ba.top)
    @Expect(ab.right, ba.right)
    @Expect(ab.bottom, ba.bottom)
    @Expect(a.join(a).left, a.left)
    @Expect(a.join(a).bottom, a.bottom)
}

@Test
func paintOutsetExpandsAsymmetricBoundsAndClampsNegativeInput(): Unit {
    let outset = PaintOutset(left: 2.0, top: -9.0, right: 5.0, bottom: 7.0)
    let expanded = outset.expand(Rect(10.0, 20.0, 30.0, 40.0))
    @Expect(expanded.x, Float32(8.0))
    @Expect(expanded.y, Float32(20.0))
    @Expect(expanded.w, Float32(37.0))
    @Expect(expanded.h, Float32(47.0))
}

@Test
func configurableShadowPublishesItsActualAsymmetricHalo(): Unit {
    let shadow = Shadow(color: Color.rgba(0, 0, 0, 64), offsetX: 10.0, offsetY: -4.0, blur: 40.0, spread: 5.0)
    let outset = configurableShadowPaintOutset(shadow)
    @Expect(outset.left, Float32(25.0))
    @Expect(outset.top, Float32(39.0))
    @Expect(outset.right, Float32(45.0))
    @Expect(outset.bottom, Float32(31.0))
    let none = configurableShadowPaintOutset(shadow.withColor(Color.rgba(0, 0, 0, 0)))
    @Expect(none.left, Float32(0.0))
    @Expect(none.bottom, Float32(0.0))
}

@Test
func nestedStackAggregatesLargestDescendantPaintOutset(): Unit {
    let store = StateStore()
    let widget = buildRoot({=> VStack {
        PaintOutsetLeaf(PaintOutset(left: 30.0, right: 2.0))
        PaintOutsetLeaf(PaintOutset(top: 9.0, bottom: 12.0))
    }}, store)
    let outset = widget.paintOutset()
    @Expect(outset.left, Float32(30.0))
    @Expect(outset.top, Float32(9.0))
    @Expect(outset.right, Float32(2.0))
    @Expect(outset.bottom, Float32(12.0))
}
