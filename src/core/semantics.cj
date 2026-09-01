package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.Rect

/** The platform-independent accessibility role exposed by a semantic node. */
public enum SemanticsRole {
    | Generic
    | Text
    | Button
    | TextField
    | Checkbox
    | Switch
    | Slider
    | List
    | ListItem
    | Image
    | Dialog
    | Menu
    | MenuItem
}

/** An accessibility action requested by a platform adapter or deterministic test. */
public enum SemanticsAction {
    | Activate
    | Focus
    | Increment
    | Decrement
    | SetValue(String)
}

/** Immutable semantic properties, independent of pixels and native accessibility APIs. */
public class Semantics {
    public let label: String
    public let role: SemanticsRole
    public let value: String
    public let hint: String
    public let enabled: Bool
    public let selected: ?Bool
    public let checked: ?Bool

    public init(
        label!: String = "",
        role!: SemanticsRole = SemanticsRole.Generic,
        value!: String = "",
        hint!: String = "",
        enabled!: Bool = true,
        selected!: ?Bool = None,
        checked!: ?Bool = None
    ) {
        this.label = label
        this.role = role
        this.value = value
        this.hint = hint
        this.enabled = enabled
        this.selected = selected
        this.checked = checked
    }

    func forcingDisabled(): Semantics {
        if (!enabled) {
            return this
        }
        Semantics(label: label, role: role, value: value, hint: hint, enabled: false, selected: selected,
            checked: checked)
    }
}

/** One resolved accessibility node in declaration/layout order. */
public class SemanticsNode {
    public let id: String
    public let properties: Semantics
    public let bounds: Rect
    public let visibleBounds: Rect
    public let actions: Array<SemanticsAction>

    /**
     * Creates a resolved semantic node.
     * Throws `IllegalArgumentException` when `id` is empty.
     */
    public init(
        id: String,
        properties: Semantics,
        bounds: Rect,
        actions!: Array<SemanticsAction> = [],
        visibleBounds!: ?Rect = None
    ) {
        if (id.isEmpty()) {
            throw IllegalArgumentException("Semantics id must not be empty")
        }
        this.id = id
        this.properties = properties
        this.bounds = bounds
        this.visibleBounds = match (visibleBounds) {
            case Some(value) => value
            case None => bounds
        }
        this.actions = actions
    }
}

/* A composable contribution to the retained semantic tree. */
interface SemanticContribution {
    func collect(
        nodes: ArrayList<SemanticsNode>,
        indexById: HashMap<String, Int64>,
        actionsById: HashMap<String, SemanticActionTarget>,
        ownersById: HashMap<String, ElementId>,
        forcedDisabled: Bool
    ): Unit
    func dispatch(id: String, action: SemanticsAction, forcedDisabled: Bool): ?Bool
    func forcingDisabled(): SemanticContribution
}

/* Cached leaf registration; the provider keeps dynamic values out of layout dependencies. */
class SemanticRegistration <: SemanticContribution {
    let id: String
    let owner: ElementId
    let bounds: Rect
    let visibleBounds: Rect
    let actions: Array<SemanticsAction>
    private let properties: () -> Semantics
    private let perform: (SemanticsAction) -> Bool
    private let invalidate: () -> Unit
    private var resolved: ?Semantics = None
    private var dependencies: ?PhaseStateDependencies = None
    private var dirty = true

    init(
        id: String,
        owner: ElementId,
        bounds: Rect,
        visibleBounds: Rect,
        actions: Array<SemanticsAction>,
        properties: () -> Semantics,
        perform: (SemanticsAction) -> Bool,
        invalidate: () -> Unit
    ) {
        this.id = id
        this.owner = owner
        this.bounds = bounds
        this.visibleBounds = visibleBounds
        this.actions = actions
        this.properties = properties
        this.perform = perform
        this.invalidate = invalidate
    }

    private func snapshot(forcedDisabled: Bool): SemanticsNode {
        let value = resolvedProperties()
        SemanticsNode(id, if (forcedDisabled) {
            value.forcingDisabled()
        } else {
            value
        }, bounds, actions: actions, visibleBounds: Some(visibleBounds))
    }

    /** Appends or replaces this id in one flattened platform snapshot. */
    public func collect(
        nodes: ArrayList<SemanticsNode>,
        indexById: HashMap<String, Int64>,
        actionsById: HashMap<String, SemanticActionTarget>,
        ownersById: HashMap<String, ElementId>,
        forcedDisabled: Bool
    ): Unit {
        let node = snapshot(forcedDisabled)
        match (indexById.get(id)) {
            case Some(index) => nodes[index] = node
            case None =>
                let index = nodes.size
                nodes.add(node)
                let _ = indexById.add(id, index) // cjcheck-ignore: ignore-result # absent id was checked above
        }
        let target = SemanticActionTarget(this, forcedDisabled)
        match (actionsById.add(id, target)) {
            case Some(previous) =>
                if (!previous.sameRegistration(target)) {
                    previous.close()
                }
            case None => ()
        }
        let _ = ownersById.add(id, owner) // cjcheck-ignore: ignore-result # the latest normalized registration owns this id
    }

    /** Dispatches only when `id` matches this leaf, preserving disabled semantics. */
    public func dispatch(target: String, action: SemanticsAction, forcedDisabled: Bool): ?Bool {
        if (target != id) {
            return None
        }
        // Property resolution may collect State reads. Forced-disabled fragments deliberately skip
        // that effect; otherwise resolve exactly once before deciding whether to run the action.
        let isEnabled = if (forcedDisabled) {
            false
        } else {
            resolvedProperties().enabled
        }
        if (!isEnabled) {
            return Some(false) // cjcheck-ignore: bool-literal-arg # Option payload is the disabled action result, not a mode flag
        }
        Some(perform(action))
    }

    /** Returns a zero-copy disabled view over this contribution. */
    public func forcingDisabled(): SemanticContribution {
        DisabledSemanticContribution(this)
    }

    func close(): Unit {
        match (dependencies) {
            case Some(value) => value.close()
            case None => ()
        }
        dependencies = None
        resolved = None
        dirty = true
    }

    private func resolvedProperties(): Semantics {
        if (!dirty) {
            match (resolved) {
                case Some(value) => return value
                case None => ()
            }
        }
        let stateDependencies = semanticStateDependencies()
        let value = collectPhaseStateReads(stateDependencies, {=> properties()})
        resolved = Some(value)
        dirty = stateDependencies.collectionWasInvalidated
        value
    }

    private func semanticStateDependencies(): PhaseStateDependencies {
        match (dependencies) {
            case Some(value) => value
            case None =>
                let value = PhaseStateDependencies({=> invalidateProperties()})
                dependencies = Some(value)
                value
        }
    }

    private func invalidateProperties(): Unit {
        dirty = true
        invalidate()
    }
}

/*
 * A retained semantic patch. Composition is associative concatenation; cached layout replays one
 * fragment reference, while flattening to a platform snapshot is paid only by an actual query.
 */
class SemanticFragment <: SemanticContribution {
    private let children: Array<SemanticContribution>

    init(children: Array<SemanticContribution>) {
        this.children = children
    }

    /** Flattens child contributions in declaration order. */
    public func collect(
        nodes: ArrayList<SemanticsNode>,
        indexById: HashMap<String, Int64>,
        actionsById: HashMap<String, SemanticActionTarget>,
        ownersById: HashMap<String, ElementId>,
        forcedDisabled: Bool
    ): Unit {
        for (child in children) {
            child.collect(nodes, indexById, actionsById, ownersById, forcedDisabled)
        }
    }

    /** Searches newest declarations first so an explicit outer override wins. */
    public func dispatch(id: String, action: SemanticsAction, forcedDisabled: Bool): ?Bool {
        var index = children.size - 1
        while (index >= 0) {
            match (children[index].dispatch(id, action, forcedDisabled)) {
                case Some(result) => return Some(result)
                case None => ()
            }
            index -= 1
        }
        None
    }

    /** Returns a zero-copy disabled view over this fragment. */
    public func forcingDisabled(): SemanticContribution {
        DisabledSemanticContribution(this)
    }
}

class DisabledSemanticContribution <: SemanticContribution {
    private let child: SemanticContribution

    init(child: SemanticContribution) {
        this.child = child
    }

    /** Flattens the wrapped contribution with disabled state forced on. */
    public func collect(
        nodes: ArrayList<SemanticsNode>,
        indexById: HashMap<String, Int64>,
        actionsById: HashMap<String, SemanticActionTarget>,
        ownersById: HashMap<String, ElementId>,
        _: Bool
    ): Unit {
        child.collect(nodes, indexById, actionsById, ownersById, true) // cjcheck-ignore: bool-literal-arg # disabled wrapper intentionally forces the inherited state
    }

    /** Rejects actions while retaining id lookup. */
    public func dispatch(id: String, action: SemanticsAction, _: Bool): ?Bool {
        child.dispatch(id, action, true) // cjcheck-ignore: bool-literal-arg # disabled wrapper intentionally rejects descendant actions
    }

    /** Reuses the existing disabled view. */
    public func forcingDisabled(): SemanticContribution {
        this
    }
}

/* O(1) committed action lookup while preserving the provider's latest dynamic enabled state. */
class SemanticActionTarget {
    private let registration: SemanticRegistration
    private let forcedDisabled: Bool

    init(registration: SemanticRegistration, forcedDisabled: Bool) {
        this.registration = registration
        this.forcedDisabled = forcedDisabled
    }

    func perform(action: SemanticsAction): Bool {
        match (registration.dispatch(registration.id, action, forcedDisabled)) {
            case Some(result) => result
            case None => false
        }
    }

    func sameRegistration(other: SemanticActionTarget): Bool {
        if (let Some(left) <- (registration as Object)) {
            if (let Some(right) <- (other.registration as Object)) {
                return refEq(left, right)
            }
        }
        false
    }

    func close(): Unit {
        registration.close()
    }
}
