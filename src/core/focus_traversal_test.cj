package cui.core

import sdl.IconName

/*
 * Keyboard focus traversal walks a build-order ring of focusable controls. Each build
 * records its focusable ids in declaration order; the shell adopts that ring and moves
 * focus with Tab / Shift+Tab. These tests build small trees, adopt the produced ring,
 * and assert the cycle order, the wrap at both ends, and the explicit-id override.
 */
@Test
func tabTraversalCyclesFocusablesInDeclarationOrder(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Button("A", {=>})
            Button("B", {=>})
            Button("C", {=>})
        }
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 3)

    ctx.adoptFocusRing(ring)
    @Expect(ctx.focusId, "")

    ctx.focusNext()
    @Expect(ctx.focusId, ring[0])
    ctx.focusNext()
    @Expect(ctx.focusId, ring[1])
    ctx.focusNext()
    @Expect(ctx.focusId, ring[2])
    ctx.focusNext()
    @Expect(ctx.focusId, ring[0]) // forward past the end wraps to the first

    ctx.focusPrevious()
    @Expect(ctx.focusId, ring[2]) // backward past the start wraps to the last
}

@Test
func shiftTabFromNoFocusEntersAtLastControl(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Button("A", {=>})
            Button("B", {=>})
        }
    }, store)
    ctx.adoptFocusRing(store.focusRing())

    ctx.focusPrevious()
    @Expect(ctx.focusId, store.focusRing()[1])
}

@Test
func heterogeneousControlsAllJoinFocusRing(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Button("Save", {=>})
            IconButton(IconName.Calendar, onClick: {=>})
            Button("Cancel", {=>})
        }
    }, store)
    @Expect(store.focusRing().size, 3)
}

@Test
func explicitIdOverrideReplacesAutoIdInFocusRing(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Button("A", {=>}).key("alpha")
            Button("B", {=>})
        }
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 2) // the override replaced the auto id rather than adding a second entry
    @Expect(ring[0], "alpha")

    ctx.adoptFocusRing(ring)
    ctx.focusNext()
    @Expect(ctx.focusId, "alpha")
}

@Test
func keyedScopesKeepRepeatedControlsDistinctInFocusRing(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Keyed("first") {
                Button("确定", {=>})
            }
            Keyed("second") {
                Button("确定", {=>})
            }
        }
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 2)
    @Expect(ring[0] != ring[1]) // same label, separate identities, two Tab stops
}

@Test
func emptyRingLeavesFocusUnchanged(): Unit {
    let ctx = testContext()
    ctx.adoptFocusRing([])

    ctx.focusNext()
    @Expect(ctx.focusId, "")
    ctx.focusPrevious()
    @Expect(ctx.focusId, "")
}
