package cui.core

// A second press within this window and distance of the previous one continues a multi-click.
private let MULTI_CLICK_MS: UInt64 = 400
private let MULTI_CLICK_DIST: Float32 = 4.0

extend UiContext {
    /* Adopts the build-order compatibility ring used by direct/custom hosts. */
    protected func adoptFocusRing(ids: Array<String>): Unit {
        adoptFocusTargets(detachedFocusTargets(ids))
    }

    /* A generational owner mismatch clears stale focus even when the public key is reused. */
    func adoptFocusTargets(targets: Array<FocusTarget>): Unit {
        adoptFocusSnapshot(focusSnapshotFromDeclarations(targets))
    }

    /* Stable composition fragments preserve identity, making an unchanged graph an O(1) commit. */
    func adoptFocusSnapshot(snapshot: FocusSnapshot): Unit {
        match (committedFocusSnapshot) {
            case Some(previous) where sameFocusSnapshot(previous, snapshot) =>
                synchronizeFocusedTarget()
                return
            case _ => ()
        }
        committedFocusSnapshot = Some(snapshot)
        focusOrder = snapshot.targets
        focusTargetByKey.clear()
        focusIndexByKey.clear()
        for (index in 0..snapshot.targets.size) {
            let _ = focusTargetByKey.add(snapshot.targets[index].key, snapshot.targets[index]) // cjcheck-ignore: ignore-result # focus targets are already deduplicated by key
            let _ = focusIndexByKey.add(snapshot.targets[index].key, index) // cjcheck-ignore: ignore-result # focus targets are already deduplicated by key
        }
        focusGraphRevision = nextRevision(focusGraphRevision)
        synchronizeFocusedTarget()
    }

    /** Revision of the committed focus graph for framework diagnostics and test hosts. */
    protected func committedFocusGraphRevision(): UInt64 {
        focusGraphRevision
    }

    /** Moves keyboard focus to the next focusable control, wrapping at the end. */
    public func focusNext(): Unit {
        moveFocus(1)
    }

    /** Moves keyboard focus to the previous focusable control, wrapping at the start. */
    public func focusPrevious(): Unit {
        moveFocus(-1)
    }

    private func moveFocus(step: Int64): Unit {
        let count = focusOrder.size
        if (count == 0) {
            return
        }
        let current = match (focusIndexByKey.get(focusId)) {
            case Some(index) where sameFocusTarget(focusOrder[index], resolvedFocusedTarget()) => index
            case _ => -1
        }
        let next = if (current < 0) {
            if (step > 0) {
                0
            } else {
                count - 1
            }
        } else {
            (((current + step) % count) + count) % count
        }
        focusedTarget = Some(focusOrder[next])
        focusId = focusOrder[next].key
        focusRingVisible = true
    }

    /** Whether `id` currently owns keyboard focus. */
    public func hasFocus(id: String): Bool {
        markRetainedPaintDynamic("focus read during paint")
        focusId == id
    }

    /* Internal owner-preserving match used by subtree event routing. */
    func hasFocusTarget(target: FocusTarget): Bool {
        sameFocusTarget(resolvedFocusedTarget(), target)
    }

    /** Whether `id` owns keyboard focus and should paint a keyboard-visible ring. */
    public func showFocusRing(id: String): Bool {
        markRetainedPaintDynamic("focus ring read during paint")
        focusId == id && focusRingVisible
    }

    /** Gives keyboard focus to `id`; `viaKeyboard` controls focus-ring visibility. */
    public func focus(id: String, viaKeyboard!: Bool = false): Unit {
        if (!compositionOwner.isEmpty() && compositionOwner != id) {
            resetImeState()
        }
        focusId = id
        focusedTarget = focusTargetForKey(id)
        focusClaimedInPress = true
        focusRingVisible = viaKeyboard
    }

    /** Removes keyboard focus from every control. */
    public func clearFocus(): Unit {
        resetImeState()
        focusId = ""
        focusedTarget = None
        focusRingVisible = false
    }

    private func synchronizeFocusedTarget(): Unit {
        if (focusId.isEmpty()) {
            focusedTarget = None
            return
        }
        match (focusedTarget) {
            case Some(current) =>
                match (focusTargetByKey.get(current.key)) {
                    case Some(target) where sameFocusTarget(target, current) => return
                    case _ => ()
                }
                if (current.owner.slot < 0) {
                    focusedTarget = focusTargetForKey(focusId)
                    if (focusedTarget.isSome()) {
                        return
                    }
                }
            case None =>
                focusedTarget = focusTargetForKey(focusId)
                if (focusedTarget.isSome()) {
                    return
                }
        }
        clearFocus()
    }

    private func resolvedFocusedTarget(): FocusTarget {
        match (focusedTarget) {
            case Some(target) => target
            case None => FocusTarget.detached(focusId)
        }
    }

    private func focusTargetForKey(id: String): ?FocusTarget {
        focusTargetByKey.get(id)
    }

    func semanticOwnerForKey(id: String): ElementId {
        match (focusTargetByKey.get(id)) {
            case Some(target) => target.owner
            case None => activeAutomaticElementId()
        }
    }

    private func resetImeState(): Unit {
        compositionOwner = ""
        compositionValue = None
        candidateValue = None
    }

    /** Classifies a primary press as single/double/triple before dispatch. */
    protected func recordPress(x: Float32, y: Float32): Unit {
        let now = frame.elapsedMs
        let dx = x - lastPressX
        let dy = y - lastPressY
        let near = dx * dx + dy * dy <= MULTI_CLICK_DIST * MULTI_CLICK_DIST
        let quick = hasLastPress && now >= lastPressMs && now - lastPressMs <= MULTI_CLICK_MS && near
        if (quick) {
            clickCount = if (clickCount >= 3) {
                1
            } else {
                clickCount + 1
            }
        } else {
            clickCount = 1
        }
        lastPressMs = now
        lastPressX = x
        lastPressY = y
        hasLastPress = true
    }

    protected func beginPointerPress(): Unit {
        focusClaimedInPress = false
    }

    protected func settleFocusAfterPress(): Unit {
        if (!focusClaimedInPress) {
            clearFocus()
        }
    }
}
