package cui.core

import std.collection.{ArrayList, HashMap, HashSet}

private let PHASE_DEPENDENCY_LINEAR_LIMIT: Int64 = 8

/* Transactional dependency set for one retained execution phase. */
class PhaseStateDependencies {
    private let invalidate: () -> Unit
    var dependencies: ?ArrayList<ObservableReadDependency> = None
    var dependenciesBySource: ?HashMap<UInt64, ObservableReadDependency> = None
    var pending: ?ArrayList<ObservableReadDependency> = None
    var pendingSources: ?HashSet<UInt64> = None
    private var collecting = false
    private var invalidatedDuringCollection = false
    private var committedPrefixActive = true
    private var derivedReadDepth: Int64 = 0

    init(invalidate: () -> Unit) {
        this.invalidate = invalidate
    }

    prop size: Int64 {
        get() {
            dependencyCount()
        }
    }

    prop collectionWasInvalidated: Bool {
        get() {
            invalidatedDuringCollection
        }
    }

    func beginCollection(): Unit {
        match (pending) {
            case Some(values) => values.clear()
            case None => ()
        }
        match (pendingSources) {
            case Some(index) => index.clear()
            case None => ()
        }
        collecting = true
        invalidatedDuringCollection = false
        committedPrefixActive = true
    }

    func readState<T>(source: State<T>): Unit {
        if (derivedReadDepth > 0) {
            return
        }
        let identity = source.dependencyIdentity()
        if (reuseDependency(identity)) {
            return
        }
        let dependency = TypedStateReadDependency<T>(source, {=> handleInvalidation()})
        ensurePending().add(dependency)
    }

    func beginDerivedRead<T>(source: DerivedState<T>): Unit {
        let shouldRead = derivedReadDepth == 0
        derivedReadDepth += 1
        if (shouldRead) {
            try {
                readDerived(source)
            } catch (error: Exception) {
                derivedReadDepth = leaveDerivedReadDepth(derivedReadDepth, "phase")
                throw error
            }
        }
    }

    func endDerivedRead(): Unit {
        derivedReadDepth = leaveDerivedReadDepth(derivedReadDepth, "phase")
    }

    private func readDerived<T>(source: DerivedState<T>): Unit {
        let identity = source.dependencyIdentity()
        if (reuseDependency(identity)) {
            return
        }
        let dependency = TypedDerivedReadDependency<T>(source, {=> handleInvalidation()})
        ensurePending().add(dependency)
    }

    private func reuseDependency(identity: UInt64): Bool {
        if (committedPrefixActive) {
            // Prefix reuse appends to the pending frontier and can permanently switch this
            // collection to reconciliation. Keep that state transition out of a short-circuit.
            if (reuseCommittedPrefix(identity)) {
                return true
            }
        }
        if (!markPendingSource(identity)) {
            return true
        }
        match (committedDependency(identity)) {
            case Some(dependency) =>
                ensurePending().add(dependency)
                true
            case None => false
        }
    }

    func commit(): Unit {
        if (dependencies.isNone() && pending.isNone()) {
            collecting = false
            return
        }
        let width = pendingCount()
        if (committedTraceUnchanged(width)) {
            match (pending) {
                case Some(values) => values.clear()
                case None => ()
            }
            pendingSources = None
            collecting = false
            return
        }
        closeRemovedDependencies(width)
        if (width == 0) {
            dependencies = None
            dependenciesBySource = None
            pending = None
            pendingSources = None
        } else {
            replaceCommittedDependencies(width)
            match (pending) {
                case Some(values) => values.clear()
                case None => ()
            }
            if (width <= PHASE_DEPENDENCY_LINEAR_LIMIT) {
                pendingSources = None
            } else {
                match (pendingSources) {
                    case Some(index) => index.clear()
                    case None => ()
                }
            }
        }
        collecting = false
    }

    func cancel(): Unit {
        match (pending) {
            case Some(values) => for (dependency in values) {
                if (committedDependency(dependency.sourceIdentity).isNone()) {
                    dependency.close()
                }
            }
            case None => ()
        }
        let width = dependencyCount()
        if (width == 0) {
            pending = None
            pendingSources = None
        } else {
            match (pending) {
                case Some(values) => values.clear()
                case None => ()
            }
            if (width <= PHASE_DEPENDENCY_LINEAR_LIMIT) {
                pendingSources = None
            } else {
                match (pendingSources) {
                    case Some(index) => index.clear()
                    case None => ()
                }
            }
        }
        collecting = false
    }

    func close(): Unit {
        cancel()
        match (dependencies) {
            case Some(values) => for (dependency in values) {
                dependency.close()
            }
            case None => ()
        }
        dependencies = None
        dependenciesBySource = None
        pending = None
        pendingSources = None
    }

    private func handleInvalidation(): Unit {
        if (collecting) {
            invalidatedDuringCollection = true
        }
        invalidate()
    }

    private func dependencyCount(): Int64 {
        match (dependencies) {
            case Some(values) => values.size
            case None => 0
        }
    }

    private func pendingCount(): Int64 {
        match (pending) {
            case Some(values) => values.size
            case None => 0
        }
    }

    private func ensurePending(): ArrayList<ObservableReadDependency> {
        match (pending) {
            case Some(values) => values
            case None =>
                let values = ArrayList<ObservableReadDependency>()
                pending = Some(values)
                values
        }
    }

    private func committedDependency(identity: UInt64): ?ObservableReadDependency {
        match (dependenciesBySource) {
            case Some(index) => index.get(identity)
            case None => match (dependencies) {
                case Some(values) =>
                    for (dependency in values) {
                        if (dependency.sourceIdentity == identity) {
                            return Some(dependency)
                        }
                    }
                    None
                case None => None
            }
        }
    }

    /*
     * A retained execution phase normally observes the same ordered trace on every cache miss.
     * Zip that trace with the committed frontier before paying for two hash probes per read. A
     * mismatch is monotone for the rest of the transaction and falls back to set reconciliation.
     */
    private func reuseCommittedPrefix(identity: UInt64): Bool {
        match (dependencies) {
            case Some(committed) =>
                let index = pendingCount()
                if (index < committed.size) {
                    let candidate = committed[index]
                    if (candidate.sourceIdentity == identity) {
                        ensurePending().add(candidate)
                        return true
                    }
                }
            case None => ()
        }
        committedPrefixActive = false
        false
    }

    private func committedTraceUnchanged(width: Int64): Bool {
        let committed = match (dependencies) {
            case Some(values) => values
            case None => return false
        }
        if (width != committed.size) {
            return false
        }
        if (committedPrefixActive) {
            return true
        }
        let staged = match (pending) {
            case Some(values) => values
            case None => return false
        }
        for (index in 0..width) {
            if (staged[index].sourceIdentity != committed[index].sourceIdentity) {
                return false
            }
        }
        true
    }

    private func closeRemovedDependencies(width: Int64): Unit {
        match (dependencies) {
            case Some(committed) =>
                if (committedPrefixActive) {
                    for (index in width..committed.size) {
                        committed[index].close()
                    }
                    return
                }
                ensurePendingSourceIndex(width)
                for (previous in committed) {
                    if (!containsPendingSource(previous.sourceIdentity)) {
                        previous.close()
                    }
                }
            case None => ()
        }
    }

    private func ensurePendingSourceIndex(width: Int64): Unit {
        if (width <= PHASE_DEPENDENCY_LINEAR_LIMIT || pendingSources.isSome()) {
            return
        }
        let index = HashSet<UInt64>(max(Int64(16), width))
        match (pending) {
            case Some(values) => for (dependency in values) {
                let _ = index.add(dependency.sourceIdentity) // cjcheck-ignore: ignore-result # pending is a unique canonical frontier
            }
            case None => ()
        }
        pendingSources = Some(index)
    }

    private func markPendingSource(identity: UInt64): Bool {
        match (pendingSources) {
            case Some(index) => index.add(identity)
            case None =>
                match (pending) {
                    case Some(values) => for (dependency in values) {
                        if (dependency.sourceIdentity == identity) {
                            return false
                        }
                    }
                    case None => ()
                }
                if (pendingCount() < PHASE_DEPENDENCY_LINEAR_LIMIT) {
                    return true
                }
                let index = HashSet<UInt64>(max(Int64(16), dependencyCount()))
                match (pending) {
                    case Some(values) => for (dependency in values) {
                        let _ = index.add(dependency.sourceIdentity) // cjcheck-ignore: ignore-result # pending is a unique canonical frontier
                    }
                    case None => ()
                }
                let added = index.add(identity)
                pendingSources = Some(index)
                added
        }
    }

    private func containsPendingSource(identity: UInt64): Bool {
        match (pendingSources) {
            case Some(index) => index.contains(identity)
            case None => match (pending) {
                case Some(values) =>
                    for (dependency in values) {
                        if (dependency.sourceIdentity == identity) {
                            return true
                        }
                    }
                    false
                case None => false
            }
        }
    }

    private func replaceCommittedDependencies(width: Int64): Unit {
        let committed = match (dependencies) {
            case Some(values) =>
                values.clear()
                values
            case None => ArrayList<ObservableReadDependency>()
        }
        match (pending) {
            case Some(values) => for (dependency in values) {
                committed.add(dependency)
            }
            case None => ()
        }
        dependencies = Some(committed)
        if (width <= PHASE_DEPENDENCY_LINEAR_LIMIT) {
            dependenciesBySource = None
            return
        }
        let index = match (dependenciesBySource) {
            case Some(current) =>
                current.clear()
                current
            case None => HashMap<UInt64, ObservableReadDependency>(width)
        }
        for (dependency in committed) {
            let _ = index.add(dependency.sourceIdentity, dependency) // cjcheck-ignore: ignore-result # committed is a unique canonical frontier
        }
        dependenciesBySource = Some(index)
    }
}

func collectPhaseStateReads<T>(dependencies: PhaseStateDependencies, body: () -> T): T {
    dependencies.beginCollection()
    beginStateReadCollection(StateReadCollector.Phase(dependencies))
    try {
        try {
            let result = body()
            dependencies.commit()
            return result
        } catch (error: Exception) {
            dependencies.cancel()
            throw error
        }
    } finally {
        endStateReadCollection()
    }
}

func requiredPhaseStateDependencies(value: ?PhaseStateDependencies, phase: String): PhaseStateDependencies {
    match (value) {
        case Some(dependencies) => dependencies
        case None => throw IllegalStateException("${phase} dependencies were not initialized")
    }
}
