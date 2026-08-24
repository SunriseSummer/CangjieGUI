package cui.core

import std.collection.ArrayList

/* Transactional dependency set for one retained execution phase. */
class PhaseStateDependencies {
    private let invalidate: () -> Unit
    private let dependencies = ArrayList<StateReadDependency>()
    private let pending = ArrayList<StateReadDependency>()
    private let pendingSources = ArrayList<Object>()
    private let created = ArrayList<StateReadDependency>()
    private var collecting = false
    private var invalidatedDuringCollection = false

    init(invalidate: () -> Unit) {
        this.invalidate = invalidate
    }

    prop size: Int64 {
        get() {
            dependencies.size
        }
    }

    prop collectionWasInvalidated: Bool {
        get() {
            invalidatedDuringCollection
        }
    }

    func beginCollection(): Unit {
        pending.clear()
        pendingSources.clear()
        created.clear()
        collecting = true
        invalidatedDuringCollection = false
    }

    func readState<T>(source: State<T>): Unit {
        let sourceObject = stateObject(source)
        for (seen in pendingSources) {
            if (refEq(seen, sourceObject)) {
                return
            }
        }
        pendingSources.add(sourceObject)
        for (dependency in dependencies) {
            if (dependency.matches(sourceObject)) {
                pending.add(dependency)
                return
            }
        }
        let dependency = TypedStateReadDependency<T>(source, {=> handleInvalidation()})
        pending.add(dependency)
        created.add(dependency)
    }

    func commit(): Unit {
        for (previous in dependencies) {
            if (!pendingContains(previous)) {
                previous.close()
            }
        }
        dependencies.clear()
        for (dependency in pending) {
            dependencies.add(dependency)
        }
        created.clear()
        pending.clear()
        pendingSources.clear()
        collecting = false
    }

    func cancel(): Unit {
        for (dependency in created) {
            dependency.close()
        }
        created.clear()
        pending.clear()
        pendingSources.clear()
        collecting = false
    }

    func close(): Unit {
        cancel()
        for (dependency in dependencies) {
            dependency.close()
        }
        dependencies.clear()
    }

    private func pendingContains(candidate: StateReadDependency): Bool {
        for (dependency in pending) {
            if (sameStateReadDependency(dependency, candidate)) {
                return true
            }
        }
        false
    }

    private func handleInvalidation(): Unit {
        if (collecting) {
            invalidatedDuringCollection = true
        }
        invalidate()
    }
}

private let activePhaseStateReads = ThreadLocal<PhaseStateDependencies>()

func currentPhaseStateReads(): ?PhaseStateDependencies {
    activePhaseStateReads.get()
}

func collectPhaseStateReads<T>(dependencies: PhaseStateDependencies, body: () -> T): T {
    let previous = activePhaseStateReads.get()
    dependencies.beginCollection()
    beginStateReadCollection()
    activePhaseStateReads.set(Some(dependencies))
    try {
        try {
            let result = body()
            dependencies.commit()
            result
        } catch (error: Exception) {
            dependencies.cancel()
            throw error
        }
    } finally {
        activePhaseStateReads.set(previous)
        endStateReadCollection()
    }
}

func requiredPhaseStateDependencies(value: ?PhaseStateDependencies, phase: String): PhaseStateDependencies {
    match (value) {
        case Some(dependencies) => dependencies
        case None => throw IllegalStateException("${phase} dependencies were not initialized")
    }
}
