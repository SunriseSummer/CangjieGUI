package cui.core

import std.collection.HashMap

let IDENTIFIED_ARRAY_CHUNK_SIZE: Int64 = 32
private let IDENTIFIED_ARRAY_LINEAR_LIMIT: Int64 = 32
private let IDENTIFIED_ARRAY_SEQUENTIAL_BATCH_LIMIT: Int64 = 1

/** Behavior when a routed child Action no longer has matching child state. */
public enum MissingFeaturePolicy {
    | Reject
    | Ignore
}

/** One child Action paired with the stable identity of its target collection element. */
public struct IdentifiedAction<ID, Action> {
    public let id: ID
    public let action: Action

    public init(id: ID, action: Action) {
        this.id = id
        this.action = action
    }
}

/**
 * An immutable ordered collection with a stable-ID index. Construction rejects duplicate IDs;
 * element replacement rejects identity changes, so keyed reducers and views cannot silently route
 * state to the wrong child after reorder or deletion.
 */
public struct IdentifiedArray<ID, Element> where ID <: Hashable & Equatable<ID> {
    private let chunks: Array<Array<Element>>
    private let elementCount: Int64
    private let indexById: ?HashMap<ID, Int64>
    private let identify: (Element) -> ID

    /**
     * Snapshots `elements` into persistent chunks.
     * Throws `IllegalArgumentException` when the `id` projection contains a duplicate.
     */
    public init(elements: Array<Element>, id!: (Element) -> ID) {
        let stableChunks = identifiedArrayChunks(elements)
        let validatedIndex = identifiedArrayIndex<ID, Element>(stableChunks, elements.size, id)
        chunks = stableChunks
        elementCount = elements.size
        this.identify = id
        indexById = if (elements.size <= IDENTIFIED_ARRAY_LINEAR_LIMIT) {
            None
        } else {
            Some(validatedIndex)
        }
    }

    private init(
        chunks: Array<Array<Element>>,
        elementCount: Int64,
        indexById: ?HashMap<ID, Int64>,
        identify: (Element) -> ID
    ) {
        this.chunks = chunks
        this.elementCount = elementCount
        this.indexById = indexById
        this.identify = identify
    }

    /** Number of elements in stable display order. */
    public prop size: Int64 {
        get() {
            elementCount
        }
    }

    /** Whether this collection contains no elements. */
    public func isEmpty(): Bool {
        elementCount == 0
    }

    /** Returns the element at one positional display index. */
    public func at(index: Int64): Element {
        chunks[index / IDENTIFIED_ARRAY_CHUNK_SIZE][index % IDENTIFIED_ARRAY_CHUNK_SIZE]
    }

    /** Returns the element with `id`, or None when it is absent. */
    public func get(id: ID): ?Element {
        match (indexOf(id)) {
            case Some(index) => Some(at(index))
            case None => None
        }
    }

    /** Returns the current positional index for `id`, or None when it is absent. */
    public func indexOf(id: ID): ?Int64 {
        match (indexById) {
            case Some(index) => index.get(id)
            case None =>
                for (position in 0..elementCount) {
                    if (identify(at(position)) == id) {
                        return Some(position)
                    }
                }
                None
        }
    }

    /** Returns an isolated array snapshot in display order. */
    public func toArray(): Array<Element> {
        Array<Element>(elementCount, {index => at(index)})
    }

    /**
     * Returns a collection with one element transformed, or None when `id` is absent. The transform
     * runs before any array clone; its exceptions leave this collection untouched. A returned
     * element with a different ID throws `IllegalArgumentException`.
     */
    public func updating(id: ID, transform: (Element) -> Element): ?IdentifiedArray<ID, Element> {
        match (indexOf(id)) {
            case Some(index) => Some(replacingAt(index, id, transform(at(index))))
            case None => None
        }
    }

    /* Package reducer bridge: an ordered child Action batch creates at most one collection version. */
    func reducingAll<Action>(
        actions: Array<IdentifiedAction<ID, Action>>,
        reducer: (Element, Action) -> Element,
        missing: MissingFeaturePolicy
    ): IdentifiedArray<ID, Element> {
        if (actions.isEmpty()) {
            return this
        }
        if (actions.size <= IDENTIFIED_ARRAY_SEQUENTIAL_BATCH_LIMIT) {
            return reducingSequentially(actions, reducer, missing)
        }
        let session = IdentifiedArrayUpdateSession<ID, Element>(chunks, identify)
        var applied = false
        for (identifiedAction in actions) {
            match (indexOf(identifiedAction.id)) {
                case Some(index) =>
                    session.reduceAt(index, identifiedAction, reducer)
                    applied = true
                case None => handleMissingFeature(missing, "Identified batch reducer")
            }
        }
        if (applied) {
            IdentifiedArray<ID, Element>(session.finish(), elementCount, indexById, identify)
        } else {
            this
        }
    }

    /**
     * Returns a collection with `element` appended.
     * Throws `IllegalArgumentException` when the element ID is already present. An
     * `IllegalStateException` indicates corruption of the private ID index invariant.
     */
    public func appending(element: Element): IdentifiedArray<ID, Element> {
        let id = identify(element)
        if (indexOf(id).isSome()) {
            throw IllegalArgumentException("IdentifiedArray cannot append a duplicate ID")
        }
        let nextChunks = appendingIdentifiedArrayChunk(chunks, elementCount, element)
        let nextCount = elementCount + 1
        let nextIndex: ?HashMap<ID, Int64> = match (indexById) {
            case Some(index) =>
                let cloned = index.clone()
                match (cloned.add(id, elementCount)) {
                    case Some(_) => throw IllegalStateException("IdentifiedArray stable-ID index is inconsistent")
                    case None => Some(cloned)
                }
            case None =>
                if (nextCount <= IDENTIFIED_ARRAY_LINEAR_LIMIT) {
                    None
                } else {
                    Some(identifiedArrayIndex<ID, Element>(nextChunks, nextCount, identify))
                }
        }
        IdentifiedArray<ID, Element>(nextChunks, nextCount, nextIndex, identify)
    }

    /** Returns a collection without `id`, or None when it is absent. */
    public func removing(id: ID): ?IdentifiedArray<ID, Element> {
        match (indexOf(id)) {
            case Some(removedIndex) =>
                let nextElements = Array<Element>(elementCount - 1, {
                    index => if (index < removedIndex) {
                        at(index)
                    } else {
                        at(index + 1)
                    }
                })
                Some(IdentifiedArray<ID, Element>(nextElements, id: identify))
            case None => None
        }
    }

    func replacingAt(index: Int64, expectedId: ID, element: Element): IdentifiedArray<ID, Element> {
        if (identify(element) != expectedId) {
            throw IllegalArgumentException("IdentifiedArray element updates cannot change identity")
        }
        let chunkIndex = index / IDENTIFIED_ARRAY_CHUNK_SIZE
        let elementIndex = index % IDENTIFIED_ARRAY_CHUNK_SIZE
        let nextChunks = chunks.clone()
        let nextChunk = chunks[chunkIndex].clone()
        nextChunk[elementIndex] = element
        nextChunks[chunkIndex] = nextChunk
        IdentifiedArray<ID, Element>(nextChunks, elementCount, indexById, identify)
    }

    private func reducingSequentially<Action>(
        actions: Array<IdentifiedAction<ID, Action>>,
        reducer: (Element, Action) -> Element,
        missing: MissingFeaturePolicy
    ): IdentifiedArray<ID, Element> {
        var current = this
        for (identifiedAction in actions) {
            match (current.indexOf(identifiedAction.id)) {
                case Some(index) => current = current.replacingAt(
                    index,
                    identifiedAction.id,
                    reducer(current.at(index), identifiedAction.action)
                )
                case None => handleMissingFeature(missing, "Identified batch reducer")
            }
        }
        current
    }
}

private func identifiedArrayChunks<Element>(elements: Array<Element>): Array<Array<Element>> {
    let chunkCount = (elements.size + IDENTIFIED_ARRAY_CHUNK_SIZE - 1) / IDENTIFIED_ARRAY_CHUNK_SIZE
    Array<Array<Element>>(
        chunkCount,
        {
            chunkIndex =>
                let start = chunkIndex * IDENTIFIED_ARRAY_CHUNK_SIZE
                let length = min(IDENTIFIED_ARRAY_CHUNK_SIZE, elements.size - start)
                Array<Element>(length, {offset => elements[start + offset]})
        }
    )
}

private func identifiedArrayIndex<ID, Element>(
    chunks: Array<Array<Element>>,
    elementCount: Int64,
    identify: (Element) -> ID
): HashMap<ID, Int64> where ID <: Hashable & Equatable<ID> {
    let index = HashMap<ID, Int64>(elementCount)
    for (position in 0..elementCount) {
        let element = chunks[position / IDENTIFIED_ARRAY_CHUNK_SIZE][position % IDENTIFIED_ARRAY_CHUNK_SIZE]
        if (index.add(identify(element), position).isSome()) {
            throw IllegalArgumentException("IdentifiedArray requires unique IDs")
        }
    }
    index
}

private func appendingIdentifiedArrayChunk<Element>(
    chunks: Array<Array<Element>>,
    elementCount: Int64,
    element: Element
): Array<Array<Element>> {
    if (elementCount % IDENTIFIED_ARRAY_CHUNK_SIZE == 0) {
        return Array<Array<Element>>(chunks.size + 1, {
            index => if (index < chunks.size) {
                chunks[index]
            } else {
                [element]
            }
        })
    }
    let nextChunks = chunks.clone()
    let lastIndex = chunks.size - 1
    let previous = chunks[lastIndex]
    nextChunks[lastIndex] = Array<Element>(previous.size + 1, {
        index => if (index < previous.size) {
            previous[index]
        } else {
            element
        }
    })
    nextChunks
}

func handleMissingFeature(policy: MissingFeaturePolicy, context: String): Unit {
    match (policy) {
        case MissingFeaturePolicy.Ignore => ()
        case MissingFeaturePolicy.Reject => throw IllegalStateException(
            "${context} received a child Action without matching state")
    }
}
