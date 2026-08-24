package cui.core

import sdl.Rect

/*
 * Persistent output of one ordinary declarative body. Unlike RetainedRecord this record does not
 * participate in layout or paint: its purpose is to preserve the exact child array while the body
 * has no dirty State dependency. Containers remain ordinary widgets, so automatic composition
 * cannot change flex, spacing, event, or modifier semantics.
 */
private let AUTOMATIC_RENDER_PROMOTION_WEIGHT: Int64 = 16
private let AUTOMATIC_RENDER_PROMOTION_BRANCHING: Int64 = 8

struct AutomaticSubtreeShape {
    let weight: Int64
    let maxBranching: Int64

    init(weight: Int64, maxBranching: Int64) {
        this.weight = weight
        this.maxBranching = maxBranching
    }
}

class AutomaticCompositionRecord {
    var children: Array<Widget>
    var focusableIds: Array<String>
    var frameSubscribers: Array<FrameSubscriber>
    let mountScope: StateMountScope
    var usesRenderNodes: Bool
    var subtreeWeight: Int64
    var subtreeMaxBranching: Int64
    var buildHits: UInt64 = UInt64(0)

    init(
        children: Array<Widget>,
        mountScope: StateMountScope,
        usesRenderNodes: Bool,
        subtreeWeight: Int64,
        subtreeMaxBranching: Int64,
        focusableIds: Array<String>,
        frameSubscribers: Array<FrameSubscriber>
    ) {
        this.children = children
        this.mountScope = mountScope
        this.usesRenderNodes = usesRenderNodes
        this.subtreeWeight = subtreeWeight
        this.subtreeMaxBranching = subtreeMaxBranching
        this.focusableIds = focusableIds
        this.frameSubscribers = frameSubscribers
        refreshDamageSink()
    }

    func replace(
        children: Array<Widget>,
        focusableIds: Array<String>,
        frameSubscribers: Array<FrameSubscriber>,
        usesRenderNodes: Bool,
        subtreeWeight: Int64,
        subtreeMaxBranching: Int64
    ): Unit {
        this.children = children
        this.focusableIds = focusableIds
        this.frameSubscribers = frameSubscribers
        this.usesRenderNodes = usesRenderNodes
        this.subtreeWeight = subtreeWeight
        this.subtreeMaxBranching = subtreeMaxBranching
        refreshDamageSink()
    }

    func closeRenderNodes(): Unit {
        mountScope.clearAutomaticDamageSink()
        mountScope.clearAutomaticPhaseSink()
        closeAutomaticRenderChildren(children)
    }

    func noteBuildInvalidationDamage(): Unit {
        noteAutomaticRenderDamage(children)
    }

    func renderStats(): AutomaticRenderStats {
        automaticRenderStats(children)
    }

    private func refreshDamageSink(): Unit {
        if (usesRenderNodes) {
            mountScope.attachAutomaticDamageSink({=> noteBuildInvalidationDamage()})
            mountScope.attachAutomaticPhaseSink(
                AutomaticRenderPhaseSink(
                    {=> invalidateAutomaticRenderMeasure(children)},
                    {=> invalidateAutomaticRenderLayout(children)},
                    {=> invalidateAutomaticRenderPaint(children)}
                )
            )
        } else {
            mountScope.clearAutomaticDamageSink()
            mountScope.clearAutomaticPhaseSink()
        }
    }
}

/* An automatic output replacement becomes visible only after the complete root build commits. */
class PendingAutomaticCompositionReplacement {
    let record: AutomaticCompositionRecord
    let reconciliation: AutomaticRenderReconciliation
    let children: Array<Widget>
    let focusableIds: Array<String>
    let frameSubscribers: Array<FrameSubscriber>
    let usesRenderNodes: Bool
    let subtreeWeight: Int64
    let subtreeMaxBranching: Int64

    init(
        record: AutomaticCompositionRecord,
        reconciliation: AutomaticRenderReconciliation,
        children: Array<Widget>,
        focusableIds: Array<String>,
        frameSubscribers: Array<FrameSubscriber>,
        usesRenderNodes: Bool,
        subtreeWeight: Int64,
        subtreeMaxBranching: Int64
    ) {
        this.record = record
        this.reconciliation = reconciliation
        this.children = children
        this.focusableIds = focusableIds
        this.frameSubscribers = frameSubscribers
        this.usesRenderNodes = usesRenderNodes
        this.subtreeWeight = subtreeWeight
        this.subtreeMaxBranching = subtreeMaxBranching
    }

    func commit(): Unit {
        reconciliation.commit()
        record.replace(children, focusableIds, frameSubscribers, usesRenderNodes, subtreeWeight, subtreeMaxBranching)
    }
}

/* Automatic body caching is a StateStore detail; public builders need no performance switches. */
extend StateStore {
    func composeChildren(kind: String, body: () -> Array<Widget>): Array<Widget> {
        if (!automaticCompositionEnabled) {
            return body()
        }
        let identity = nextAutomaticScopeIdentity(kind)
        let path = scopedKey(identity)
        visitAutomaticChild(this, path, identity)
        let parentForcesChildren = automaticDescendantsForced(this)

        match (automaticEntries.get(path)) {
            case Some(record) where !forceFullRetainedExecution && !parentForcesChildren &&
                !record.mountScope.buildDirty && record.mountScope.retainedKeys.isEmpty() &&
                record.mountScope.effectKeys.isEmpty() =>
                replayAutomaticComposition(record)
                currentMountBuild(this).absorbAutomaticSubtree(record.subtreeWeight, record.subtreeMaxBranching)
                record.buildHits += UInt64(1)
                record.children
            case previous => rebuildAutomaticComposition(path, identity, kind, previous, parentForcesChildren, body)
        }
    }

    private func rebuildAutomaticComposition(
        path: String,
        identity: String,
        kind: String,
        previous: ?AutomaticCompositionRecord,
        parentForcesChildren: Bool,
        body: () -> Array<Widget>
    ): Array<Widget> {
        let mountScope = match (previous) {
            case Some(existing) => existing.mountScope
            case None => StateMountScope(currentMountScope(this), automaticDiagnosticScopedKey(identity))
        }
        let forceChildren = parentForcesChildren || previous.isNone() || mountScope.buildSelfDirty
        pushScope(identity)
        beginAutomaticMount(this, mountScope, forceChildren)
        let subscriberStart = frameSubscriberCount(this)
        var subtreeShape = AutomaticSubtreeShape(1, 0)
        let rawChildren = try {
            body()
        } finally {
            subtreeShape = endAutomaticMount(this)
            popScope()
        }
        let subscribers = frameSubscribersFrom(this, subscriberStart)
        let usesRenderNodes = shouldUseAutomaticRenderNodes(kind, rawChildren.size, subtreeShape, previous)
        let reconciliation = automaticRenderReconciliation(this, mountScope, previous, rawChildren, usesRenderNodes)
        let children = reconciliation.children
        let focusables = collectFocusableIds(children)
        match (previous) {
            case Some(existing) => stageAutomaticReplacement(this,
                PendingAutomaticCompositionReplacement(existing, reconciliation, children, focusables, subscribers,
                    usesRenderNodes, subtreeShape.weight, subtreeShape.maxBranching))
            case None =>
                let created = AutomaticCompositionRecord(children, mountScope, usesRenderNodes, subtreeShape.weight,
                    subtreeShape.maxBranching, focusables, subscribers)
                let _ = automaticEntries.add(path, created) // cjcheck-ignore: ignore-result # path was checked absent
                automaticAddedDuringBuild.add(path)
        }
        children
    }

    private func replayAutomaticComposition(record: AutomaticCompositionRecord): Unit {
        replayFrameSubscribers(this, record.frameSubscribers)
        for (id in record.focusableIds) {
            registerFocusable(id)
        }
    }

    private func nextAutomaticScopeIdentity(kind: String): String {
        let base = scopedKey(kind)
        let seen = match (automaticScopeCounts.get(base)) {
            case Some(count) => count
            case None => 0
        }
        let _ = automaticScopeCounts.add(base, seen + 1) // cjcheck-ignore: ignore-result # displaced count was read above
        "@${kind}[${seen + 1}]"
    }

    private func automaticDiagnosticScopedKey(key: String): String {
        let result = StringBuilder()
        for (scope in scopes) {
            if (scope.startsWith("@")) {
                result.append(scope)
                result.append(" / ")
            }
        }
        result.append(key)
        result.toString()
    }
}

private func automaticRenderReconciliation(
    store: StateStore,
    scope: StateMountScope,
    previous: ?AutomaticCompositionRecord,
    rawChildren: Array<Widget>,
    usesRenderNodes: Bool
): AutomaticRenderReconciliation {
    if (!usesRenderNodes) {
        let removed: Array<AutomaticRenderNode> = match (previous) {
            case Some(record) => automaticRenderNodes(record.children)
            case None => []
        }
        return AutomaticRenderReconciliation(rawChildren, [], removed)
    }
    let invalidateComposition = {
        =>
            scope.markBuildDirty()
            markFullRetainedDamage(store)
    }
    let invalidateDamage = {rect: Rect => markRetainedDamage(store, rect)}
    match (previous) {
        case Some(record) => reconcileAutomaticChildren(record.children, rawChildren, store.automaticPaintBudget,
            invalidateComposition, invalidateDamage)
        case None => AutomaticRenderReconciliation(
            wrapAutomaticChildren(rawChildren, store.automaticPaintBudget, invalidateComposition, invalidateDamage), [],
            [])
    }
}

private func shouldUseAutomaticRenderNodes(
    kind: String,
    childCount: Int64,
    shape: AutomaticSubtreeShape,
    previous: ?AutomaticCompositionRecord
): Bool {
    if (kind == "Root") {
        return true
    }
    if (childCount != 1) {
        return false
    }
    match (previous) {
        case Some(record) where record.usesRenderNodes => true
        case _ => shape.maxBranching >= AUTOMATIC_RENDER_PROMOTION_BRANCHING || (shape.weight >=
            AUTOMATIC_RENDER_PROMOTION_WEIGHT * 2 && shape.maxBranching >= 2)
    }
}

func visitAutomaticChild(store: StateStore, path: String, key: String): Unit {
    currentMountBuild(store).visitAutomatic(path, key)
}

func automaticDescendantsForced(store: StateStore): Bool {
    currentMountBuild(store).forceAutomaticDescendants
}

func beginAutomaticMount(store: StateStore, scope: StateMountScope, forceChildren: Bool): Unit {
    let build = StateMountBuild(scope, collectStateReads: true, invalidate: {=> scope.markBuildDirty()},
        forceAutomaticDescendants: forceChildren, automaticSubtreeWeight: 1)
    store.mountBuilds.add(build)
    store.activeMountBuilds.add(build)
    beginStateReadCollection()
}

func endAutomaticMount(store: StateStore): AutomaticSubtreeShape {
    if (store.activeMountBuilds.size <= 1) {
        throw IllegalStateException("Unbalanced automatic composition state scope")
    }
    let completed = currentMountBuild(store)
    endNestedMount(store, "automatic composition")
    currentMountBuild(store).absorbAutomaticSubtree(completed.automaticSubtreeWeight, completed.automaticMaxBranching)
    AutomaticSubtreeShape(completed.automaticSubtreeWeight, completed.automaticMaxBranching)
}

func stageAutomaticReplacement(
    store: StateStore,
    replacement: PendingAutomaticCompositionReplacement
): Unit {
    store.automaticReplacements.add(replacement)
}

func removeAutomaticMount(store: StateStore, path: String): Unit {
    match (store.automaticEntries.get(path)) {
        case Some(record) =>
            record.closeRenderNodes()
            for (statePath in record.mountScope.stateKeys) {
                let _ = store.entries.remove(statePath) // cjcheck-ignore: ignore-result # state belongs to the automatic subtree
            }
            for (childPath in record.mountScope.retainedKeys) {
                removeRetainedMount(store, childPath)
            }
            for (childPath in record.mountScope.automaticKeys) {
                removeAutomaticMount(store, childPath)
            }
            stageLifecycleEffectsInScope(store, record.mountScope)
            record.mountScope.stateKeys.clear()
            record.mountScope.retainedKeys.clear()
            record.mountScope.automaticKeys.clear()
            record.mountScope.effectKeys.clear()
            record.mountScope.closeBuildDependencies()
        case None => ()
    }
    let _ = store.automaticEntries.remove(path) // cjcheck-ignore: ignore-result # missing records are harmless during cleanup
}

/* Hosts opt into the automatic graph; direct StateStore transaction tests keep raw build semantics. */
protected func enableAutomaticComposition(store: StateStore): Unit {
    store.automaticCompositionEnabled = true
}
