package cui.core

import std.sync.AtomicUInt64

/*
 * Compatibility-wide assignment counter. The desktop loop now uses its own FrameScheduler. The
 * process counter remains atomic for sequential worker-to-UI hand-off diagnostics; State values
 * and observers themselves are thread-confined, not concurrent containers.
 */
private let stateWriteGeneration = AtomicUInt64(UInt64(0))
private let stateIdentityGeneration = AtomicUInt64(UInt64(0))

/* Process-unique State identity used by dependency indexes across erased generic types. */
func allocateStateIdentity(): UInt64 {
    stateIdentityGeneration.fetchAdd(UInt64(1))
}

func recordStateWrite(): Unit {
    stateWriteGeneration.fetchAdd(UInt64(1))
}

internal func nextRevision(current: UInt64): UInt64 {
    if (current == UInt64.Max) {
        UInt64(0)
    } else {
        current + UInt64(1)
    }
}

/** Compatibility diagnostic for the process-wide state-write generation. */
public func currentStateGeneration(): UInt64 {
    stateWriteGeneration.load()
}
