package cui.core

import std.collection.ArrayList

/**
 * A readable, observable value. `State` is the writable single source of truth;
 * `DerivedState` provides read-only values computed from other observables. Widgets
 * that only display a value accept `Observable`, so either kind can drive them.
 */
public interface Observable<T> {
    /** Reads the current value. */
    func get(): T

    /** Increases whenever the value may have changed. */
    prop revision: UInt64

    /**
     * Observes subsequent changes and returns a resource that cancels observation.
     * The callback receives `(previous, current)` and is not invoked immediately.
     */
    func observe(callback: (T, T) -> Unit): StateObservation<T>

    /** Returns a read-only state whose value is `transform` applied to this one. */
    func map<U>(transform: (T) -> U): DerivedState<U> {
        derive(this, transform)
    }

    /**
     * Returns a derived state that propagates invalidation only when projected results are not
     * equivalent under `policy`.
     */
    func map<U>(transform: (T) -> U, policy!: StateMutationPolicy<U>): DerivedState<U> {
        deriveDistinct(this, transform, policy)
    }
}

/**
 * A readable and writable observable value. Interactive controls accept `Bindable`,
 * so they work with plain `State` as well as `Binding` projections of larger models.
 */
public interface Bindable<T> <: Observable<T> {
    /** Reads or replaces the current value. */
    mut prop value: T

    /** Reads the current value; equivalent to `value`, for call-style access. */
    func get(): T {
        value
    }

    /** Replaces the current value with one endomorphism of its latest snapshot. */
    func update(transform: (T) -> T): Unit {
        value = transform(value)
    }

    /**
     * Returns a two-way binding onto one component of this value. `get` extracts the
     * component and `set` rebuilds the whole value around a changed component:
     *
     *     let form = State<Profile>(Profile("林", true))
     *     let name = form.project(get: {p => p.name}, set: {p, v => Profile(v, p.subscribed)})
     *     TextField(name)
     */
    func project<U>(get!: (T) -> U, set!: (T, U) -> T): Binding<U> {
        bindingOf<T, U>(this, get, set)
    }

    /** Returns a writable projection whose observations use an explicit result equivalence. */
    func project<U>(
        get!: (T) -> U,
        set!: (T, U) -> T,
        policy!: StateMutationPolicy<U>
    ): Binding<U> {
        bindingOf<T, U>(this, get, set, policy)
    }

    /** Returns a two-way binding through a composable, law-abiding `Lens`. */
    func project<U>(lens: Lens<T, U>): Binding<U> {
        bindingOf<T, U>(this, lens)
    }

    /** Returns a Lens projection whose read side advances only across result equivalence classes. */
    func project<U>(lens: Lens<T, U>, policy!: StateMutationPolicy<U>): Binding<U> {
        bindingOf<T, U>(this, lens, policy)
    }
}

/**
 * An observable, single-source-of-truth value used by stateful controls and views.
 * Assigning `value` updates the revision. Outside a scheduler transaction observers run immediately;
 * inside one outer transaction each State reports only its first previous and final committed value.
 * An explicit mutation policy also suppresses the whole transaction when those endpoints are
 * equivalent, so intermediate excursions cannot create a redundant notification or frame.
 * Every active observer is offered a change even if an earlier callback fails; the first failure is
 * rethrown after delivery so framework invalidation listeners cannot be starved by business code.
 * Scheduler transactions extend that guarantee across State sources and deferred derived observers.
 * A State is thread-confined: after it enters an application, reads, writes, observation changes,
 * and transforms must remain on that UI thread; workers publish results through DesktopApp.post.
 */
public class State<T> <: Bindable<T> {
    private let identity = allocateStateIdentity()
    private var storedValue: T
    private let listeners = ArrayList<StateListener<T>>()
    private var notificationDepth: Int64 = 0
    private var needsListenerCompaction = false
    private var stateRevision: UInt64 = UInt64(0)
    private var scheduler: ?FrameScheduler = None
    private let mutationPolicy: ?StateMutationPolicy<T>
    private var transactionNotification: ?TypedPendingStateNotification<T> = None

    /** Increases after every accepted assignment; a mutation policy may suppress equivalent writes. */
    public prop revision: UInt64 {
        get() {
            prepareRead()
            stateRevision
        }
    }

    /** Reads or replaces the current value. */
    public mut prop value: T {
        get() {
            prepareRead()
            storedValue
        }
        set(next) {
            bindToCurrentScheduler()
            let previous = storedValue
            match (mutationPolicy) {
                case Some(policy) =>
                    if (policy.equivalent(previous, next)) {
                        return
                    }
                case None => ()
            }
            storedValue = next
            stateRevision = nextRevision(stateRevision)
            recordStateWrite()
            match (mutationPolicy) {
                case Some(_) =>
                    // A policy State is observed through transaction endpoints. Queue it even when
                    // it has no listeners so a net-zero batch does not request a redundant frame.
                    if (!enqueueTransactionNotification(previous)) {
                        invalidateScheduler()
                        notify(previous, next)
                    }
                case None =>
                    invalidateScheduler()
                    // Avoid transaction type erasure entirely for the dominant unobserved animation path.
                    if (!listeners.isEmpty() && !enqueueTransactionNotification(previous)) {
                        notify(previous, next)
                    }
            }
        }
    }

    public init(value: T) {
        this.storedValue = value
        this.mutationPolicy = None
    }

    /** Creates State with an explicit policy for suppressing observationally equivalent writes. */
    public init(value: T, policy!: StateMutationPolicy<T>) {
        this.storedValue = value
        this.mutationPolicy = Some(policy)
    }

    /* Stable across the State lifetime and independent of its erased generic value type. */
    func dependencyIdentity(): UInt64 {
        identity
    }

    /* Returns the one lazily allocated type-erased transaction slot owned by this State. */
    func prepareTransactionNotification(previous: T): PendingStateNotification {
        match (transactionNotification) {
            case Some(notification) =>
                notification.prepare(previous)
                notification
            case None =>
                let notification = TypedPendingStateNotification<T>(this, previous)
                transactionNotification = Some(notification)
                notification
        }
    }

    /* Package-private ownership probe for allocation/reentry tests. */
    func transactionNotificationSlot(): ?PendingStateNotification {
        match (transactionNotification) {
            case Some(notification) => Some(notification)
            case None => None
        }
    }

    /* Reads one collector-visible value/revision pair after a single ownership/dependency check. */
    func valueRevisionSnapshot(): (T, UInt64) {
        prepareRead()
        (storedValue, stateRevision)
    }

    /*
     * Samples a phase-transfer hint without making the active build depend on this State. The
     * consuming phase must perform a normal tracked read and repair/rebuild when the hint is stale.
     */
    func phaseHintValueRevisionSnapshot(): (T, UInt64) {
        assertSchedulerThread()
        (storedValue, stateRevision)
    }

    /* Checks ownership without reading the value or registering a build dependency. */
    func assertThreadAccess(): Unit {
        assertSchedulerThread()
    }

    /** Replaces the value with the result of `transform`. */
    public func update(transform: (T) -> T): Unit {
        // Check before running user code so background misuse cannot execute transform side effects.
        value = transform(value)
    }

    private func bindToCurrentScheduler(): Unit {
        match (currentFrameScheduler()) {
            case Some(active) => match (scheduler) {
                case Some(bound) =>
                    if (sameScheduler(bound, active)) {
                        active.assertOwnerThread()
                    } else {
                        // Sequential same-thread apps may transfer; unrelated threads may not.
                        bound.assertOwnerThread()
                        bound.assertStateTransferSourceIdle()
                        active.assertOwnerThread()
                        scheduler = Some(active)
                    }
                case None =>
                    active.assertOwnerThread()
                    scheduler = Some(active)
            }
            case None => assertSchedulerThread()
        }
    }

    private func prepareRead(): Unit {
        match (scheduler) {
            case Some(bound) =>
                bound.assertOwnerThread()
                bound.recordCollectedStateRead(this)
            case None =>
                bindToCurrentScheduler()
                match (scheduler) {
                    case Some(bound) => bound.recordCollectedStateRead(this)
                    case None => recordUnscheduledStateRead(this)
                }
        }
    }

    private func assertSchedulerThread(): Unit {
        match (scheduler) {
            case Some(bound) => bound.assertOwnerThread()
            case None => ()
        }
    }

    private func invalidateScheduler(): Unit {
        match (scheduler) {
            case Some(bound) => bound.invalidate()
            case None => match (currentFrameScheduler()) {
                case Some(active) =>
                    scheduler = Some(active)
                    active.invalidate()
                case None => ()
            }
        }
    }

    public func observe(callback: (T, T) -> Unit): StateObservation<T> {
        bindToCurrentScheduler()
        let listener = StateListener<T>(callback)
        listeners.add(listener)
        StateObservation<T>(
            {
                =>
                    assertSchedulerThread()
                    listener.isActive = false
                    removeListener(listener)
            }
        )
    }

    private func notify(previous: T, current: T): Unit {
        if (listeners.isEmpty()) {
            return
        }

        // Capture only the initial logical window. Appends are invisible to this notification but
        // visible to a nested, later assignment; removals become tombstones until the outer walk
        // finishes, so every active walk keeps stable indices without copying the listener array.
        let limit = listeners.size
        var firstFailure: ?Exception = None
        notificationDepth += 1
        try {
            var index: Int64 = 0
            while (index < limit) {
                let listener = listeners[index]
                let failure = invokeListener(listener, previous, current)
                if (firstFailure.isNone()) {
                    firstFailure = failure
                }
                index += 1
            }
        } finally {
            notificationDepth -= 1
            if (notificationDepth == 0 && needsListenerCompaction) {
                compactListeners()
            }
        }
        match (firstFailure) {
            case Some(error) => throw error
            case None => ()
        }
    }

    private func invokeListener(listener: StateListener<T>, previous: T, current: T): ?Exception {
        if (!listener.isActive) {
            return None
        }
        try {
            listener.callback(previous, current)
            None
        } catch (error: Exception) {
            Some(error)
        }
    }

    private func enqueueTransactionNotification(previous: T): Bool {
        match (scheduler) {
            case Some(bound) => bound.enqueueStateNotification(this, previous)
            case None => false
        }
    }

    /* Returns whether the transaction endpoints occupy different observational equivalence classes. */
    func dispatchTransactionNotification(previous: T, needsEndpointComparison: Bool): Bool {
        match (mutationPolicy) {
            case Some(policy) =>
                // The setter already proved one accepted write non-equivalent. Only a second write
                // can return to the original equivalence class and requires another comparison.
                if (needsEndpointComparison && policy.equivalent(previous, storedValue)) {
                    return false
                }
            case None => ()
        }
        notify(previous, storedValue)
        true
    }

    /* Package-private invariant probe used by notification mutation tests. */
    func listenerSlotCount(): Int64 {
        listeners.size
    }

    private func compactListeners(): Unit {
        var i = listeners.size - 1
        while (i >= 0) {
            if (!listeners[i].isActive) {
                listeners.remove(at: i)
            }
            i -= 1
        }
        needsListenerCompaction = false
    }

    private func removeListener(listener: StateListener<T>): Unit {
        if (notificationDepth > 0) {
            needsListenerCompaction = true
            return
        }
        var i = listeners.size - 1
        while (i >= 0) {
            if (sameListener(listeners[i], listener)) {
                listeners.remove(at: i)
                return
            }
            i -= 1
        }
    }
}

private func sameListener<T>(left: StateListener<T>, right: StateListener<T>): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both operands are class instances by construction
}

private func sameScheduler(left: FrameScheduler, right: FrameScheduler): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both operands are class instances by construction
}

extend<T> State<T> where T <: Equatable<T> {
    /**
     * Assigns `next` only when it differs from the current value, so observers are not
     * notified for no-op writes. Returns whether an assignment happened.
     */
    public func setIfChanged(next: T): Bool {
        if (next == value) {
            return false
        }
        value = next
        true
    }
}
