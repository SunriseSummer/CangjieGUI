package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.Rect

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
}

/**
 * An observable, single-source-of-truth value used by stateful controls and views.
 * Assigning `value` updates the revision and notifies observers synchronously on the caller thread.
 * A State is thread-confined: after it enters an application, reads, writes, observation changes,
 * and transforms must remain on that UI thread; workers publish results through DesktopApp.post.
 */
public class State<T> <: Bindable<T> {
    private var storedValue: T
    private let listeners = ArrayList<StateListener<T>>()
    private var stateRevision: UInt64 = UInt64(0)
    private var scheduler: ?FrameScheduler = None

    /** Increases after every assignment, including assignments of an equal value. */
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
            storedValue = next
            stateRevision = nextRevision(stateRevision)
            recordStateWrite()
            invalidateScheduler()
            notify(previous, next)
        }
    }

    public init(value: T) {
        this.storedValue = value
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
                if (bound.isCollectingStateReads()) {
                    recordCollectedStateRead(this)
                }
            case None =>
                bindToCurrentScheduler()
                match (scheduler) {
                    case Some(bound) =>
                        if (bound.isCollectingStateReads()) {
                            recordCollectedStateRead(this)
                        }
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
        // A snapshot tolerates cancellation/re-subscription: new listeners see later assignments,
        // cancelled ones are skipped, and compaction follows the iteration.
        let snapshot = listeners.toArray()
        for (listener in snapshot) {
            if (listener.isActive) {
                listener.callback(previous, current)
            }
        }
        compactListeners()
    }

    private func compactListeners(): Unit {
        var i = listeners.size - 1
        while (i >= 0) {
            if (!listeners[i].isActive) {
                listeners.remove(at: i)
            }
            i -= 1
        }
    }

    private func removeListener(listener: StateListener<T>): Unit {
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

/**
 * Retains explicitly keyed local state across declarative tree rebuilds. Entries that
 * are not visited during a completed build are removed, matching view unmount semantics.
 */
public class StateStore {
    let entries = HashMap<String, Any>()
    let retainedEntries = HashMap<String, RetainedRecord>()
    let automaticEntries = HashMap<String, AutomaticCompositionRecord>()
    let automaticPaintBudget = AutomaticPaintBudget()
    let lifecycleEffects = HashMap<String, LifecycleEffectRecord>()
    let rootMountScope = StateMountScope()
    let mountBuilds = ArrayList<StateMountBuild>()
    let activeMountBuilds = ArrayList<StateMountBuild>()
    let stateAddedDuringBuild = ArrayList<String>()
    let retainedAddedDuringBuild = ArrayList<String>()
    let automaticAddedDuringBuild = ArrayList<String>()
    let retainedReplacements = ArrayList<PendingRetainedReplacement>()
    let automaticReplacements = ArrayList<PendingAutomaticCompositionReplacement>()
    let pendingLifecycleEffects = ArrayList<PendingLifecycleEffect>()
    let lifecycleEffectRemovals = ArrayList<String>()
    let failedLifecycleCleanups = ArrayList<Resource>()
    let frameSubscribers = ArrayList<FrameSubscriber>()
    var forceFullRetainedExecution = false
    var automaticCompositionEnabled = false
    var acceptingBuildDeclarations = false
    let scopes = ArrayList<String>()
    private let controlIdCounts = HashMap<String, Int64>()
    let automaticScopeCounts = HashMap<String, Int64>()
    private let focusOrder = ArrayList<String>()
    var pendingRetainedDamage: ?Rect = None
    var fullRetainedDamagePending = true
    var rootLayoutDependencies: ?PhaseStateDependencies = None
    var rootPaintDependencies: ?PhaseStateDependencies = None

    /**
     * Returns the state at the current scope and key, creating it on first use.
     * Throws `IllegalArgumentException` for an empty key and `IllegalStateException`
     * for a duplicate key or a key whose value type changed.
     */
    public func remember<T>(key: String, initial: () -> T): State<T> {
        validateKey(key)
        let path = scopedKey(key)
        visitRememberedState(this, path, key)

        match (entries.get(path)) {
            case Some(stored) => match (stored as State<T>) {
                case Some(state) => state
                case None => throw IllegalStateException("Remembered state key '${key}' changed value type")
            }
            case None =>
                let state = State<T>(initial())
                let _ = entries.add(path, state) // cjcheck-ignore: ignore-result # key was just checked absent; no displaced value exists
                recordStateInsertion(this, path)
                state
        }
    }

    /** Removes every retained state value. */
    public func clear(): Unit {
        let effectFailure = clearLifecycleEffects(this)
        clearMountedState(this)
        clearRetainedDamageTracking(this)
        match (effectFailure) {
            case Some(error) => throw error
            case None => ()
        }
    }

    // Builds run every frame, so the per-build bookkeeping reuses its collections
    // instead of allocating fresh ones.
    func beginBuild(): Unit {
        acceptingBuildDeclarations = true
        beginMountBuild(this)
        beginStateReadCollection()
        beginLifecycleEffectBuild(this)
        scopes.clear()
        controlIdCounts.clear()
        automaticScopeCounts.clear()
        focusOrder.clear()
        frameSubscribers.clear()
    }

    func finishBuildBody(): Unit {
        if (!acceptingBuildDeclarations) {
            throw IllegalStateException("UI build body was already finished")
        }
        endStateReadCollection()
        acceptingBuildDeclarations = false
    }

    func finishBuild(): ?Exception {
        if (acceptingBuildDeclarations) {
            throw IllegalStateException("UI build body must finish before commit")
        }
        prepareLifecycleEffectBuild(this)
        finishMountBuild(this)
        scopes.clear()
        commitLifecycleEffectBuild(this)
    }

    /** Rolls back state created by a build that threw partway through. */
    func cancelBuild(): ?Exception {
        if (acceptingBuildDeclarations) {
            endStateReadCollection()
            acceptingBuildDeclarations = false
        }
        let effectFailure = cancelLifecycleEffectBuild(this)
        cancelMountBuild(this)
        frameSubscribers.clear()
        scopes.clear()
        effectFailure
    }

    func pushScope(key: String): Unit {
        validateKey(key)
        scopes.add(key)
    }

    func popScope(): Unit {
        if (!scopes.isEmpty()) {
            scopes.remove(at: scopes.size - 1)
        }
    }

    /*
     * A stable identity for a control that declared no explicit id. The identity is the
     * control's default name inside the current `Keyed` scope; repeated names receive a
     * build-order suffix. The counters reset each build, so identities stay stable while
     * the declared tree keeps its shape — this is what lets two icon-only buttons in one
     * row own separate focus and press state.
     */
    func uniqueControlId(base: String): String {
        let path = scopedKey(base)
        let seen = match (controlIdCounts.get(path)) {
            case Some(count) => count
            case None => 0
        }
        let _ = controlIdCounts.add(path, seen + 1) // cjcheck-ignore: ignore-result # displaced count is `seen`, already read above
        if (seen == 0) {
            path
        } else {
            "${path}#${seen + 1}"
        }
    }

    /*
     * Records a control that can hold keyboard focus, in build (declaration) order. The
     * shell reads this list after each build to move focus with Tab / Shift+Tab. Like the
     * control-id counters it is rebuilt every frame, so the traversal order tracks the
     * declared tree without any retained widget references.
     */
    func registerFocusable(id: String): Unit {
        // A duplicate id (two controls given the same explicit id) registers once: the
        // first-match search in moveFocus would otherwise bounce between the twin
        // entries forever and Tab could never leave them.
        if (!focusOrder.contains(id)) {
            focusOrder.add(id)
        }
    }

    /*
     * Replaces a previously registered focus id with an explicit one. A control registers
     * its build-order id in its constructor; a chained `.key(...)` overrides that id and
     * calls this so the ring stays consistent with what the control checks in `hasFocus`.
     * The auto id is almost always the last entry, so the search from the end is O(1).
     */
    func reregisterFocusable(previous: String, replacement: String): Unit {
        removeFocusable(replacement) // keep the no-duplicate invariant on id collisions
        var i = focusOrder.size - 1
        while (i >= 0) {
            if (focusOrder[i] == previous) {
                focusOrder[i] = replacement
                return
            }
            i -= 1
        }
        focusOrder.add(replacement)
    }

    /** Removes `id` from this build's ring — a control disabled by `.enabled(false)` leaves Tab traversal. */
    func unregisterFocusable(id: String): Unit {
        removeFocusable(id)
    }

    private func removeFocusable(id: String): Unit {
        var i = focusOrder.size - 1
        while (i >= 0) {
            if (focusOrder[i] == id) {
                focusOrder.remove(at: i)
                return
            }
            i -= 1
        }
    }

    /** The focusable control ids gathered by the most recent build, in traversal order. */
    protected func focusRing(): Array<String> {
        focusOrder.toArray()
    }

    /** Number of focus stops registered so far in this build; see `focusablesFrom`. */
    func focusableCount(): Int64 {
        focusOrder.size
    }

    /*
     * The focus stops registered at or after `start`, in declaration order. An overlay
     * host (Modal) snapshots the count before building its subtree and takes this slice
     * after, giving it the focus stops that live inside the dialog — the scope its Tab
     * trap cycles through.
     */
    func focusablesFrom(start: Int64): Array<String> {
        if (start >= focusOrder.size) {
            return []
        }
        let from = max(0, start)
        Array<String>(focusOrder.size - from, {i => focusOrder[from + i]})
    }

    func scopedKey(key: String): String {
        let result = StringBuilder()
        for (scope in scopes) {
            appendKeySegment(result, scope)
        }
        appendKeySegment(result, key)
        result.toString()
    }

    func diagnosticScopedKey(key: String): String {
        let result = StringBuilder()
        for (scope in scopes) {
            if (scope.startsWith("@")) {
                continue
            }
            result.append(scope)
            result.append(" / ")
        }
        result.append(key)
        result.toString()
    }

    private func appendKeySegment(result: StringBuilder, value: String): Unit {
        result.append(value.size)
        result.append(":")
        result.append(value)
        result.append(";")
    }

    /** Throws `IllegalArgumentException` when a state identity key is empty. */
    func validateKey(key: String): Unit {
        if (key.isEmpty()) {
            throw IllegalArgumentException("State key must not be empty")
        }
    }
}

/**
 * Returns local state retained by the active `DesktopApp` build. Place repeated or
 * conditionally mounted state inside `Keyed` so its identity is independent of position.
 * Throws `IllegalArgumentException` for an empty key and `IllegalStateException` when
 * called outside an active build, or when key identity rules are violated.
 */
public func rememberState<T>(key: String, initial: () -> T): State<T> {
    currentStateStore().remember<T>(key, initial)
}
