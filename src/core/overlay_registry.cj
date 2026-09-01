package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.UiEvent

/* Immutable declaration fragment and its ordered last-owner-wins active stack. */
class OverlaySnapshot {
    let registrations: Array<Overlay>
    let overlays: Array<Overlay>
    private let indexByOwner: HashMap<String, Int64>

    init(
        registrations: Array<Overlay>,
        overlays: Array<Overlay>,
        indexByOwner: HashMap<String, Int64>
    ) {
        this.registrations = registrations
        this.overlays = overlays
        this.indexByOwner = indexByOwner
    }

    func indexFor(owner: String): ?Int64 {
        indexByOwner.get(owner)
    }
}

func overlaySnapshotFromRegistrations(registrations: Array<Overlay>): OverlaySnapshot {
    let overlays = ArrayList<Overlay>()
    let indexByOwner = HashMap<String, Int64>()
    for (overlay in registrations) {
        if (!overlay.owner.isEmpty()) {
            match (indexByOwner.get(overlay.owner)) {
                case Some(index) =>
                    overlays[index] = overlay
                    continue
                case None => let _ = indexByOwner.add(overlay.owner, overlays.size)
            }
        }
        overlays.add(overlay)
    }
    OverlaySnapshot(registrations, overlays.toArray(), indexByOwner)
}

/* Ordered overlay stack with indexed owners and O(1) adoption of one committed layout fragment. */
class OverlayRegistry {
    private let overlays = ArrayList<Overlay>()
    private let registrations = ArrayList<Overlay>()
    private let indexByOwner = HashMap<String, Int64>()
    private var adopted: ?OverlaySnapshot = None
    private var replayVisits: UInt64 = UInt64(0)

    prop size: Int64 {
        get() {
            match (adopted) {
                case Some(snapshot) => snapshot.overlays.size
                case None => overlays.size
            }
        }
    }

    func register(overlay: Overlay): Unit {
        materializeAdopted()
        registerMaterialized(overlay)
    }

    func replay(snapshot: OverlaySnapshot): Unit {
        if (adopted.isNone() && registrations.isEmpty() && overlays.isEmpty()) {
            adopted = Some(snapshot)
            return
        }
        materializeAdopted()
        replayVisits += UInt64(snapshot.registrations.size)
        for (overlay in snapshot.registrations) {
            registerMaterialized(overlay)
        }
    }

    func remove(owner: String): Unit {
        if (owner.isEmpty()) {
            return
        }
        materializeAdopted()
        match (indexByOwner.get(owner)) {
            case Some(index) =>
                let _ = indexByOwner.remove(owner) // cjcheck-ignore: ignore-result # index proves the owner is present
                overlays.remove(at: index)
                reindexFrom(index)
            case None => ()
        }
    }

    func clear(): Unit {
        adopted = None
        overlays.clear()
        registrations.clear()
        indexByOwner.clear()
    }

    func isEmpty(): Bool {
        size == 0
    }

    func registrationCount(): Int64 {
        match (adopted) {
            case Some(snapshot) => snapshot.registrations.size
            case None => registrations.size
        }
    }

    func replayVisitCount(): UInt64 {
        replayVisits
    }

    func snapshotIfAnyFrom(start: Int64): ?OverlaySnapshot {
        let first = max(0, start)
        match (adopted) {
            case Some(snapshot) =>
                if (first >= snapshot.registrations.size) {
                    return None
                }
                if (first == 0) {
                    return Some(snapshot)
                }
                Some(
                    overlaySnapshotFromRegistrations(
                        Array<Overlay>(
                            snapshot.registrations.size - first,
                            {index => snapshot.registrations[first + index]}
                        )
                    )
                )
            case None =>
                if (first >= registrations.size) {
                    return None
                }
                Some(
                    overlaySnapshotFromRegistrations(
                        Array<Overlay>(
                            registrations.size - first,
                            {index => registrations[first + index]}
                        )
                    )
                )
        }
    }

    func dispatch(ctx: UiContext, event: UiEvent): Bool {
        let snapshot = activeOverlays()
        var index = snapshot.size - 1
        while (index >= 0) {
            let overlay = snapshot[index]
            if (isRegistered(overlay) && overlay.dispatch(ctx, event)) {
                return true
            }
            index -= 1
        }
        false
    }

    func draw(ctx: UiContext): Unit {
        var index = 0
        while (index < size) {
            overlayAt(index).render(ctx)
            index += 1
        }
    }

    private func registerMaterialized(overlay: Overlay): Unit {
        registrations.add(overlay)
        if (!overlay.owner.isEmpty()) {
            match (indexByOwner.get(overlay.owner)) {
                case Some(index) =>
                    overlays[index] = overlay
                    return
                case None => let _ = indexByOwner.add(overlay.owner, overlays.size)
            }
        }
        overlays.add(overlay)
    }

    private func isRegistered(overlay: Overlay): Bool {
        if (!overlay.owner.isEmpty()) {
            return match (ownerIndex(overlay.owner)) {
                case Some(index) => refEq(overlayAt(index), overlay)
                case None => false
            }
        }
        for (candidate in activeOverlays()) {
            if (refEq(candidate, overlay)) {
                return true
            }
        }
        false
    }

    private func reindexFrom(start: Int64): Unit {
        for (index in start..overlays.size) {
            let owner = overlays[index].owner
            if (!owner.isEmpty()) {
                let _ = indexByOwner.add(owner, index) // cjcheck-ignore: ignore-result # shifted owners replace their old indices
            }
        }
    }

    private func ownerIndex(owner: String): ?Int64 {
        match (adopted) {
            case Some(snapshot) => snapshot.indexFor(owner)
            case None => indexByOwner.get(owner)
        }
    }

    private func overlayAt(index: Int64): Overlay {
        match (adopted) {
            case Some(snapshot) => snapshot.overlays[index]
            case None => overlays[index]
        }
    }

    private func activeOverlays(): Array<Overlay> {
        match (adopted) {
            case Some(snapshot) => snapshot.overlays
            case None => overlays.toArray()
        }
    }

    private func materializeAdopted(): Unit {
        match (adopted) {
            case Some(snapshot) =>
                adopted = None
                for (overlay in snapshot.registrations) {
                    registrations.add(overlay)
                }
                for (overlay in snapshot.overlays) {
                    if (!overlay.owner.isEmpty()) {
                        let _ = indexByOwner.add(overlay.owner, overlays.size) // cjcheck-ignore: ignore-result # snapshot owners are normalized
                    }
                    overlays.add(overlay)
                }
            case None => ()
        }
    }
}

/** Cumulative declarations visited because an overlay fragment could not be adopted directly. */
protected func overlayFragmentReplayVisits(ctx: UiContext): UInt64 {
    ctx.overlayFragmentReplayVisitCount()
}
