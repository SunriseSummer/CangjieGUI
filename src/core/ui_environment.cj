package cui.core

import std.sync.AtomicUInt64

private let UI_ENVIRONMENT_GENERATION_COUNTER = AtomicUInt64(UInt64(0))

/* Process-unique generation interned for one complete ambient UI environment. */
func allocateUiEnvironmentGeneration(): UInt64 {
    UI_ENVIRONMENT_GENERATION_COUNTER.fetchAdd(UInt64(1))
}

/*
 * Interned key for ambient inputs that may change phase output without changing explicit geometry:
 * UiContext identity, renderer/theme identity, display and font scale, and the frame-stable font
 * registry snapshot. Equality remains one integer comparison on every hot cache path.
 */
protected struct UiEnvironmentKey {
    let generation: UInt64

    init(generation: UInt64) {
        this.generation = generation
    }
}

protected func sameUiEnvironment(left: UiEnvironmentKey, right: UiEnvironmentKey): Bool {
    left.generation == right.generation
}
