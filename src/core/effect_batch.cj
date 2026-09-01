package cui.core

import std.collection.ArrayList

private abstract class EffectBatchNode<Effect> {
    /** Handles a leaf without allocating a traversal stack; branches return false for expansion. */
    public func tryVisitDirect(visit: (Effect) -> Unit): Bool
    /** Pushes a branch's children in reverse visit order onto the iterative traversal stack. */
    public func expand(pending: ArrayList<EffectBatchNode<Effect>>, visit: (Effect) -> Unit): Unit
}

private class OneEffectBatchNode<Effect> <: EffectBatchNode<Effect> {
    private let effect: Effect

    init(effect: Effect) {
        this.effect = effect
    }

    public override func tryVisitDirect(visit: (Effect) -> Unit): Bool {
        visit(effect)
        true
    }

    public override func expand(_: ArrayList<EffectBatchNode<Effect>>, visit: (Effect) -> Unit): Unit {
        visit(effect)
    }
}

private class ManyEffectBatchNode<Effect> <: EffectBatchNode<Effect> {
    private let effects: Array<Effect>

    init(effects: Array<Effect>) {
        this.effects = effects
    }

    public override func tryVisitDirect(visit: (Effect) -> Unit): Bool {
        for (effect in effects) {
            visit(effect)
        }
        true
    }

    public override func expand(_: ArrayList<EffectBatchNode<Effect>>, visit: (Effect) -> Unit): Unit {
        for (effect in effects) {
            visit(effect)
        }
    }
}

private class ConcatEffectBatchNode<Effect> <: EffectBatchNode<Effect> {
    private let left: EffectBatchNode<Effect>
    private let right: EffectBatchNode<Effect>

    init(left: EffectBatchNode<Effect>, right: EffectBatchNode<Effect>) {
        this.left = left
        this.right = right
    }

    public override func tryVisitDirect(_: (Effect) -> Unit): Bool {
        false
    }

    public override func expand(pending: ArrayList<EffectBatchNode<Effect>>, _: (Effect) -> Unit): Unit {
        pending.add(right)
        pending.add(left)
    }
}

/**
 * An immutable, ordered batch of domain effect descriptions. Concatenation is O(1); iteration and
 * materialization flatten the persistent concatenation tree without recursive stack growth.
 */
public struct EffectBatch<Effect> {
    private let root: ?EffectBatchNode<Effect>
    private let effectCount: Int64

    /** Creates the empty effect batch. */
    public init() {
        root = None
        effectCount = 0
    }

    /** Creates a singleton effect batch. */
    public init(effect: Effect) {
        root = Some(OneEffectBatchNode<Effect>(effect))
        effectCount = 1
    }

    /** Creates a batch from a snapshot of `effects`. */
    public init(effects: Array<Effect>) {
        let stable = effects.clone()
        root = if (stable.isEmpty()) {
            None
        } else {
            Some(ManyEffectBatchNode<Effect>(stable))
        }
        effectCount = stable.size
    }

    private init(root: ?EffectBatchNode<Effect>, effectCount: Int64) {
        this.root = root
        this.effectCount = effectCount
    }

    private init(ownedEffects: Array<Effect>, takeOwnership!: Bool) {
        let stable = if (takeOwnership) {
            ownedEffects
        } else {
            ownedEffects.clone()
        }
        root = if (stable.isEmpty()) {
            None
        } else {
            Some(ManyEffectBatchNode<Effect>(stable))
        }
        effectCount = stable.size
    }

    /** Number of effect descriptions in this batch. */
    public prop size: Int64 {
        get() {
            effectCount
        }
    }

    /** Returns whether this batch has no effects. */
    public func isEmpty(): Bool {
        effectCount == 0
    }

    /**
     * Returns the ordered concatenation of this batch and `next`. Empty batches are identities and
     * do not allocate a concatenation node. `IllegalStateException` is reserved for corruption of
     * the private root/count invariant; it cannot be produced by a valid public constructor.
     */
    public func then(next: EffectBatch<Effect>): EffectBatch<Effect> {
        if (isEmpty()) {
            return next
        }
        if (next.isEmpty()) {
            return this
        }
        let left = match (root) {
            case Some(node) => node
            case None => throw IllegalStateException("Non-empty EffectBatch requires a root node")
        }
        let right = match (next.root) {
            case Some(node) => node
            case None => throw IllegalStateException("Non-empty EffectBatch requires a root node")
        }
        EffectBatch<Effect>(Some(ConcatEffectBatchNode<Effect>(left, right)), effectCount + next.effectCount)
    }

    /** Visits effects once in declaration order. */
    public func forEach(visit: (Effect) -> Unit): Unit {
        visitEffectBatchNode(root, visit)
    }

    /** Returns an independent, ordered materialization of this batch. */
    public func toArray(): Array<Effect> {
        let effects = ArrayList<Effect>(effectCount)
        forEach({effect => effects.add(effect)})
        effects.toArray()
    }

    /** Maps effect descriptions without changing their order. */
    public func map<Mapped>(transform: (Effect) -> Mapped): EffectBatch<Mapped> {
        let mapped = ArrayList<Mapped>(effectCount)
        forEach({effect => mapped.add(transform(effect))})
        EffectBatch<Mapped>(mapped.toArray(), takeOwnership: true)
    }
}

private func visitEffectBatchNode<Effect>(root: ?EffectBatchNode<Effect>, visit: (Effect) -> Unit): Unit {
    match (root) {
        case None => return
        case Some(node) =>
            if (node.tryVisitDirect(visit)) {
                return
            }
            let pending = ArrayList<EffectBatchNode<Effect>>()
            pending.add(node)
            while (!pending.isEmpty()) {
                let current = pending.remove(at: pending.size - 1)
                if (!current.tryVisitDirect(visit)) {
                    current.expand(pending, visit)
                }
            }
    }
}

/** A pure reducer result: one next model and an ordered batch of effects to interpret later. */
public struct Transition<Model, Effect> {
    public let model: Model
    public let effects: EffectBatch<Effect>

    /** Creates a transition without effects. */
    public init(model: Model) {
        this.model = model
        effects = EffectBatch<Effect>()
    }

    /** Creates a transition with one effect. */
    public init(model: Model, effect!: Effect) {
        this.model = model
        effects = EffectBatch<Effect>(effect)
    }

    /** Creates a transition with an existing immutable effect batch. */
    public init(model: Model, effects!: EffectBatch<Effect>) {
        this.model = model
        this.effects = effects
    }

    /** Maps effect descriptions while preserving the next model and effect order. */
    public func mapEffects<Mapped>(transform: (Effect) -> Mapped): Transition<Model, Mapped> {
        Transition<Model, Mapped>(model, effects: effects.map(transform))
    }
}
