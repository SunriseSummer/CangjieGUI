package cui.core

import sdl.Rect

private let PARTIAL_DAMAGE_AREA_LIMIT: Float32 = 0.70

/** Conservative frame-damage decision consumed once after stable layout. */
protected enum RetainedFrameDamage {
    | FullFrame
    | Region(Rect)
}

func markFullRetainedDamage(store: StateStore): Unit {
    store.fullRetainedDamagePending = true
    store.pendingRetainedDamage = None
}

func markRetainedDamage(store: StateStore, rect: Rect): Unit {
    if (store.fullRetainedDamagePending || rect.w <= 0.0 || rect.h <= 0.0) {
        return
    }
    store.pendingRetainedDamage = match (store.pendingRetainedDamage) {
        case Some(current) => Some(unionRect(current, rect))
        case None => Some(rect)
    }
}

/** Root layout reads are the conservative fallback for state used outside retained boundaries. */
protected func collectRootLayoutStateReads<T>(store: StateStore, body: () -> T): T {
    collectPhaseStateReads(rootLayoutStateDependencies(store), body)
}

/** Root paint reads are the conservative fallback for state used outside retained boundaries. */
protected func collectRootPaintStateReads<T>(store: StateStore, body: () -> T): T {
    collectPhaseStateReads(rootPaintStateDependencies(store), body)
}

/**
 * Consumes accumulated damage. Full rendering wins for unsafe triggers, root dependencies, empty
 * hints, or a union large enough that clipping/compositing is unlikely to pay back.
 */
protected func takeRetainedFrameDamage(
    store: StateStore,
    viewport: Rect,
    allowPartial: Bool
): RetainedFrameDamage {
    let pending = store.pendingRetainedDamage
    let full = store.fullRetainedDamagePending
    store.pendingRetainedDamage = None
    store.fullRetainedDamagePending = false
    if (!allowPartial || full) {
        return RetainedFrameDamage.FullFrame
    }
    match (pending) {
        case Some(value) =>
            let clipped = value.intersection(viewport)
            if (clipped.w <= 0.0 || clipped.h <= 0.0 || coversMostOfViewport(clipped, viewport)) {
                RetainedFrameDamage.FullFrame
            } else {
                RetainedFrameDamage.Region(clipped)
            }
        case None => RetainedFrameDamage.FullFrame
    }
}

/** Marks a host-driven full draw as consuming every damage hint accumulated before it. */
protected func consumeFullRetainedFrameDamage(store: StateStore): Unit {
    store.pendingRetainedDamage = None
    store.fullRetainedDamagePending = false
}

func clearRetainedDamageTracking(store: StateStore): Unit {
    match (store.rootLayoutDependencies) {
        case Some(dependencies) => dependencies.close()
        case None => ()
    }
    match (store.rootPaintDependencies) {
        case Some(dependencies) => dependencies.close()
        case None => ()
    }
    store.rootLayoutDependencies = None
    store.rootPaintDependencies = None
    store.pendingRetainedDamage = None
    store.fullRetainedDamagePending = true
}

private func rootLayoutStateDependencies(store: StateStore): PhaseStateDependencies {
    match (store.rootLayoutDependencies) {
        case Some(dependencies) => dependencies
        case None =>
            let dependencies = PhaseStateDependencies({=> markFullRetainedDamage(store)})
            store.rootLayoutDependencies = Some(dependencies)
            dependencies
    }
}

private func rootPaintStateDependencies(store: StateStore): PhaseStateDependencies {
    match (store.rootPaintDependencies) {
        case Some(dependencies) => dependencies
        case None =>
            let dependencies = PhaseStateDependencies({=> markFullRetainedDamage(store)})
            store.rootPaintDependencies = Some(dependencies)
            dependencies
    }
}

func unionRect(left: Rect, right: Rect): Rect {
    let x = min(left.x, right.x)
    let y = min(left.y, right.y)
    let farX = max(left.right(), right.right())
    let farY = max(left.bottom(), right.bottom())
    Rect(x, y, farX - x, farY - y)
}

private func coversMostOfViewport(damage: Rect, viewport: Rect): Bool {
    let viewportArea = viewport.w * viewport.h
    viewportArea <= 0.0 || damage.w * damage.h >= viewportArea * PARTIAL_DAMAGE_AREA_LIMIT
}
