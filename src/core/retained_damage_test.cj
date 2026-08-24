package cui.core

import sdl.{Color, Rect, Size, UiEvent}

private class DamageRegionProbe <: Widget {
    private let color: Color
    private var frame = Rect.zero()

    init(color: Color) {
        this.color = color
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(60.0, available.w), min(40.0, available.h))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fill(frame, color)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class DamageGap <: Widget {
    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(40.0, available.w), min(40.0, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

private class RootPhaseDamageProbe <: Widget {
    private let layoutState: State<Int64>
    private let paintState: State<Int64>

    init(layoutState: State<Int64>, paintState: State<Int64>) {
        this.layoutState = layoutState
        this.paintState = paintState
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        let _ = layoutState.value
    }

    public func draw(_: UiContext): Unit {
        let _ = paintState.value
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func retainedDamageLocalizesBoundaryStateButRootBuildStateForcesFull(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let rootState = State<Int64>(0)
    let leftState = State<Int64>(0)
    let viewport = Rect(0.0, 0.0, 200.0, 80.0)
    let body: () -> Unit = {
        => let _ = rootState.value
        HStack {
            RetainedSubtree("left", cachePaint: true) {
                DamageRegionProbe(if (leftState.value == 0) {Color.rgb(10, 20, 30)} else {Color.rgb(40, 50, 60)})
            }
            DamageGap()
            RetainedSubtree("right", cachePaint: true) {
                DamageRegionProbe(Color.rgb(70, 80, 90))
            }
        }
    }

    let first = buildRoot(body, store)
    layoutRoot(store, first, ctx, viewport)
    @Expect(isFullDamage(takeRetainedFrameDamage(store, viewport, true)))
    drawRoot(store, first, ctx)

    leftState.value = 1
    let second = buildRoot(body, store)
    layoutRoot(store, second, ctx, viewport)
    match (takeRetainedFrameDamage(store, viewport, true)) {
        case RetainedFrameDamage.Region(rect) =>
            @Expect(rect.w > 0.0)
            @Expect(rect.w < viewport.w)
        case RetainedFrameDamage.FullFrame => @Fail("retained boundary update should produce partial damage")
    }
    drawRoot(store, second, ctx)

    rootState.value = 1
    let third = buildRoot(body, store)
    layoutRoot(store, third, ctx, viewport)
    @Expect(isFullDamage(takeRetainedFrameDamage(store, viewport, true)))
}

@Test
func rootLayoutAndPaintStateDependenciesForceFullDamage(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let layoutState = State<Int64>(0)
    let paintState = State<Int64>(0)
    let viewport = Rect(0.0, 0.0, 120.0, 60.0)
    let body: () -> Unit = {=> RootPhaseDamageProbe(layoutState, paintState)}

    let first = buildRoot(body, store)
    layoutRoot(store, first, ctx, viewport)
    @Expect(isFullDamage(takeRetainedFrameDamage(store, viewport, true)))
    drawRoot(store, first, ctx)

    layoutState.value = 1
    let second = buildRoot(body, store)
    layoutRoot(store, second, ctx, viewport)
    @Expect(isFullDamage(takeRetainedFrameDamage(store, viewport, true)))
    drawRoot(store, second, ctx)

    paintState.value = 1
    let third = buildRoot(body, store)
    layoutRoot(store, third, ctx, viewport)
    @Expect(isFullDamage(takeRetainedFrameDamage(store, viewport, true)))
}

private func layoutRoot(store: StateStore, widget: Widget, ctx: UiContext, rect: Rect): Unit {
    collectRootLayoutStateReads(store, {=> widget.layout(ctx, rect)})
}

private func drawRoot(store: StateStore, widget: Widget, ctx: UiContext): Unit {
    collectRootPaintStateReads(store, {=> widget.draw(ctx)})
}

private func isFullDamage(damage: RetainedFrameDamage): Bool {
    match (damage) {
        case RetainedFrameDamage.FullFrame => true
        case RetainedFrameDamage.Region(_) => false
    }
}
