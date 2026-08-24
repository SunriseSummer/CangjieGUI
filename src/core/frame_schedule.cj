package cui.core

/** A consumed snapshot of immediate/deadline frame requests made by widgets. */
public class FrameSchedule {
    public let immediate: Bool
    public let deadlineMs: ?UInt64

    public init(immediate!: Bool, deadlineMs!: ?UInt64) {
        this.immediate = immediate
        this.deadlineMs = deadlineMs
    }

    /** Whether a frame is due at `elapsedMs`. */
    public func isDue(elapsedMs: UInt64): Bool {
        if (immediate) {
            return true
        }
        match (deadlineMs) {
            case Some(deadline) => elapsedMs >= deadline
            case None => false
        }
    }

    /** Whether either an immediate request or a future deadline is pending. */
    public func hasPending(): Bool {
        immediate || deadlineMs.isSome()
    }
}
