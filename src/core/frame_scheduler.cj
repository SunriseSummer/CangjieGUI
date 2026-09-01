package cui.core

import std.collection.{ArrayList, HashMap, HashSet}
import std.sync.{AtomicReference, AtomicUInt64}

private class FrameSchedulerOwner {
    let thread: ?Thread

    init(thread: ?Thread) {
        this.thread = thread
    }
}

// AtomicReference CAS compares object identity. A dedicated token avoids relying on Thread.id
// sentinel values or on ids that the runtime is allowed to reuse after a thread exits.
private let unclaimedFrameSchedulerOwner = FrameSchedulerOwner(None)
private let MAX_TRANSACTION_DISPATCHES: Int64 = 100000

/*
 * Per-application invalidation coordinator. A scheduler is owned by the thread that first activates
 * it; all UI-state reads/writes bound to it must remain on that thread. `DesktopApp.post` is the
 * cross-thread hand-off and drains posted actions inside `transaction`, so several writes caused by
 * one input/action advance the generation only once.
 */
public class FrameScheduler {
    private let generationValue = AtomicUInt64(UInt64(0))
    private let owner = AtomicReference<FrameSchedulerOwner>(unclaimedFrameSchedulerOwner)
    private var transactionDepth: Int64 = 0
    private var transactionDirty = false
    private var flushingTransactionWork = false
    private let pendingStateNotifications = ArrayList<PendingStateNotification>()
    private let pendingStateSources = HashSet<UInt64>()
    private var pendingStateIndex: ?HashMap<UInt64, PendingStateNotification> = None
    private var pendingStateIndexActive = false
    private var lastPendingStateIdentity: ?UInt64 = None
    private var lastPendingStateNotification: ?PendingStateNotification = None
    private let deferredObserverActions = ArrayList<DeferredStateObserverAction>()
    private let deferredObserverIdentities = HashSet<UInt64>()
    private var pendingDispatchFailure: ?Exception = None
    private var stateReadCollector: ?StateReadCollector = None
    private let parentStateReadCollectors = ArrayList<StateReadCollector>()

    /** Current application-local invalidation generation. */
    public init() {}

    protected prop generation: UInt64 {
        get() {
            generationValue.load()
        }
    }

    /**
     * Claims this scheduler for the current thread.
     * Throws `IllegalStateException` when another thread owns it or the atomic claim is inconsistent.
     */
    protected func assertOwnerThread(): Unit {
        let current = Thread.currentThread
        var ownerSnapshot = owner.load()
        if (sameOwner(ownerSnapshot, unclaimedFrameSchedulerOwner)) {
            let candidate = FrameSchedulerOwner(Some(current))
            if (owner.compareAndSwap(unclaimedFrameSchedulerOwner, candidate)) {
                return
            }
            ownerSnapshot = owner.load()
        }
        match (ownerSnapshot.thread) {
            case Some(ownerThread) =>
                if (!sameThread(ownerThread, current)) {
                    throw IllegalStateException(
                        "CUI State is bound to desktop UI thread ${ownerThread.id}; publish background results with DesktopApp.post")
                }
                return
            case None => throw IllegalStateException("CUI frame scheduler owner claim failed")
        }
    }

    /* State may move to a sequential same-thread app, never across an unfinished transaction. */
    func assertStateTransferSourceIdle(): Unit {
        if (transactionDepth > 0 || flushingTransactionWork) {
            throw IllegalStateException(
                "CUI State cannot transfer to another app while its previous scheduler transaction is active")
        }
    }

    /** Whether the owning UI thread is currently collecting retained State dependencies. */
    func isCollectingStateReads(): Bool {
        stateReadCollector.isSome()
    }

    /* Routes a bound State directly through this scheduler's unique active collector. */
    func recordCollectedStateRead<T>(source: State<T>): Unit {
        match (stateReadCollector) {
            case Some(collector) => routeCollectedStateRead(collector, source)
            case None => ()
        }
    }

    func currentStateReadCollector(): ?StateReadCollector {
        stateReadCollector
    }

    /** Marks visual state dirty, coalescing writes while a transaction is active. */
    protected func invalidate(): Unit {
        assertOwnerThread()
        if (transactionDepth > 0 || flushingTransactionWork) {
            transactionDirty = true
        } else {
            generationValue.fetchAdd(UInt64(1))
        }
    }

    /** Runs one UI action atomically, draining State/derived work before reporting its first failure. */
    protected func transaction(body: () -> Unit): Unit {
        assertOwnerThread()
        transactionDepth += 1
        var bodyFailure: ?Exception = None
        try {
            body()
        } catch (error: Exception) {
            bodyFailure = Some(error)
        }
        transactionDepth -= 1

        var notificationFailure: ?Exception = None
        if (transactionDepth == 0 && !flushingTransactionWork) {
            try {
                flushTransactionWork()
            } catch (error: Exception) {
                notificationFailure = Some(error)
            }
            if (transactionDirty) {
                transactionDirty = false
                generationValue.fetchAdd(UInt64(1))
            }
        }

        match (bodyFailure) {
            case Some(error) => match (notificationFailure) {
                case Some(notification) => throw IllegalStateException(
                    "State transaction failed (${error.message}) and notification also failed (${notification.message})")
                case None => throw error
            }
            case None => match (notificationFailure) {
                case Some(error) => throw error
                case None => ()
            }
        }
    }

    /* Queues the first pre-transaction value; dispatch reads the source's final committed value. */
    func enqueueStateNotification<T>(source: State<T>, previous: T): Bool {
        if (transactionDepth <= 0 && !flushingTransactionWork) {
            return false
        }
        let identity = source.dependencyIdentity()
        if (pendingStateSources.add(identity)) {
            let pending = source.prepareTransactionNotification(previous)
            pendingStateNotifications.add(pending)
            lastPendingStateIdentity = Some(identity)
            lastPendingStateNotification = Some(pending)
            if (pendingStateIndexActive) {
                let index = activePendingStateIndex()
                if (index.add(identity, pending).isSome()) {
                    throw IllegalStateException("Pending State notification index duplicated a newly admitted source")
                }
            }
        } else {
            recordAdditionalStateWrite(identity)
        }
        true
    }

    /* Defers a derived observer until all State notifications currently ahead of it have settled. */
    func deferStateObserver(action: DeferredStateObserverAction): Bool {
        if (transactionDepth <= 0 && !flushingTransactionWork) {
            return false
        }
        if (deferredObserverIdentities.add(action.identity)) {
            deferredObserverActions.add(action)
        }
        true
    }

    private func flushTransactionWork(): Unit {
        if (pendingStateNotifications.isEmpty() && deferredObserverActions.isEmpty()) {
            return
        }
        flushingTransactionWork = true
        var stateIndex: Int64 = 0
        var actionIndex: Int64 = 0
        var dispatches: Int64 = 0
        var firstFailure: ?Exception = None
        try {
            while (stateIndex < pendingStateNotifications.size || actionIndex < deferredObserverActions.size) {
                while (stateIndex < pendingStateNotifications.size) {
                    dispatches += 1
                    ensureTransactionConverges(dispatches)
                    let notification = pendingStateNotifications[stateIndex]
                    removePendingStateNotification(notification)
                    stateIndex += 1
                    dispatchStateNotification(notification)
                }
                if (actionIndex < deferredObserverActions.size) {
                    dispatches += 1
                    ensureTransactionConverges(dispatches)
                    let action = deferredObserverActions[actionIndex]
                    let _ = deferredObserverIdentities.remove(action.identity) // cjcheck-ignore: ignore-result # the set is only a coalescing index; absence cannot affect delivery
                    actionIndex += 1
                    dispatchDeferredObserverAction(action)
                }
            }
            firstFailure = pendingDispatchFailure
        } finally {
            clearPendingTransactionWork()
        }
        match (firstFailure) {
            case Some(error) => throw error
            case None => ()
        }
    }

    private func dispatchStateNotification(notification: PendingStateNotification): Unit {
        try {
            if (notification.dispatch()) {
                transactionDirty = true
            }
        } catch (error: Exception) {
            transactionDirty = true
            recordDispatchFailure(error)
        }
    }

    private func dispatchDeferredObserverAction(action: DeferredStateObserverAction): Unit {
        try {
            action.dispatch()
        } catch (error: Exception) {
            recordDispatchFailure(error)
        }
    }

    private func recordDispatchFailure(error: Exception): Unit {
        if (pendingDispatchFailure.isNone()) {
            pendingDispatchFailure = Some(error)
        }
    }

    private func clearPendingTransactionWork(): Unit {
        pendingStateNotifications.clear()
        pendingStateSources.clear()
        match (pendingStateIndex) {
            case Some(index) => index.clear()
            case None => ()
        }
        pendingStateIndexActive = false
        lastPendingStateIdentity = None
        lastPendingStateNotification = None
        deferredObserverActions.clear()
        deferredObserverIdentities.clear()
        pendingDispatchFailure = None
        flushingTransactionWork = false
    }

    private func recordAdditionalStateWrite(identity: UInt64): Unit {
        match (lastPendingStateIdentity) {
            case Some(lastIdentity) =>
                if (lastIdentity == identity) {
                    match (lastPendingStateNotification) {
                        case Some(pending) =>
                            pending.recordAdditionalWrite()
                            return
                        case None => ()
                    }
                }
            case None => ()
        }
        match (activePendingStateIndex().get(identity)) {
            case Some(pending) => pending.recordAdditionalWrite()
            case None => throw IllegalStateException("Pending State notification index lost an active source")
        }
    }

    private func activePendingStateIndex(): HashMap<UInt64, PendingStateNotification> {
        let index = match (pendingStateIndex) {
            case Some(existing) => existing
            case None =>
                let created = HashMap<UInt64, PendingStateNotification>()
                pendingStateIndex = Some(created)
                created
        }
        if (!pendingStateIndexActive) {
            index.clear()
            for (pending in pendingStateNotifications) {
                if (pendingStateSources.contains(pending.sourceIdentity)) {
                    match (index.add(pending.sourceIdentity, pending)) {
                        case Some(_) => () // the later active entry is canonical after observer reentry
                        case None => ()
                    }
                }
            }
            pendingStateIndexActive = true
        }
        index
    }

    private func removePendingStateNotification(notification: PendingStateNotification): Unit {
        let identity = notification.sourceIdentity
        if (!pendingStateSources.remove(identity)) {
            throw IllegalStateException("Pending State notification lost its active source")
        }
        match (lastPendingStateIdentity) {
            case Some(lastIdentity) =>
                if (lastIdentity == identity) {
                    lastPendingStateIdentity = None
                    lastPendingStateNotification = None
                }
            case None => ()
        }
        if (pendingStateIndexActive) {
            match (pendingStateIndex) {
                case Some(index) =>
                    if (index.remove(identity).isNone()) {
                        throw IllegalStateException("Pending State notification index lost its dispatched source")
                    }
                case None => ()
            }
        }
    }

    private func ensureTransactionConverges(dispatches: Int64): Unit {
        if (dispatches > MAX_TRANSACTION_DISPATCHES) {
            throw IllegalStateException(
                "State transaction did not converge after ${MAX_TRANSACTION_DISPATCHES} notifications; check for an observer cycle")
        }
    }

    func beginStateReadCollection(collector: StateReadCollector): Unit {
        match (stateReadCollector) {
            case Some(current) => parentStateReadCollectors.add(current)
            case None => ()
        }
        stateReadCollector = Some(collector)
    }

    func endStateReadCollection(): Unit {
        if (stateReadCollector.isNone()) {
            throw IllegalStateException("Unbalanced scheduler State read collection")
        }
        if (parentStateReadCollectors.isEmpty()) {
            stateReadCollector = None
        } else {
            stateReadCollector = Some(parentStateReadCollectors.remove(at: parentStateReadCollectors.size - 1))
        }
    }
}

private func sameOwner(left: FrameSchedulerOwner, right: FrameSchedulerOwner): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both operands are class instances by construction
}

private func sameThread(left: Thread, right: Thread): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both operands are class instances by construction
}

// Build/event callbacks are synchronous but may nest. Thread-local storage prevents a second app on
// another thread from binding its State objects to this app's scheduler.
private let activeFrameScheduler = ThreadLocal<FrameScheduler>()

/** Runs `body` with `scheduler` as the current UI scheduler, restoring any nested predecessor. */
protected func withFrameScheduler(scheduler: FrameScheduler, body: () -> Unit): Unit {
    scheduler.assertOwnerThread()
    let previous = activeFrameScheduler.get()
    activeFrameScheduler.set(Some(scheduler))
    try {
        body()
    } finally {
        activeFrameScheduler.set(previous)
    }
}

/** Returns the scheduler active on this thread, if the caller is inside a desktop frame/action. */
func currentFrameScheduler(): ?FrameScheduler {
    activeFrameScheduler.get()
}
