package cui.core

import std.collection.HashMap
import sdl.Rect

extend UiContext {
    /** Returns the current platform-independent accessibility snapshot in declaration order. */
    public func semanticsSnapshot(): Array<SemanticsNode> {
        semanticsTreeSnapshot().nodes
    }

    /** Indexed semantic tree committed by the latest stable layout transaction. */
    public func semanticsTreeSnapshot(): SemanticsSnapshot {
        ensureCommittedSemantics().snapshot
    }

    /** Returns the committed semantic node for the current focus key, if one exists. */
    public func focusedSemanticsNode(): ?SemanticsNode {
        let snapshot = semanticsTreeSnapshot()
        let focusedId = semanticFocusForSnapshot(snapshot, focusId, focusedTarget)
        if (focusedId.isEmpty()) {
            return None
        }
        snapshot.node(focusedId)
    }

    /** Performs an accessibility action against the latest registration for `id`. */
    public func performSemanticsAction(id: String, action: SemanticsAction): Bool {
        if (!allowsModalSemanticsAction(id)) {
            return false
        }
        match (ensureCommittedSemantics().actionsById.get(id)) {
            case Some(target) => target.perform(action)
            case None => false
        }
    }

    /** Installs or replaces the push adapter and immediately bootstraps it with the committed tree. */
    public func setAccessibilityAdapter(adapter: AccessibilityAdapter): Unit {
        accessibilityAdapter = Some(adapter)
        let snapshot = semanticsTreeSnapshot()
        pushAccessibilityUpdate(adapter,
            AccessibilityUpdate(UInt64(0), snapshot, addedSemanticChanges(snapshot.nodes),
                {id, action => performSemanticsAction(id, action)}))
    }

    /** Registers static semantic properties from a custom widget's layout callback. */
    public func registerSemantics(
        node: SemanticsNode,
        perform!: (SemanticsAction) -> Bool = {_ => false}
    ): Unit {
        registerSemanticProviderWithVisibleBounds(node.id, node.bounds, node.visibleBounds, node.actions,
            {=> node.properties}, perform)
    }

    /* Registers lazily resolved properties so accessibility values do not become layout dependencies. */
    protected func registerSemanticProvider(
        id: String,
        bounds: Rect,
        actions: Array<SemanticsAction>,
        properties: () -> Semantics,
        perform: (SemanticsAction) -> Bool
    ): Unit {
        registerSemanticProviderWithVisibleBounds(id, bounds, bounds, actions, properties, perform)
    }

    private func registerSemanticProviderWithVisibleBounds(
        id: String,
        bounds: Rect,
        visibleBounds: Rect,
        actions: Array<SemanticsAction>,
        properties: () -> Semantics,
        perform: (SemanticsAction) -> Bool
    ): Unit {
        registerSemanticContribution(
            SemanticRegistration(id, semanticOwnerForKey(id), bounds, semanticVisibleBounds(visibleBounds), actions,
                properties, perform, {=> markSemanticProviderDirty()}))
    }

    /* Applies the current layout clip while preserving the un-clipped accessibility bounds. */
    func withSemanticClip<T>(clip: Rect, body: () -> T): T {
        withSpatialClip(exactSpatialClip(clip), body)
    }

    func registerSemanticContribution(contribution: SemanticContribution): Unit {
        semanticContributions.add(contribution)
    }

    /** Clears the prior layout snapshot before the tree re-registers semantic nodes. */
    protected func clearSemantics(): Unit {
        semanticContributions.clear()
    }

    /** Commits one normalized semantic patch after the complete layout transaction stabilizes. */
    protected func commitSemantics(arena!: ?ElementArena = None): Unit {
        let arenaStructureRevision = match (arena) {
            case Some(value) => value.structureRevision()
            case None => UInt64(0)
        }
        match (committedSemantics) {
            case Some(previous) where !semanticProvidersDirty && sameSemanticContributionSequence(
                previous.contributions, semanticContributions) && previous.snapshot.focusedId ==
                semanticFocusForSnapshot(previous.snapshot, focusId, focusedTarget) &&
                previous.arenaStructureRevision == arenaStructureRevision => return
            case _ => ()
        }
        let normalized = normalizeSemantics(semanticContributions)
        let nextFocusedId = semanticFocusForNodes(normalized.nodes, normalized.ownersById, focusId, focusedTarget)
        let previous = match (committedSemantics) {
            case Some(value) => value.snapshot
            case None => SemanticsSnapshot(semanticRevision, [], HashMap<String, ElementId>())
        }
        let topology = match (arena) {
            case Some(value) => semanticTopologyFor(value, normalized.nodes, normalized.ownersById)
            case None => flatSemanticTopology(normalized.nodes.size)
        }
        let changes = semanticsChanges(previous, normalized.nodes, normalized.ownersById, topology, nextFocusedId)
        if (!changes.isEmpty()) {
            semanticRevision = nextRevision(semanticRevision)
        }
        let snapshot = SemanticsSnapshot(semanticRevision, normalized.nodes, normalized.ownersById,
            focusedId: nextFocusedId, topology: Some(topology))
        match (committedSemantics) {
            case Some(value) => value.closeReplacedActions(normalized.actionsById)
            case None => ()
        }
        committedSemantics = Some(
            CommittedSemantics(snapshot, normalized.actionsById, semanticContributions.toArray(), arenaStructureRevision))
        semanticProvidersDirty = false
        match (arena) {
            case Some(value) => commitElementSemanticOwnership(value, previous, snapshot)
            case None => ()
        }
        if (changes.isEmpty()) {
            return
        }
        match (accessibilityAdapter) {
            case Some(adapter) => pushAccessibilityUpdate(adapter,
                AccessibilityUpdate(previous.revision, snapshot, changes,
                    {id, action => performSemanticsAction(id, action)}))
            case None => ()
        }
    }

    /** Clears working and committed semantics, emitting removals to an attached adapter. */
    protected func resetSemantics(): Unit {
        semanticContributions.clear()
        semanticProvidersDirty = true
        commitSemantics()
    }

    func semanticRegistrationCount(): Int64 {
        semanticContributions.size
    }

    func semanticFragmentIfAnyFrom(start: Int64): ?SemanticFragment {
        let from = max(0, start)
        if (from >= semanticContributions.size) {
            return None
        }
        Some(
            SemanticFragment(
                Array<SemanticContribution>(semanticContributions.size - from, {i => semanticContributions[from + i]})))
    }

    func disableSemanticRegistrationsFrom(start: Int64): Unit {
        var index = max(0, start)
        while (index < semanticContributions.size) {
            semanticContributions[index] = semanticContributions[index].forcingDisabled()
            index += 1
        }
    }

    private func ensureCommittedSemantics(): CommittedSemantics {
        match (committedSemantics) {
            case Some(value) => value
            case None =>
                let normalized = normalizeSemantics(semanticContributions)
                let snapshot = SemanticsSnapshot(semanticRevision, normalized.nodes, normalized.ownersById)
                let committed = CommittedSemantics(snapshot, normalized.actionsById, semanticContributions.toArray(),
                    UInt64(0))
                committedSemantics = Some(committed)
                semanticProvidersDirty = false
                committed
        }
    }

    private func markSemanticProviderDirty(): Unit {
        semanticProvidersDirty = true
        requestFrame()
    }

    private func semanticVisibleBounds(bounds: Rect): Rect {
        match (spatialClip) {
            case Some(value) => bounds.intersection(value.visibleBounds)
            case None => bounds
        }
    }

    private func pushAccessibilityUpdate(adapter: AccessibilityAdapter, update: AccessibilityUpdate): Unit {
        try {
            adapter.update(update)
        } catch (error: Exception) {
            accessibilityAdapter = None
            throw error
        }
    }
}

private func semanticOwnerMatchesFocus(semanticOwner: ?ElementId, focus: ?FocusTarget): Bool {
    match ((semanticOwner, focus)) {
        case (Some(owner), Some(target)) =>
            if (owner.slot < 0 || target.owner.slot < 0) {
                owner.slot < 0 && target.owner.slot < 0
            } else {
                sameElementId(owner, target.owner)
            }
        case (Some(owner), None) => owner.slot < 0
        case (None, None) => true
        case _ => false
    }
}

private func semanticFocusForSnapshot(snapshot: SemanticsSnapshot, key: String, focus: ?FocusTarget): String {
    if (key.isEmpty() || snapshot.node(key).isNone() || !semanticOwnerMatchesFocus(snapshot.owner(key), focus)) {
        ""
    } else {
        key
    }
}

private func semanticFocusForNodes(
    nodes: Array<SemanticsNode>,
    owners: HashMap<String, ElementId>,
    key: String,
    focus: ?FocusTarget
): String {
    if (key.isEmpty() || !semanticOwnerMatchesFocus(owners.get(key), focus)) {
        return ""
    }
    for (node in nodes) {
        if (node.id == key) {
            return key
        }
    }
    ""
}

private func addedSemanticChanges(nodes: Array<SemanticsNode>): Array<SemanticsChange> {
    Array<SemanticsChange>(nodes.size, {index => SemanticsChange.Added(nodes[index].id)})
}

/** Commits semantics and reconciles its generational Element ownership. */
protected func commitSemanticsForStore(context: UiContext, store: StateStore): Unit {
    context.commitSemantics(arena: Some(store.elementArena))
}
