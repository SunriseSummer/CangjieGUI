package cui.core

import std.sync.AtomicInt64

private let scheduledStateReadCollections = AtomicInt64(0)

/* Type-erased reactive subscription owned by one retained build or execution-phase scope. */
interface ObservableReadDependency <: Resource {
    prop sourceIdentity: UInt64
}

class TypedStateReadDependency<T> <: ObservableReadDependency {
    private let identity: UInt64
    private let observation: StateObservation<T>

    init(state: State<T>, invalidate: () -> Unit) {
        this.identity = state.dependencyIdentity()
        this.observation = state.observe({_, _ => invalidate()})
    }

    /** Process-unique identity of the observed State, independent of its generic value type. */
    public prop sourceIdentity: UInt64 {
        get() {
            identity
        }
    }

    /** Returns whether the underlying State observation has been cancelled. */
    public func isClosed(): Bool {
        observation.isClosed()
    }

    /** Cancels the underlying State observation; repeated calls are safe. */
    public func close(): Unit {
        observation.close()
    }
}

class TypedDerivedReadDependency<T> <: ObservableReadDependency {
    private let identity: UInt64
    private let observation: StateObservation<T>

    init(source: DerivedState<T>, invalidate: () -> Unit) {
        this.identity = source.dependencyIdentity()
        this.observation = source.observeInvalidation(invalidate)
    }

    /** Stable identity of the aggregate DerivedState node represented by this edge. */
    public prop sourceIdentity: UInt64 {
        get() {
            identity
        }
    }

    /** Returns whether the aggregate invalidation subscription has been cancelled. */
    public func isClosed(): Bool {
        observation.isClosed()
    }

    /** Detaches this edge and all invalidation subscriptions owned by the DerivedState observation. */
    public func close(): Unit {
        observation.close()
    }
}

/* Exactly one dependency owner receives a collected read: a build scope or an execution phase. */
enum StateReadCollector {
    | Mount(StateMountBuild)
    | Phase(PhaseStateDependencies)
}

private class UnscheduledStateReadCollectorFrame {
    let collector: StateReadCollector
    let previous: ?UnscheduledStateReadCollectorFrame

    init(collector: StateReadCollector, previous: ?UnscheduledStateReadCollectorFrame) {
        this.collector = collector
        this.previous = previous
    }
}

private let unscheduledStateReadCollector = ThreadLocal<UnscheduledStateReadCollectorFrame>()

func routeCollectedStateRead<T>(collector: StateReadCollector, source: State<T>): Unit {
    match (collector) {
        case StateReadCollector.Mount(build) => build.readState(source)
        case StateReadCollector.Phase(dependencies) => dependencies.readState(source)
    }
}

private func beginCollectedDerivedRead<T>(collector: StateReadCollector, source: DerivedState<T>): Bool {
    match (collector) {
        case StateReadCollector.Mount(build) => build.beginDerivedRead(source)
        case StateReadCollector.Phase(dependencies) =>
            dependencies.beginDerivedRead(source)
            true
    }
}

private func endCollectedDerivedRead(collector: StateReadCollector): Unit {
    match (collector) {
        case StateReadCollector.Mount(build) => build.endDerivedRead()
        case StateReadCollector.Phase(dependencies) => dependencies.endDerivedRead()
    }
}

func leaveDerivedReadDepth(depth: Int64, scope: String): Int64 {
    if (depth <= 0) {
        throw IllegalStateException("Unbalanced derived ${scope} dependency read")
    }
    depth - 1
}

func recordUnscheduledStateRead<T>(source: State<T>): Unit {
    match (unscheduledStateReadCollector.get()) {
        case Some(frame) => routeCollectedStateRead(frame.collector, source)
        case None => ()
    }
}

func collectDerivedStateRead<T>(source: DerivedState<T>, body: () -> T): T {
    match (currentStateReadCollector()) {
        case Some(collector) =>
            if (!beginCollectedDerivedRead(collector, source)) {
                return body()
            }
            try {
                return body()
            } finally {
                endCollectedDerivedRead(collector)
            }
        case None => body()
    }
}

func beginStateReadCollection(collector: StateReadCollector): Unit {
    match (currentFrameScheduler()) {
        case Some(scheduler) =>
            scheduler.beginStateReadCollection(collector)
            scheduledStateReadCollections.fetchAdd(1)
        case None =>
            let previous = unscheduledStateReadCollector.get()
            unscheduledStateReadCollector.set(Some(UnscheduledStateReadCollectorFrame(collector, previous)))
    }
}

func isStateReadCollectionActive(): Bool {
    if (unscheduledStateReadCollector.get().isSome()) {
        return true
    }
    if (scheduledStateReadCollections.load() <= 0) {
        return false
    }
    match (currentFrameScheduler()) {
        case Some(scheduler) => scheduler.isCollectingStateReads()
        case None => false
    }
}

func endStateReadCollection(): Unit {
    match (currentFrameScheduler()) {
        case Some(scheduler) =>
            scheduler.endStateReadCollection()
            scheduledStateReadCollections.fetchAdd(-1)
        case None => match (unscheduledStateReadCollector.get()) {
            case Some(frame) => unscheduledStateReadCollector.set(frame.previous)
            case None => throw IllegalStateException("Unbalanced unscheduled State read collection")
        }
    }
}

private func currentStateReadCollector(): ?StateReadCollector {
    match (currentFrameScheduler()) {
        case Some(scheduler) => scheduler.currentStateReadCollector()
        case None => match (unscheduledStateReadCollector.get()) {
            case Some(frame) => Some(frame.collector)
            case None => None
        }
    }
}
