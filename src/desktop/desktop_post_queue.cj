package cui.desktop

import std.collection.concurrent.ConcurrentLinkedQueue
import std.sync.Mutex

/** Read-only snapshot of the bounded UI action queue. */
public struct DesktopPostStats {
    public let pending: Int64
    public let highWatermark: Int64
    public let rejected: UInt64
    public let wakeFailures: UInt64

    internal init(pending: Int64, highWatermark: Int64, rejected: UInt64, wakeFailures: UInt64) {
        this.pending = pending
        this.highWatermark = highWatermark
        this.rejected = rejected
        this.wakeFailures = wakeFailures
    }
}

class DesktopPostQueue {
    private let lock = Mutex()
    private let actions = ConcurrentLinkedQueue<() -> Unit>()
    private let capacity: Int64
    private var pending: Int64 = 0
    private var highWatermark: Int64 = 0
    private var rejected: UInt64 = 0
    private var wakeFailures: UInt64 = 0
    private var stopped = false
    private var draining = false

    init(capacity: Int64) {
        if (capacity < 1) {
            throw IllegalArgumentException("maxPendingPosts must be positive")
        }
        this.capacity = capacity
    }

    // Wake only on the empty -> nonempty transition; remaining work requests the next frame.
    func add(action: () -> Unit): (Bool, Bool) {
        synchronized(lock) {
            if (stopped || pending >= capacity) {
                rejected += 1
                return (false, false)
            }
            let first = pending == 0 && !draining
            if (!actions.add(action)) {
                rejected += 1
                return (false, false)
            }
            pending += 1
            highWatermark = max(highWatermark, pending)
            (true, first)
        }
    }

    private func take(): ?() -> Unit {
        synchronized(lock) {
            let action = actions.remove()
            if (action.isSome()) {
                pending -= 1
            }
            action
        }
    }

    func drain(limit: Int64): Bool {
        synchronized(lock) {
            if (draining) {
                throw IllegalStateException("UI post queue cannot be drained recursively")
            }
            draining = true
        }
        try {
            for (_ in 0..max(0, limit)) {
                match (take()) {
                    case Some(action) => action()
                    case None => return false
                }
            }
            stats().pending > 0
        } finally {
            synchronized(lock) {
                draining = false
            }
        }
    }

    func noteWakeFailure(): Unit {
        synchronized(lock) {
            wakeFailures += 1
        }
    }

    func stats(): DesktopPostStats {
        synchronized(lock) {
            DesktopPostStats(pending, highWatermark, rejected, wakeFailures)
        }
    }

    func stop(): Unit {
        synchronized(lock) {
            stopped = true
            while (actions.remove().isSome()) {}
            pending = 0
        }
    }
}
