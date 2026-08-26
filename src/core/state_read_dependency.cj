package cui.core

var unscheduledStateReadCollectionDepth: Int64 = 0 // cjcheck-ignore: global-var # headless/direct builds share CUI's single UI build thread contract

/* Type-erased subscription owned by one retained build scope. */
interface StateReadDependency <: Resource {
    prop sourceIdentity: UInt64
}

class TypedStateReadDependency<T> <: StateReadDependency {
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

func recordCollectedStateRead<T>(source: State<T>): Unit {
    recordStateReadInActiveCollector(source)
}

func recordUnscheduledStateRead<T>(source: State<T>): Unit {
    if (unscheduledStateReadCollectionDepth <= 0) {
        return
    }
    recordStateReadInActiveCollector(source)
}

private func recordStateReadInActiveCollector<T>(source: State<T>): Unit {
    match (currentPhaseStateReads()) {
        case Some(collector) => collector.readState(source)
        case None => match (currentStateStoreIfActive()) {
            case Some(store) => recordMountStateRead(store, source)
            case None => ()
        }
    }
}

func beginStateReadCollection(): Unit {
    match (currentFrameScheduler()) {
        case Some(scheduler) => scheduler.beginStateReadCollection()
        case None => unscheduledStateReadCollectionDepth += 1
    }
}

func endStateReadCollection(): Unit {
    match (currentFrameScheduler()) {
        case Some(scheduler) => scheduler.endStateReadCollection()
        case None =>
            if (unscheduledStateReadCollectionDepth <= 0) {
                throw IllegalStateException("Unbalanced unscheduled State read collection")
            }
            unscheduledStateReadCollectionDepth -= 1
    }
}
