package cui.core

import std.collection.ArrayList
import std.sort.sort
import sdl.Rect

/** One stable, immutable diagnostic row for the root or a retained execution scope. */
public struct RetainedScopeDiagnostics {
    public let identity: String
    public let path: String
    public let depth: Int64
    public let bounds: Rect
    public let stateCount: Int64
    public let effectCount: Int64
    public let retainedChildCount: Int64
    public let buildDirty: Bool
    public let measureDirty: Bool
    public let layoutDirty: Bool
    public let paintDirty: Bool
    public let lastInvalidationReason: String
    public let stats: RetainedSubtreeStats

    init(
        identity: String,
        path: String,
        depth: Int64,
        bounds: Rect,
        stateCount: Int64,
        effectCount: Int64,
        retainedChildCount: Int64,
        buildDirty: Bool,
        measureDirty: Bool,
        layoutDirty: Bool,
        paintDirty: Bool,
        lastInvalidationReason: String,
        stats: RetainedSubtreeStats
    ) {
        this.identity = identity
        this.path = path
        this.depth = depth
        this.bounds = bounds
        this.stateCount = stateCount
        this.effectCount = effectCount
        this.retainedChildCount = retainedChildCount
        this.buildDirty = buildDirty
        this.measureDirty = measureDirty
        this.layoutDirty = layoutDirty
        this.paintDirty = paintDirty
        this.lastInvalidationReason = lastInvalidationReason
        this.stats = stats
    }
}

/** One immutable diagnostic row for a framework-managed declarative body. */
public struct AutomaticScopeDiagnostics {
    public let identity: String
    public let path: String
    public let depth: Int64
    public let stateCount: Int64
    public let effectCount: Int64
    public let retainedChildCount: Int64
    public let automaticChildCount: Int64
    public let buildDirty: Bool
    public let selfDirty: Bool
    public let descendantDirty: Bool
    public let buildDependencyCount: Int64
    public let buildInvalidations: UInt64
    public let buildHits: UInt64
    public let renderNodeCount: Int64
    public let layoutHits: UInt64
    public let paintHits: UInt64
    public let paintRecordAttempts: UInt64
    public let paintDynamicBypasses: UInt64
    public let paintRejectedCandidates: UInt64
    public let paintBudgetEvictions: UInt64
    public let paintCommandCount: Int64
    public let paintEstimatedBytes: UInt64
    public let paintBypassRemaining: Int64
    public let sceneRevision: UInt64
    public let lastInvalidationReason: String

    init(identity: String, path: String, scope: StateMountScope, buildHits: UInt64, render: AutomaticRenderStats) {
        this.identity = identity
        this.path = path
        this.depth = scope.depth
        this.stateCount = scope.stateKeyCount()
        this.effectCount = scope.effectKeyCount()
        this.retainedChildCount = scope.retainedKeyCount()
        this.automaticChildCount = scope.automaticKeyCount()
        this.buildDirty = scope.buildDirty
        this.selfDirty = scope.buildSelfDirty
        this.descendantDirty = scope.buildDescendantDirty
        this.buildDependencyCount = scope.buildDependencyCount()
        this.buildInvalidations = scope.buildInvalidations
        this.buildHits = buildHits
        this.renderNodeCount = render.nodeCount
        this.layoutHits = render.layoutHits
        this.paintHits = render.paintHits
        this.paintRecordAttempts = render.paintRecordAttempts
        this.paintDynamicBypasses = render.paintDynamicBypasses
        this.paintRejectedCandidates = render.paintRejectedCandidates
        this.paintBudgetEvictions = render.paintBudgetEvictions
        this.paintCommandCount = render.paintCommandCount
        this.paintEstimatedBytes = render.paintEstimatedBytes
        this.paintBypassRemaining = render.paintBypassRemaining
        this.sceneRevision = render.sceneRevision
        this.lastInvalidationReason = scope.buildDirtyReason
    }
}

/** Deterministic retained execution-graph snapshot for tests, profilers, and bug reports. */
public class RetainedGraphDiagnostics {
    public let scopes: Array<RetainedScopeDiagnostics>
    public let automaticScopes: Array<AutomaticScopeDiagnostics>
    public let activeEffectCount: Int64
    public let failedEffectCleanupCount: Int64
    public let fullDamagePending: Bool
    public let pendingDamage: ?Rect

    init(
        scopes: Array<RetainedScopeDiagnostics>,
        automaticScopes: Array<AutomaticScopeDiagnostics>,
        activeEffectCount: Int64,
        failedEffectCleanupCount: Int64,
        fullDamagePending: Bool,
        pendingDamage: ?Rect
    ) {
        this.scopes = scopes
        this.automaticScopes = automaticScopes
        this.activeEffectCount = activeEffectCount
        this.failedEffectCleanupCount = failedEffectCleanupCount
        this.fullDamagePending = fullDamagePending
        this.pendingDamage = pendingDamage
    }

    /** Renders a stable multiline summary suitable for logs and golden diagnostics. */
    public func describe(): String {
        let result = StringBuilder()
        result.append("retained-scopes=")
        result.append(scopes.size)
        result.append(" automatic-scopes=")
        result.append(automaticScopes.size)
        result.append(" active-effects=")
        result.append(activeEffectCount)
        result.append(" failed-effect-cleanups=")
        result.append(failedEffectCleanupCount)
        result.append(" damage=")
        appendDamage(result, fullDamagePending, pendingDamage)
        for (scope in scopes) {
            appendScopeDiagnostics(result, scope)
        }
        for (scope in automaticScopes) {
            appendAutomaticScopeDiagnostics(result, scope)
        }
        result.toString()
    }
}

private func appendAutomaticScopeDiagnostics(result: StringBuilder, scope: AutomaticScopeDiagnostics): Unit {
    result.append("\nauto ")
    result.append(scope.path)
    result.append(" depth=")
    result.append(scope.depth)
    result.append(" states=")
    result.append(scope.stateCount)
    result.append(" children=")
    result.append(scope.automaticChildCount)
    result.append(" deps=")
    result.append(scope.buildDependencyCount)
    result.append(" hits=")
    result.append(scope.buildHits)
    if (scope.renderNodeCount > 0) {
        result.append(" render=")
        result.append(scope.renderNodeCount)
        result.append(" layout-hits=")
        result.append(scope.layoutHits)
        result.append(" paint-hits=")
        result.append(scope.paintHits)
        result.append(" commands=")
        result.append(scope.paintCommandCount)
        result.append("/")
        result.append(scope.paintEstimatedBytes)
        result.append(" probe=")
        result.append(scope.paintRecordAttempts)
        result.append(" bypass=")
        result.append(scope.paintDynamicBypasses)
        result.append("/")
        result.append(scope.paintRejectedCandidates)
        result.append(" evict=")
        result.append(scope.paintBudgetEvictions)
        result.append(" next=")
        result.append(scope.paintBypassRemaining)
    }
    result.append(" dirty=")
    if (scope.buildDirty) {
        if (scope.selfDirty) {
            result.append("self")
        } else {
            result.append("descendant")
        }
    } else {
        result.append("clean")
    }
    if (!scope.lastInvalidationReason.isEmpty()) {
        result.append(" reason=")
        result.append(scope.lastInvalidationReason)
    }
}

private func appendScopeDiagnostics(result: StringBuilder, scope: RetainedScopeDiagnostics): Unit {
    result.append("\n")
    result.append(scope.path)
    result.append(" depth=")
    result.append(scope.depth)
    result.append(" states=")
    result.append(scope.stateCount)
    result.append(" effects=")
    result.append(scope.effectCount)
    result.append(" children=")
    result.append(scope.retainedChildCount)
    result.append(" dirty=")
    result.append(dirtyPhases(scope))
    appendScopeCounters(result, scope)
    if (!scope.lastInvalidationReason.isEmpty()) {
        result.append(" reason=")
        result.append(scope.lastInvalidationReason)
    }
}

private func appendScopeCounters(result: StringBuilder, scope: RetainedScopeDiagnostics): Unit {
    result.append(" deps=")
    result.append(scope.stats.buildDependencyCount)
    result.append("/")
    result.append(scope.stats.measureDependencyCount)
    result.append("/")
    result.append(scope.stats.layoutDependencyCount)
    result.append("/")
    result.append(scope.stats.paintDependencyCount)
    result.append(" hits=")
    result.append(scope.stats.buildHits)
    result.append("/")
    result.append(scope.stats.layoutHits)
    result.append("/")
    result.append(scope.stats.paintHits)
    result.append(" commands=")
    result.append(scope.stats.paintCommandCount)
    result.append("/")
    result.append(scope.stats.paintEstimatedBytes)
    result.append(" bypass=")
    result.append(scope.stats.paintBypassFrames)
    result.append("/")
    result.append(scope.stats.paintDynamicBypasses)
    result.append(" probe=")
    result.append(scope.stats.paintRecordAttempts)
    result.append(" next=")
    result.append(scope.stats.paintBypassRemaining)
}

/*
 * Reads only committed retained state. Throws `IllegalStateException` while a build transaction is
 * active, so diagnostics can never expose a partially staged graph.
 */
protected func retainedGraphDiagnostics(store: StateStore): RetainedGraphDiagnostics {
    if (!store.activeMountBuilds.isEmpty()) {
        throw IllegalStateException("Retained diagnostics are available only after a build commits")
    }
    let scopes = ArrayList<RetainedScopeDiagnostics>()
    scopes.add(rootScopeDiagnostics(store))
    let retained = retainedScopeDiagnostics(store)
    sort<RetainedScopeDiagnostics, String>(retained, key: {scope => scope.identity}, stable: true)
    sort<RetainedScopeDiagnostics, String>(retained, key: {scope => scope.path}, stable: true)
    for (scope in retained) {
        scopes.add(scope)
    }
    RetainedGraphDiagnostics(scopes.toArray(), automaticScopeDiagnostics(store), store.lifecycleEffects.size,
        store.failedLifecycleCleanups.size, store.fullRetainedDamagePending, store.pendingRetainedDamage)
}

private func automaticScopeDiagnostics(store: StateStore): Array<AutomaticScopeDiagnostics> {
    let automatic = ArrayList<AutomaticScopeDiagnostics>()
    for ((identity, record) in store.automaticEntries) {
        automatic.add(
            AutomaticScopeDiagnostics(identity, record.mountScope.diagnosticPath, record.mountScope, record.buildHits,
                record.renderStats()))
    }
    sort<AutomaticScopeDiagnostics, String>(automatic, key: {scope => scope.identity}, stable: true)
    sort<AutomaticScopeDiagnostics, String>(automatic, key: {scope => scope.path}, stable: true)
    automatic.toArray()
}

private func appendDamage(result: StringBuilder, full: Bool, pending: ?Rect): Unit {
    if (full) {
        result.append("full")
        return
    }
    match (pending) {
        case Some(rect) =>
            result.append(rect.x)
            result.append(",")
            result.append(rect.y)
            result.append(",")
            result.append(rect.w)
            result.append("x")
            result.append(rect.h)
        case None => result.append("none")
    }
}

private func rootScopeDiagnostics(store: StateStore): RetainedScopeDiagnostics {
    let root = store.rootMountScope
    let clean = false
    RetainedScopeDiagnostics(
        "<root>",
        root.diagnosticPath,
        root.depth,
        Rect.zero(),
        root.stateKeyCount(),
        root.effectKeyCount(),
        root.retainedKeyCount(),
        clean,
        clean,
        clean,
        clean,
        root.buildDirtyReason,
        RetainedSubtreeStats(
            UInt64(0),
            UInt64(0),
            UInt64(0),
            root.buildDependencyCount(),
            root.buildInvalidations,
            frameSubscriberCount(store),
            0,
            0,
            0
        )
    )
}

private func retainedScopeDiagnostics(store: StateStore): ArrayList<RetainedScopeDiagnostics> {
    let retained = ArrayList<RetainedScopeDiagnostics>()
    for ((identity, record) in store.retainedEntries) {
        let scope = record.mountScope
        retained.add(
            RetainedScopeDiagnostics(
                identity,
                scope.diagnosticPath,
                retainedDiagnosticDepth(scope),
                record.diagnosticBounds(),
                scope.stateKeyCount(),
                scope.effectKeyCount(),
                scope.retainedKeyCount(),
                scope.buildDirty,
                record.diagnosticMeasureDirty(),
                record.diagnosticLayoutDirty(),
                record.diagnosticPaintDirty(),
                if (scope.buildDirty) {
                    scope.buildDirtyReason
                } else {
                    record.diagnosticInvalidationReason()
                },
                record.stats()
            )
        )
    }
    retained
}

private func retainedDiagnosticDepth(scope: StateMountScope): Int64 {
    var depth: Int64 = 1
    var current = scope.parent
    while (let Some(parent) <- current) {
        if (parent.ownerRecord.isSome()) {
            depth += 1
        }
        current = parent.parent
    }
    depth
}

private func dirtyPhases(scope: RetainedScopeDiagnostics): String {
    let result = StringBuilder()
    appendDirtyPhase(result, scope.buildDirty, "build")
    appendDirtyPhase(result, scope.measureDirty, "measure")
    appendDirtyPhase(result, scope.layoutDirty, "layout")
    appendDirtyPhase(result, scope.paintDirty, "paint")
    if (result.size == 0) {
        "clean"
    } else {
        result.toString()
    }
}

private func appendDirtyPhase(result: StringBuilder, dirty: Bool, phase: String): Unit {
    if (!dirty) {
        return
    }
    if (result.size > 0) {
        result.append(",")
    }
    result.append(phase)
}
