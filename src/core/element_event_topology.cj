package cui.core

/*
 * Complete owner-side transaction state for one child event topology. StagingCurrent aliases the
 * committed topology by construction; StagingReplacement keeps the old read face and new write
 * face distinct until the surrounding ElementLayoutCommit publishes atomically.
 */
enum ElementEventTopologyState {
    | Empty
    | Cached(ChildEventTopology)
    | Current(ChildEventTopology)
    | CurrentWithCached(ChildEventTopology, ChildEventTopology)
    | StagingInitial(ChildEventTopology)
    | StagingCurrent(ChildEventTopology)
    | StagingReplacement(ChildEventTopology, ChildEventTopology)
}

extend ElementSceneSpace {
    func eventTopology(childCount: Int64): ChildEventTopology {
        ensureAlive("resolve child event topology")
        match (matchingStagedEventTopology(childCount)) {
            case Some(value) => return value
            case None => discardEventTopologyStaging()
        }
        stageEventTopologyFromStableState(childCount)
    }

    func stagedEventTopologyCommit(): ElementEventTopologyCommit {
        ensureAlive("capture staged child event topology")
        let topology = match (eventTopologyState) {
            case ElementEventTopologyState.StagingInitial(value) => value
            case ElementEventTopologyState.StagingCurrent(value) => value
            case ElementEventTopologyState.StagingReplacement(_, value) => value
            case _ => throw IllegalStateException("No child event topology participated in this layout")
        }
        if (!topology.hasStagedLayout()) {
            throw IllegalStateException("Child event topology layout has not completed")
        }
        ElementEventTopologyCommit.Replace(topology)
    }

    func discardStagedEventTopology(): Unit {
        ensureAlive("discard staged child event topology")
        discardEventTopologyStaging()
    }

    internal func publishEventTopology(value: ElementEventTopologyCommit): Unit {
        match (value) {
            case ElementEventTopologyCommit.Preserve => ()
            case ElementEventTopologyCommit.Clear => closeElementEventTopologies(this)
            case ElementEventTopologyCommit.Replace(topology) => publishStagedEventTopology(topology)
        }
    }

    private func matchingStagedEventTopology(childCount: Int64): ?ChildEventTopology {
        match (eventTopologyState) {
            case ElementEventTopologyState.StagingInitial(value) where value.childCount() == childCount => Some(value)
            case ElementEventTopologyState.StagingCurrent(value) where value.childCount() == childCount => Some(value)
            case ElementEventTopologyState.StagingReplacement(_, value) where value.childCount() == childCount => Some(
                value)
            case _ => None
        }
    }

    private func discardEventTopologyStaging(): Unit {
        match (eventTopologyState) {
            case ElementEventTopologyState.StagingInitial(value) =>
                value.discardStagedLayout()
                eventTopologyState = ElementEventTopologyState.Cached(value)
            case ElementEventTopologyState.StagingCurrent(value) =>
                value.discardStagedLayout()
                eventTopologyState = ElementEventTopologyState.Current(value)
            case ElementEventTopologyState.StagingReplacement(current, pending) =>
                pending.discardStagedLayout()
                eventTopologyState = ElementEventTopologyState.CurrentWithCached(current, pending)
            case _ => ()
        }
    }

    private func stageEventTopologyFromStableState(childCount: Int64): ChildEventTopology {
        match (eventTopologyState) {
            case ElementEventTopologyState.Empty => stageInitialEventTopology(childCount)
            case ElementEventTopologyState.Cached(pending) => stageCachedEventTopology(pending, childCount)
            case ElementEventTopologyState.Current(current) => stageCurrentEventTopology(current, childCount)
            case ElementEventTopologyState.CurrentWithCached(current, pending) => stageCurrentWithCachedEventTopology(
                current, pending, childCount)
            case _ => throw IllegalStateException("Event topology staging state did not normalize")
        }
    }

    private func stageCachedEventTopology(pending: ChildEventTopology, childCount: Int64): ChildEventTopology {
        if (pending.childCount() == childCount) {
            eventTopologyState = ElementEventTopologyState.StagingInitial(pending)
            return pending
        }
        pending.close()
        stageInitialEventTopology(childCount)
    }

    private func stageCurrentEventTopology(current: ChildEventTopology, childCount: Int64): ChildEventTopology {
        if (current.childCount() == childCount) {
            eventTopologyState = ElementEventTopologyState.StagingCurrent(current)
            return current
        }
        stageReplacementEventTopology(current, childCount)
    }

    private func stageCurrentWithCachedEventTopology(
        current: ChildEventTopology,
        pending: ChildEventTopology,
        childCount: Int64
    ): ChildEventTopology {
        if (current.childCount() == childCount) {
            pending.close()
            eventTopologyState = ElementEventTopologyState.StagingCurrent(current)
            return current
        }
        if (pending.childCount() == childCount) {
            eventTopologyState = ElementEventTopologyState.StagingReplacement(current, pending)
            return pending
        }
        pending.close()
        stageReplacementEventTopology(current, childCount)
    }

    private func stageInitialEventTopology(childCount: Int64): ChildEventTopology {
        let topology = ChildEventTopology(childCount, deferredPublication: true)
        eventTopologyState = ElementEventTopologyState.StagingInitial(topology)
        topology
    }

    private func stageReplacementEventTopology(
        current: ChildEventTopology,
        childCount: Int64
    ): ChildEventTopology {
        let pending = ChildEventTopology(childCount, deferredPublication: true)
        eventTopologyState = ElementEventTopologyState.StagingReplacement(current, pending)
        pending
    }

    private func publishStagedEventTopology(topology: ChildEventTopology): Unit {
        match (eventTopologyState) {
            case ElementEventTopologyState.StagingInitial(staged) where refEq(staged, topology) =>
                topology.publishStagedLayout()
                eventTopologyState = ElementEventTopologyState.Current(topology)
            case ElementEventTopologyState.StagingCurrent(staged) where refEq(staged, topology) =>
                topology.publishStagedLayout()
                eventTopologyState = ElementEventTopologyState.Current(topology)
            case ElementEventTopologyState.StagingReplacement(current, staged) where refEq(staged, topology) =>
                topology.publishStagedLayout()
                current.close()
                eventTopologyState = ElementEventTopologyState.Current(topology)
            case _ => throw IllegalStateException("Layout commit contains an event topology not staged by this Element")
        }
    }
}

func committedEventTopologyFor(space: ElementSceneSpace): ?ChildEventTopology {
    match (space.eventTopologyState) {
        case ElementEventTopologyState.Current(value) => Some(value)
        case ElementEventTopologyState.CurrentWithCached(current, _) => Some(current)
        case ElementEventTopologyState.StagingCurrent(value) => Some(value)
        case ElementEventTopologyState.StagingReplacement(current, _) => Some(current)
        case _ => None
    }
}

func closeElementEventTopologies(space: ElementSceneSpace): Unit {
    match (space.eventTopologyState) {
        case ElementEventTopologyState.Empty => ()
        case ElementEventTopologyState.Cached(value) => value.close()
        case ElementEventTopologyState.Current(value) => value.close()
        case ElementEventTopologyState.CurrentWithCached(current, cached) =>
            current.close()
            cached.close()
        case ElementEventTopologyState.StagingInitial(value) => value.close()
        case ElementEventTopologyState.StagingCurrent(value) => value.close()
        case ElementEventTopologyState.StagingReplacement(current, staged) =>
            current.close()
            staged.close()
    }
    space.eventTopologyState = ElementEventTopologyState.Empty
}
