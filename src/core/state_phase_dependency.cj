package cui.core

import std.collection.{ArrayList, HashMap, HashSet}

/* Transactional dependency set for one retained execution phase. */
class PhaseStateDependencies {
    private let invalidate: () -> Unit
    private let dependencies = ArrayList<StateReadDependency>()
    private let dependenciesByState = HashMap<UInt64, StateReadDependency>()
    private let pending = ArrayList<StateReadDependency>()
    private let pendingSources = HashSet<UInt64>()
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
        let identity = source.dependencyIdentity()
        if (!pendingSources.add(identity)) {
            return
        }
        match (dependenciesByState.get(identity)) {
            case Some(dependency) =>
                pending.add(dependency)
                return
            case None => ()
        }
        let dependency = TypedStateReadDependency<T>(source, {=> handleInvalidation()})
        pending.add(dependency)
        created.add(dependency)
    }

    func commit(): Unit {
        for (previous in dependencies) {
            if (!pendingSources.contains(previous.sourceIdentity)) {
                previous.close()
            }
        }
        dependencies.clear()
        dependenciesByState.clear()
        for (dependency in pending) {
            dependencies.add(dependency)
            dependenciesByState.add(dependency.sourceIdentity, dependency)
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
        dependenciesByState.clear()
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
            return result
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
