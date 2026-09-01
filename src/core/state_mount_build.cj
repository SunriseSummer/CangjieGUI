package cui.core

import std.collection.{ArrayList, HashMap, HashSet}

private let BUILD_LOCAL_LINEAR_LIMIT: Int64 = 8

/* Build-local transaction for one mount scope; persistent ownership changes only at root commit. */
class StateMountBuild {
    var scope: StateMountScope
    let stateKeys = ArrayList<String>()
    let retainedKeys = ArrayList<String>()
    let automaticKeys = ArrayList<String>()
    let effectKeys = ArrayList<String>()
    var hasExternalRetainedRevision = false
    var hasExternalEffectRevision = false
    private var stateKeyIndex: ?HashSet<String> = None
    private var retainedKeyIndex: ?HashSet<String> = None
    private var automaticKeyIndex: ?HashSet<String> = None
    private var effectKeyIndex: ?HashSet<String> = None
    private var collectStateReads: Bool
    private var invalidate: () -> Unit
    /* Frozen at logical-transaction start; the scope publishes a replacement only after commit. */
    private var committedDependencies: ?CommittedBuildDependencies
    private let dependencies = ArrayList<ObservableReadDependency>()
    private var dependencySources: ?HashSet<UInt64> = None
    private let newDependencies = ArrayList<ObservableReadDependency>()
    private var committedPrefixActive = true
    private var derivedReadDepth: Int64 = 0
    private var dirtyVersionAtStart: UInt64
    var forceAutomaticDescendants: Bool
    var automaticSubtreeWeight: Int64
    var automaticMaxBranching: Int64 = 0
    private var implicitSlots: ?HashMap<String, ImplicitSlotCursor> = None

    init(
        scope: StateMountScope,
        collectStateReads!: Bool,
        invalidate!: () -> Unit,
        forceAutomaticDescendants!: Bool = false,
        automaticSubtreeWeight!: Int64 = 0
    ) {
        this.scope = scope
        this.collectStateReads = collectStateReads
        this.invalidate = invalidate
        this.committedDependencies = scope.committedBuildDependencies()
        this.dirtyVersionAtStart = scope.dirtyVersion
        this.forceAutomaticDescendants = forceAutomaticDescendants
        this.automaticSubtreeWeight = automaticSubtreeWeight
    }

    /*
     * Starts another logical transaction in a pooled frame-arena cell. The canonical logs are
     * physically reused, but committed ownership continues to live only on StateMountScope.
     */
    func restart(
        scope: StateMountScope,
        collectStateReads!: Bool,
        invalidate!: () -> Unit,
        forceAutomaticDescendants!: Bool = false,
        automaticSubtreeWeight!: Int64 = 0
    ): Unit {
        if (!newDependencies.isEmpty()) {
            throw IllegalStateException("Mount build transaction was reused before its staged dependencies were closed")
        }
        stateKeys.clear()
        retainedKeys.clear()
        automaticKeys.clear()
        effectKeys.clear()
        hasExternalRetainedRevision = false
        hasExternalEffectRevision = false
        stateKeyIndex = None
        retainedKeyIndex = None
        automaticKeyIndex = None
        effectKeyIndex = None
        dependencies.clear()
        dependencySources = None
        committedPrefixActive = true
        derivedReadDepth = 0
        this.scope = scope
        this.collectStateReads = collectStateReads
        this.invalidate = invalidate
        committedDependencies = scope.committedBuildDependencies()
        dirtyVersionAtStart = scope.dirtyVersion
        this.forceAutomaticDescendants = forceAutomaticDescendants
        this.automaticSubtreeWeight = automaticSubtreeWeight
        automaticMaxBranching = 0
        implicitSlots = None
    }

    func visitState(path: String, identity: String): Unit {
        let (duplicate, nextIndex) = registerDeclarationKey(stateKeys, stateKeyIndex, path, scope.stateKeyCount())
        stateKeyIndex = nextIndex
        if (duplicate) {
            throw IllegalStateException("Duplicate remembered state ${identity} in the same scope")
        }
        stateKeys.add(path)
    }

    func registerImplicitSlotScope(namespace: String): Unit {
        match (scope.committedImplicitSlotShapes()) {
            case Some(committed) => match (committed.get(namespace)) {
                case Some(shape) => registerImplicitSlotCursor(namespace, Some(shape))
                case None => ()
            }
            case None => ()
        }
    }

    func implicitSlotCursor(namespace: String): ImplicitSlotCursor {
        let slots = implicitSlotMap()
        match (slots.get(namespace)) {
            case Some(cursor) => cursor
            case None =>
                let committed: ?ImplicitSlotShape = match (scope.committedImplicitSlotShapes()) {
                    case Some(shapes) => shapes.get(namespace)
                    case None => None
                }
                let cursor = ImplicitSlotCursor(namespace, committed)
                let _ = slots.add(namespace, cursor) // cjcheck-ignore: ignore-result # namespace was checked absent immediately above
                cursor
        }
    }

    func validateImplicitSlotShape(): Unit {
        match (implicitSlots) {
            case Some(current) => for ((namespace, cursor) in current) {
                match (scope.committedImplicitSlotShapes()) {
                    case Some(committed) => match (committed.get(namespace)) {
                        case Some(previous) where previous.paths.size != cursor.count => throw IllegalStateException(
                            "Keyless rememberState slot count changed in '${scope.diagnosticPath}' from ${previous.paths.size} to ${cursor.count}; keep positional slots unconditional, or wrap dynamic state in Keyed/use an explicit key")
                        case _ => ()
                    }
                    case None => ()
                }
            }
            case None => ()
        }
    }

    func commitImplicitSlotShape(ownership: CommittedMountOwnership): Unit {
        match (implicitSlots) {
            case Some(current) =>
                let committed: HashMap<String, ImplicitSlotShape> = match (ownership.implicitSlotShapes) {
                    case Some(existing) =>
                        existing.clear()
                        existing
                    case None => HashMap<String, ImplicitSlotShape>()
                }
                for ((namespace, cursor) in current) {
                    let _ = committed.add(namespace, cursor.committedShape()) // cjcheck-ignore: ignore-result # target map was cleared before rebuilding the committed shape
                }
                ownership.implicitSlotShapes = Some(committed)
            case None => ownership.implicitSlotShapes = None
        }
    }

    func hasCommittedImplicitSlotShapes(): Bool {
        scope.hasCommittedImplicitSlotShapes()
    }

    private func registerImplicitSlotCursor(namespace: String, committed: ?ImplicitSlotShape): Unit {
        let slots = implicitSlotMap()
        if (slots.get(namespace).isNone()) {
            let _ = slots.add(namespace, ImplicitSlotCursor(namespace, committed)) // cjcheck-ignore: ignore-result # namespace absence is the branch precondition
        }
    }

    private func implicitSlotMap(): HashMap<String, ImplicitSlotCursor> {
        match (implicitSlots) {
            case Some(slots) => slots
            case None =>
                let slots = HashMap<String, ImplicitSlotCursor>()
                implicitSlots = Some(slots)
                slots
        }
    }

    func visitRetained(path: String, key: String, hasExternalRevision: Bool): Unit {
        let (duplicate, nextIndex) = registerDeclarationKey(retainedKeys, retainedKeyIndex, path,
            scope.retainedKeyCount())
        retainedKeyIndex = nextIndex
        if (duplicate) {
            throw IllegalStateException("Duplicate retained subtree key '${key}' in the same scope")
        }
        retainedKeys.add(path)
        hasExternalRetainedRevision = hasExternalRetainedRevision || hasExternalRevision
    }

    func visitAutomatic(path: String, key: String): Unit {
        let (duplicate, nextIndex) = registerDeclarationKey(automaticKeys, automaticKeyIndex, path,
            scope.automaticKeyCount())
        automaticKeyIndex = nextIndex
        if (duplicate) {
            throw IllegalStateException("Duplicate automatic composition identity '${key}' in the same scope")
        }
        automaticKeys.add(path)
        automaticMaxBranching = max(automaticMaxBranching, automaticKeys.size)
    }

    func visitEffect(path: String, key: String, hasExternalRevision: Bool): Unit {
        let (duplicate, nextIndex) = registerDeclarationKey(effectKeys, effectKeyIndex, path, scope.effectKeyCount())
        effectKeyIndex = nextIndex
        if (duplicate) {
            throw IllegalStateException("Duplicate lifecycle effect key '${key}' in the same scope")
        }
        effectKeys.add(path)
        hasExternalEffectRevision = hasExternalEffectRevision || hasExternalRevision
    }

    func containsState(path: String): Bool {
        containsDeclarationKey(stateKeys, stateKeyIndex, path)
    }

    func containsRetained(path: String): Bool {
        containsDeclarationKey(retainedKeys, retainedKeyIndex, path)
    }

    func containsAutomatic(path: String): Bool {
        containsDeclarationKey(automaticKeys, automaticKeyIndex, path)
    }

    func containsEffect(path: String): Bool {
        containsDeclarationKey(effectKeys, effectKeyIndex, path)
    }

    func hasOwnershipDeclarations(): Bool {
        !stateKeys.isEmpty() || !retainedKeys.isEmpty() || !automaticKeys.isEmpty() || !effectKeys.isEmpty()
    }

    func absorbAutomaticSubtree(weight: Int64, maxBranching: Int64): Unit {
        automaticSubtreeWeight += weight
        automaticMaxBranching = max(automaticMaxBranching, maxBranching)
    }

    func readState<T>(source: State<T>): Unit {
        if (!collectStateReads || derivedReadDepth > 0) {
            return
        }
        let identity = source.dependencyIdentity()
        if (reuseDependency(identity)) {
            return
        }
        let dependency = TypedStateReadDependency<T>(source, invalidate)
        dependencies.add(dependency)
        newDependencies.add(dependency)
    }

    func beginDerivedRead<T>(source: DerivedState<T>): Bool {
        if (!collectStateReads) {
            return false
        }
        let shouldRead = derivedReadDepth == 0
        derivedReadDepth += 1
        if (shouldRead) {
            try {
                readDerived(source)
            } catch (error: Exception) {
                derivedReadDepth = leaveDerivedReadDepth(derivedReadDepth, "build")
                throw error
            }
        }
        true
    }

    func endDerivedRead(): Unit {
        derivedReadDepth = leaveDerivedReadDepth(derivedReadDepth, "build")
    }

    private func readDerived<T>(source: DerivedState<T>): Unit {
        let identity = source.dependencyIdentity()
        if (reuseDependency(identity)) {
            return
        }
        let dependency = TypedDerivedReadDependency<T>(source, invalidate)
        dependencies.add(dependency)
        newDependencies.add(dependency)
    }

    private func reuseDependency(identity: UInt64): Bool {
        if (reuseCommittedPrefix(identity)) {
            return true
        }
        if (!markDependencySource(identity)) {
            return true
        }
        match (committedDependency(identity)) {
            case Some(dependency) =>
                dependencies.add(dependency)
                true
            case None => false
        }
    }

    private func committedDependency(identity: UInt64): ?ObservableReadDependency {
        match (committedDependencies) {
            case Some(committed) => committed.get(identity)
            case None => None
        }
    }

    /*
     * Stable declarative bodies overwhelmingly read the same dependency trace in the same order.
     * Zip that trace with the committed canonical frontier before paying for transient and
     * persistent hash lookups. The first mismatch switches monotonically to the general set path;
     * duplicate, reordered, inserted, and removed reads therefore keep the existing semantics.
     */
    private func reuseCommittedPrefix(identity: UInt64): Bool {
        if (!committedPrefixActive) {
            return false
        }
        match (committedDependencies) {
            case Some(committed) =>
                if (dependencies.size < committed.dependencies.size) {
                    let candidate = committed.dependencies[dependencies.size]
                    if (candidate.sourceIdentity == identity) {
                        dependencies.add(candidate)
                        return true
                    }
                }
            case None => ()
        }
        committedPrefixActive = false
        false
    }

    private func markDependencySource(identity: UInt64): Bool {
        match (dependencySources) {
            case Some(indexed) => indexed.add(identity)
            case None =>
                for (dependency in dependencies) {
                    if (dependency.sourceIdentity == identity) {
                        return false
                    }
                }
                if (dependencies.size < BUILD_LOCAL_LINEAR_LIMIT) {
                    return true
                }
                let expectedWidth = max(Int64(16), scope.buildDependencyCount())
                let indexed = HashSet<UInt64>(max(expectedWidth, dependencies.size * 2))
                for (dependency in dependencies) {
                    let _ = indexed.add(dependency.sourceIdentity) // cjcheck-ignore: ignore-result # dependencies is already a unique canonical frontier
                }
                let added = indexed.add(identity)
                dependencySources = Some(indexed)
                added
        }
    }

    private func containsDependencySource(identity: UInt64): Bool {
        match (dependencySources) {
            case Some(indexed) => indexed.contains(identity)
            case None =>
                for (dependency in dependencies) {
                    if (dependency.sourceIdentity == identity) {
                        return true
                    }
                }
                false
        }
    }

    /** Internal invariant probe for the adaptive dependency-frontier threshold tests. */
    public func usesIndexedDependencySources(): Bool {
        dependencySources.isSome()
    }

    func commitStateReads(): Unit {
        if (!collectStateReads) {
            return
        }
        let frontierUnchanged = match (committedDependencies) {
            case Some(committed) => newDependencies.isEmpty() && dependencies.size == committed.dependencies.size
            case None => false
        }
        if (!frontierUnchanged) {
            match (committedDependencies) {
                case Some(committed) => for (previous in committed.dependencies) {
                    if (!containsDependencySource(previous.sourceIdentity)) {
                        previous.close()
                    }
                }
                case None => ()
            }
            if (dependencies.isEmpty()) {
                scope.buildDependencyFacet = None
            } else {
                let committed = scope.ensureBuildDependencies()
                committed.replaceWith(dependencies)
            }
        }
        newDependencies.clear()
        let invalidatedDuringBuild = scope.dirtyVersion != dirtyVersionAtStart
        scope.buildDirty = invalidatedDuringBuild
        if (!invalidatedDuringBuild) {
            scope.buildSelfDirty = false
            scope.buildDescendantDirty = false
            scope.buildDirtyReason = ""
        }
    }

    func cancelStateReads(): Unit {
        for (dependency in newDependencies) {
            dependency.close()
        }
        newDependencies.clear()
    }
}

private func registerDeclarationKey(
    keys: ArrayList<String>,
    currentIndex: ?HashSet<String>,
    key: String,
    committedWidth: Int64
): (Bool, ?HashSet<String>) {
    match (currentIndex) {
        case Some(indexed) => (!indexed.add(key), Some(indexed))
        case None =>
            if (containsLinearKey(keys, key)) {
                return (true, None)
            }
            if (keys.size < BUILD_LOCAL_LINEAR_LIMIT) {
                return (false, None)
            }
            let expectedWidth = max(Int64(16), committedWidth)
            let indexed = HashSet<String>(max(expectedWidth, keys.size * 2))
            for (existing in keys) {
                let _ = indexed.add(existing) // cjcheck-ignore: ignore-result # canonical declaration keys are unique before promotion
            }
            let _ = indexed.add(key) // cjcheck-ignore: ignore-result # linear duplicate check above proved this key absent
            (false, Some(indexed))
    }
}

private func containsDeclarationKey(
    keys: ArrayList<String>,
    index: ?HashSet<String>,
    key: String
): Bool {
    match (index) {
        case Some(indexed) => indexed.contains(key)
        case None => containsLinearKey(keys, key)
    }
}

private func containsLinearKey(keys: ArrayList<String>, key: String): Bool {
    for (existing in keys) {
        if (existing == key) {
            return true
        }
    }
    false
}
