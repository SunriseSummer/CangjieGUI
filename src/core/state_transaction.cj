package cui.core

/* Type-erased notification queued by one outermost FrameScheduler transaction. */
interface PendingStateNotification {
    prop sourceIdentity: UInt64
    func recordAdditionalWrite(): Unit
    func dispatch(): Bool
}

class TypedPendingStateNotification<T> <: PendingStateNotification {
    private let source: State<T>
    private var previous: T
    private var needsEndpointComparison = false

    init(source: State<T>, previous: T) {
        this.source = source
        this.previous = previous
    }

    /* Reinitializes the State-owned slot for a new pending transaction segment. */
    func prepare(previous: T): Unit {
        this.previous = previous
        needsEndpointComparison = false
    }

    /** Stable identity used to coalesce multiple writes to this source. */
    public prop sourceIdentity: UInt64 {
        get() {
            source.dependencyIdentity()
        }
    }

    /** Records that setter non-equivalence alone no longer proves the complete transaction changed. */
    public func recordAdditionalWrite(): Unit {
        needsEndpointComparison = true
    }

    /** Delivers a net change and returns false when the source policy equates both transaction ends. */
    public func dispatch(): Bool {
        let transactionPrevious = previous
        let compareEndpoints = needsEndpointComparison
        // Copy before callbacks: a reentrant write may prepare this same slot for its next segment.
        needsEndpointComparison = false
        source.dispatchTransactionNotification(transactionPrevious, compareEndpoints)
    }
}

/* Stable observer continuation reused across transactions and run after pending State notifications. */
class DeferredStateObserverAction {
    let identity: UInt64
    private let action: () -> Unit

    init(identity: UInt64, action: () -> Unit) {
        this.identity = identity
        this.action = action
    }

    func dispatch(): Unit {
        action()
    }
}
