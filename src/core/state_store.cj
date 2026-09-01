package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.Rect

/**
 * Retains local state across declarative tree rebuilds. Public direct access is explicitly keyed;
 * the active build helper also projects guarded positional slots onto this ownership store.
 */
public class StateStore {
    let elementArena: ElementArena
    let entries = HashMap<String, Any>()
    let retainedEntries = HashMap<String, RetainedRecord>()
    let automaticEntries = HashMap<String, AutomaticCompositionRecord>()
    let automaticPaintBudget = AutomaticPaintBudget()
    let lifecycleEffects = HashMap<String, LifecycleEffectRecord>()
    let rootMountScope: StateMountScope
    let mountBuilds = ArrayList<StateMountBuild>()
    let activeMountBuilds = ArrayList<StateMountBuild>()
    let mountBuildArena = ArrayList<StateMountBuild>()
    var mountBuildArenaCursor: Int64 = 0
    let stateAddedDuringBuild = ArrayList<String>()
    let retainedAddedDuringBuild = ArrayList<String>()
    let automaticAddedDuringBuild = ArrayList<String>()
    let elementAddedDuringBuild = ArrayList<ElementId>()
    let retainedReplacements = ArrayList<PendingRetainedReplacement>()
    let automaticReplacements = ArrayList<PendingAutomaticCompositionReplacement>()
    let pendingLifecycleEffects = ArrayList<PendingLifecycleEffect>()
    let lifecycleEffectRemovals = ArrayList<String>()
    let failedLifecycleCleanups = ArrayList<Resource>()
    let frameSubscriptionRegistry = FrameSubscriptionRegistry()
    var forceFullRetainedExecution = false
    var automaticCompositionEnabled = false
    var acceptingBuildDeclarations = false
    let scopes = ArrayList<String>()
    private var cachedImplicitSlotNamespace: ?String = None
    private var cachedImplicitSlotCursor: ?ImplicitSlotCursor = None
    private let controlIdCounts = HashMap<String, Int64>()
    let automaticScopeCounts = HashMap<String, Int64>()
    private let focusRegistry = FocusRegistry()
    var pendingRetainedDamage: ?Rect = None
    var fullRetainedDamagePending = true
    var rootLayoutDependencies: ?PhaseStateDependencies = None
    var rootPaintDependencies: ?PhaseStateDependencies = None

    /** Creates an empty ownership store with one persistent root Element. */
    public init() {
        elementArena = ElementArena()
        rootMountScope = StateMountScope(elementArena.rootId)
        elementArena.attachMountScope(elementArena.rootId, rootMountScope)
    }

    /**
     * Returns the state at the current scope and key, creating it on first use.
     * Throws `IllegalArgumentException` for an empty key and `IllegalStateException`
     * for a duplicate key or a key whose value type changed.
     */
    public func remember<T>(key: String, initial: () -> T): State<T> {
        validateKey(key)
        rememberValueAt<State<T>>(scopedKey(key), "key '${key}'", {=> State<T>(initial())})
    }

    /** Returns keyed local State with an explicit observational-equivalence policy. */
    public func remember<T>(key: String, policy: StateMutationPolicy<T>, initial: () -> T): State<T> {
        validateKey(key)
        rememberValueAt<State<T>>(scopedKey(key), "key '${key}'", {=> State<T>(initial(), policy: policy)})
    }

    /* Positional state slot used by the keyless public helper during an active build. */
    func rememberImplicit<T>(initial: () -> T): State<T> {
        let (path, identity) = nextImplicitSlot(ImplicitSlotKind.RememberedValue)
        rememberValueAt<State<T>>(path, identity, {=> State<T>(initial())})
    }

    /* Positional State slot with an explicit observational-equivalence policy. */
    func rememberImplicit<T>(policy: StateMutationPolicy<T>, initial: () -> T): State<T> {
        let (path, identity) = nextImplicitSlot(ImplicitSlotKind.RememberedValue)
        rememberValueAt<State<T>>(path, identity, {=> State<T>(initial(), policy: policy)})
    }

    /* Arbitrary stable value retained under an explicit key during an active build. */
    func rememberValue<T>(key: String, factory: () -> T): T {
        validateKey(key)
        rememberValueAt<T>(scopedKey(key), "key '${key}'", factory)
    }

    /* Arbitrary stable value retained in the next guarded positional slot. */
    func rememberImplicitValue<T>(factory: () -> T): T {
        let (path, identity) = nextImplicitSlot(ImplicitSlotKind.RememberedValue)
        rememberValueAt<T>(path, identity, factory)
    }

    func nextImplicitSlot(kind: ImplicitSlotKind): (String, String) {
        let cursor = match (cachedImplicitSlotCursor) {
            case Some(current) => current
            case None =>
                let current = currentMountBuild(this).implicitSlotCursor(implicitSlotNamespace())
                cachedImplicitSlotCursor = Some(current)
                current
        }
        let slot = cursor.count
        (cursor.claimPath(kind), "slot #${slot + 1}")
    }

    private func rememberValueAt<T>(path: String, identity: String, factory: () -> T): T {
        visitRememberedState(this, path, identity)

        match (entries.get(path)) {
            case Some(stored) => match (stored as T) {
                case Some(value) => value
                case None => throw IllegalStateException("Remembered state ${identity} changed value type")
            }
            case None =>
                let value = withRememberedValueConstruction(factory)
                let _ = entries.add(path, value) // cjcheck-ignore: ignore-result # path was just checked absent; no displaced value exists
                recordStateInsertion(this, path)
                value
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
        scopes.clear()
        cachedImplicitSlotNamespace = None
        cachedImplicitSlotCursor = None
        acceptingBuildDeclarations = true
        beginMountBuild(this)
        beginMountStateReadCollection(this)
        beginLifecycleEffectBuild(this)
        controlIdCounts.clear()
        automaticScopeCounts.clear()
        focusRegistry.clear()
        frameSubscriptionRegistry.clear()
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
        cachedImplicitSlotNamespace = None
        cachedImplicitSlotCursor = None
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
        frameSubscriptionRegistry.clear()
        scopes.clear()
        cachedImplicitSlotNamespace = None
        cachedImplicitSlotCursor = None
        effectFailure
    }

    func pushScope(key: String): Unit {
        validateKey(key)
        scopes.add(key)
        cachedImplicitSlotNamespace = None
        cachedImplicitSlotCursor = None
        if (!activeMountBuilds.isEmpty()) {
            let build = currentMountBuild(this)
            if (build.hasCommittedImplicitSlotShapes()) {
                build.registerImplicitSlotScope(implicitSlotNamespace())
            }
        }
    }

    func popScope(): Unit {
        if (!scopes.isEmpty()) {
            scopes.remove(at: scopes.size - 1)
            cachedImplicitSlotNamespace = None
            cachedImplicitSlotCursor = None
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
    func registerFocusable(target: FocusTarget): Unit {
        focusRegistry.register(target)
    }

    /* Replays a persistent declaration fragment; an empty registry adopts it in O(1). */
    func registerFocusFragment(snapshot: FocusSnapshot): Unit {
        focusRegistry.replay(snapshot)
    }

    /*
     * Replaces a previously registered focus id with an explicit one. A control registers
     * its build-order id in its constructor; a chained `.key(...)` overrides that id and
     * calls this so the ring stays consistent with what the control checks in `hasFocus`.
     * The auto id is almost always the last entry, so the search from the end is O(1).
     */
    func reregisterFocusable(previous: String, replacement: String): Unit {
        focusRegistry.reregister(previous, replacement)
    }

    /** Removes `id` from this build's ring — a control disabled by `.enabled(false)` leaves Tab traversal. */
    func unregisterFocusable(id: String): Unit {
        focusRegistry.unregister(id)
    }

    /** The focusable control ids gathered by the most recent build, in traversal order. */
    protected func focusRing(): Array<String> {
        focusRegistry.ring()
    }

    /** Adopts the latest ownership-preserving focus graph into a host context. */
    protected func adoptFocus(context: UiContext): Unit {
        context.adoptFocusSnapshot(focusRegistry.snapshot())
    }

    /** Number of focus stops registered so far in this build; see `focusablesFrom`. */
    func focusableCount(): Int64 {
        focusRegistry.size
    }

    /*
     * The focus stops registered at or after `start`, in declaration order. An overlay
     * host (Modal) snapshots the count before building its subtree and takes this slice
     * after, giving it the focus stops that live inside the dialog — the scope its Tab
     * trap cycles through.
     */
    func focusablesFrom(start: Int64): Array<String> {
        focusRegistry.from(start)
    }

    /** Number of focus declarations, including duplicate public keys, recorded so far. */
    func focusDeclarationCount(): Int64 {
        focusRegistry.declarationCount()
    }

    /** Persistent declaration fragment recorded since `start`. */
    func focusFragmentFrom(start: Int64): FocusSnapshot {
        focusRegistry.fragmentFrom(start)
    }

    /** Persistent active focus declarations inside one stable build-log interval. */
    func focusFragmentBetween(start: Int64, end: Int64): FocusSnapshot {
        focusRegistry.fragmentBetween(start, end)
    }

    func scopedKey(key: String): String {
        let result = StringBuilder()
        for (scope in scopes) {
            appendKeySegment(result, scope)
        }
        appendKeySegment(result, key)
        result.toString()
    }

    /*
     * Empty key segments are forbidden for explicit keys and Keyed scopes, so an empty namespace
     * segment makes the positional sum disjoint from every user-constructible explicit path.
     */
    func implicitSlotNamespace(): String {
        match (cachedImplicitSlotNamespace) {
            case Some(namespace) => return namespace
            case None => ()
        }
        let result = StringBuilder()
        for (scope in scopes) {
            appendKeySegment(result, scope)
        }
        appendKeySegment(result, "")
        let namespace = result.toString()
        cachedImplicitSlotNamespace = Some(namespace)
        namespace
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

private let rememberedValueConstruction = ThreadLocal<Bool>()

private func withRememberedValueConstruction<T>(factory: () -> T): T {
    let previous = rememberedValueConstruction.get()
    let active = true
    rememberedValueConstruction.set(Some(active))
    try {
        factory()
    } finally {
        rememberedValueConstruction.set(previous)
    }
}

func isRememberedValueConstructionActive(): Bool {
    match (rememberedValueConstruction.get()) {
        case Some(active) => active
        case None => false
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

/** Returns explicitly keyed local State with the supplied observational-equivalence policy. */
public func rememberState<T>(
    key: String,
    policy: StateMutationPolicy<T>,
    initial: () -> T
): State<T> {
    currentStateStore().remember<T>(key, policy, initial)
}

/**
 * Returns local state at the next positional slot of the active declarative scope. Slot count is
 * guarded across rebuilds; use Keyed or the explicit-key overload for conditional/repeated state.
 */
public func rememberState<T>(initial: () -> T): State<T> {
    currentStateStore().rememberImplicit<T>(initial)
}

/** Returns positional local State with the supplied observational-equivalence policy. */
public func rememberState<T>(policy: StateMutationPolicy<T>, initial: () -> T): State<T> {
    currentStateStore().rememberImplicit<T>(policy, initial)
}

/**
 * Retains an arbitrary value at the next guarded positional slot of the active build. Use this for
 * stable controllers, formatters, animation objects, or DerivedState graphs; Resource lifetimes
 * belong in mountEffect/lifecycleEffect. Dynamic structures need Keyed or the explicit-key overload.
 */
public func remember<T>(factory: () -> T): T {
    currentStateStore().rememberImplicitValue<T>(factory)
}

/** Retains an arbitrary value under an explicit key in the active declarative scope. */
public func remember<T>(key: String, factory: () -> T): T {
    currentStateStore().rememberValue<T>(key, factory)
}
