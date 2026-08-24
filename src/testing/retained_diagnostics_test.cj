package cui.testing

import sdl.{Rect, Size, UiEvent}
import cui.core.{EffectCleanup, RetainedScopeDiagnostics, RetainedSubtree, State, UiContext, Widget, emit,
    mountEffect}

private class DiagnosticLayoutProbe <: Widget {
    let source: State<Int64>

    init(source: State<Int64>) {
        this.source = source
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        let _ = source.value
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func retainedDiagnosticsAreStableStructuredAndExplainDirtyPropagation(): Unit {
    let host = WidgetTestHost()
    let buildState = State<Int64>(0)
    let layoutState = State<Int64>(0)
    let cleanupCount = State<Int64>(0)
    let body: () -> Unit = {
        => RetainedSubtree("outer") {
            let _ = buildState.value
            mountEffect("listener", {=> EffectCleanup({=> cleanupCount.value += 1})})
            RetainedSubtree("inner") {
                DiagnosticLayoutProbe(layoutState)
            }
        }
    }

    let _ = host.frame(Rect(0.0, 0.0, 240.0, 120.0), body: body)
    let initial = host.retainedDiagnostics()
    @Expect(initial.scopes.size, Int64(3))
    @Expect(initial.scopes[0].path, "<root>")
    @Expect(initial.scopes[1].path, "outer")
    @Expect(initial.scopes[2].path, "outer / inner")
    @Expect(initial.scopes[1].effectCount, Int64(1))
    @Expect(initial.scopes[1].stats.buildDependencyCount, Int64(1))
    @Expect(initial.scopes[2].stats.layoutDependencyCount, Int64(1))
    @Expect(initial.activeEffectCount, Int64(1))
    @Expect(initial.failedEffectCleanupCount, Int64(0))
    @Expect(!initial.fullDamagePending)
    @Expect(initial.pendingDamage.isNone())
    @Expect(initial.scopes[1].bounds.w, 240.0)
    @Expect(initial.describe().contains("outer / inner depth=2"))
    @Expect(initial.describe().contains("damage=none"))

    layoutState.value = 1
    let layoutDirty = host.retainedDiagnostics()
    @Expect(layoutDirty.pendingDamage.isSome())
    @Expect(retainedScopeAt(layoutDirty.scopes, "outer").layoutDirty)
    @Expect(retainedScopeAt(layoutDirty.scopes, "outer").lastInvalidationReason, "descendant layout invalidated")
    @Expect(retainedScopeAt(layoutDirty.scopes, "outer / inner").lastInvalidationReason,
        "layout State dependency changed")

    buildState.value = 1
    let buildDirty = host.retainedDiagnostics()
    @Expect(retainedScopeAt(buildDirty.scopes, "outer").buildDirty)
    @Expect(retainedScopeAt(buildDirty.scopes, "outer").lastInvalidationReason, "State dependency changed")

    let _ = host.frame(Rect(0.0, 0.0, 240.0, 120.0), body: body)
    @Expect(!retainedScopeAt(host.retainedDiagnostics().scopes, "outer").buildDirty)
    host.reset()
    @Expect(cleanupCount.value, Int64(1))
}

func retainedScopeAt(scopes: Array<RetainedScopeDiagnostics>, path: String): RetainedScopeDiagnostics {
    for (scope in scopes) {
        if (scope.path == path) {
            return scope
        }
    }
    throw IllegalStateException("Missing retained diagnostic scope '${path}'")
}
