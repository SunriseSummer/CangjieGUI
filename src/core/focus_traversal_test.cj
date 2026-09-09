package cui.core


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

@Test
func duplicateExplicitFocusIdsKeepOneOrderedStop(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Button("First", {=>}).key("shared")
            Button("Second", {=>}).key("shared")
            Button("Tail", {=>}).key("tail")
        }
    }, store)
    let ring = store.focusRing()

    @Expect(ring.size, Int64(2))
    @Expect(ring[0], "shared")
    @Expect(ring[1], "tail")
}

@Test
func focusTargetRejectsAReusedElementSlotWithTheSamePublicKey(): Unit {
    let ctx = testContext()
    let arena = ElementArena()
    let first = arena.mount("first", arena.rootId, ElementKind.Automatic)
    ctx.adoptFocusTargets([FocusTarget(first, "shared")])
    ctx.focus("shared")

    arena.release(first)
    let replacement = arena.mount("replacement", arena.rootId, ElementKind.Automatic)
    @Expect(first.slot, replacement.slot)
    @Expect(first.generation != replacement.generation)
    ctx.adoptFocusTargets([FocusTarget(replacement, "shared")])

    @Expect(ctx.focusId, "")
}

@Test
func retainedFocusTargetKeepsItsElementOwnerAcrossCacheHits(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let body = {
        =>
            let _ = RetainedSubtree("pane") {
                Button("Editor", {=>}).key("editor")
            }
    }
    let _ = buildRoot(body, store)
    store.adoptFocus(ctx)
    ctx.focus("editor")

    let _ = buildRoot(body, store)
    store.adoptFocus(ctx)

    @Expect(ctx.focusId, "editor")

    let firstStableRevision = ctx.focusGraphRevision
    let _ = buildRoot(body, store)
    store.adoptFocus(ctx)
    @Expect(ctx.focusGraphRevision, firstStableRevision)
}

@Test
func stableAutomaticFocusGraphReusesOneCommittedOrder(): Unit {
    let ctx = testContext()
    let store = StateStore()
    enableAutomaticComposition(store)
    let body: () -> Unit = {
        => VStack {
            Button("First", {=>}).key("first")
            Button("Second", {=>}).key("second")
        }
        ()
    }

    let _ = buildRoot(body, store)
    store.adoptFocus(ctx)
    let _ = buildRoot(body, store)
    store.adoptFocus(ctx)
    let firstStableRevision = ctx.focusGraphRevision
    let _ = buildRoot(body, store)
    store.adoptFocus(ctx)

    @Expect(ctx.focusGraphRevision, firstStableRevision)
}

@Test
func dirtyAutomaticBranchComposesCleanFocusFragmentsInOrder(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let showMiddle = State<Bool>(false)
    let body: () -> Unit = {
        => VStack {
            VStack {
                Button("First", {=>}).key("first")
            }
            VStack {
                if (showMiddle.value) {
                    Button("Middle", {=>}).key("middle")
                }
            }
            VStack {
                Button("Last", {=>}).key("last")
            }
        }
        ()
    }

    let _ = buildRoot(body, store)
    expectFocusRing(store.focusRing(), ["first", "last"])
    showMiddle.value = true
    let _ = buildRoot(body, store)
    expectFocusRing(store.focusRing(), ["first", "middle", "last"])
    showMiddle.value = false
    let _ = buildRoot(body, store)
    let restored = store.focusRing()
    @Expect(restored.size, Int64(2))
    expectFocusRing(restored, ["first", "last"])
}

@Test
func focusFragmentsKeepFirstDuplicateKeyAsTheOnlyTabStop(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let body: () -> Unit = {
        => VStack {
            VStack {
                Button("First", {=>}).key("shared")
            }
            VStack {
                Button("Second", {=>}).key("shared")
                Button("Tail", {=>}).key("tail")
            }
        }
        ()
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    let ring = store.focusRing()
    @Expect(ring.size, Int64(2))
    expectFocusRing(ring, ["shared", "tail"])
}

private func expectFocusRing(actual: Array<String>, expected: Array<String>): Unit {
    @Expect(actual.size, expected.size)
    for (index in 0..expected.size) {
        @Expect(actual[index], expected[index])
    }
}
