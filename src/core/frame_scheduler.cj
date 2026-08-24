package cui.core

import std.sync.{AtomicReference, AtomicUInt64}

private class FrameSchedulerOwner {
    let thread: ?Thread

    init(thread: ?Thread) {
        this.thread = thread
    }
}

// AtomicReference CAS compares object identity. A dedicated token avoids relying on Thread.id
// sentinel values or on ids that the runtime is allowed to reuse after a thread exits.
private let unclaimedFrameSchedulerOwner = FrameSchedulerOwner(None)

/*
 * Per-application invalidation coordinator. A scheduler is owned by the thread that first activates
 * it; all UI-state reads/writes bound to it must remain on that thread. `DesktopApp.post` is the
 * cross-thread hand-off and drains posted actions inside `transaction`, so several writes caused by
 * one input/action advance the generation only once.
 */
public class FrameScheduler {
    private let generationValue = AtomicUInt64(UInt64(0))
    private let owner = AtomicReference<FrameSchedulerOwner>(unclaimedFrameSchedulerOwner)
    private var transactionDepth: Int64 = 0
    private var transactionDirty = false
    private var stateReadCollectionDepth: Int64 = 0

    /** Current application-local invalidation generation. */
    public init() {}

    protected prop generation: UInt64 {
        get() {
            generationValue.load()
        }
    }

    /** Claims this scheduler for the current thread, or rejects use from another thread. */
    protected func assertOwnerThread(): Unit {
        let current = Thread.currentThread
        var ownerSnapshot = owner.load()
        if (sameOwner(ownerSnapshot, unclaimedFrameSchedulerOwner)) {
            let candidate = FrameSchedulerOwner(Some(current))
            if (owner.compareAndSwap(unclaimedFrameSchedulerOwner, candidate)) {
                return
            }
            ownerSnapshot = owner.load()
        }
        match (ownerSnapshot.thread) {
            case Some(ownerThread) =>
                if (!sameThread(ownerThread, current)) {
                    throw IllegalStateException(
                        "CUI State is bound to desktop UI thread ${ownerThread.id}; publish background results with DesktopApp.post")
                }
                return
            case None => throw IllegalStateException("CUI frame scheduler owner claim failed")
        }
    }

    /** Whether the owning UI thread is currently collecting retained State dependencies. */
    func isCollectingStateReads(): Bool {
        stateReadCollectionDepth > 0
    }

    /** Marks visual state dirty, coalescing writes while a transaction is active. */
    protected func invalidate(): Unit {
        assertOwnerThread()
        if (transactionDepth > 0) {
            transactionDirty = true
        } else {
            generationValue.fetchAdd(UInt64(1))
        }
    }

    /** Runs one UI action atomically from the frame scheduler's point of view. */
    protected func transaction(body: () -> Unit): Unit {
        assertOwnerThread()
        transactionDepth += 1
        try {
            body()
        } finally {
            transactionDepth -= 1
            if (transactionDepth == 0 && transactionDirty) {
                transactionDirty = false
                generationValue.fetchAdd(UInt64(1))
            }
        }
    }

    func beginStateReadCollection(): Unit {
        stateReadCollectionDepth += 1
    }

    func endStateReadCollection(): Unit {
        if (stateReadCollectionDepth <= 0) {
            throw IllegalStateException("Unbalanced scheduler State read collection")
        }
        stateReadCollectionDepth -= 1
    }
}

private func sameOwner(left: FrameSchedulerOwner, right: FrameSchedulerOwner): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both operands are class instances by construction
}

private func sameThread(left: Thread, right: Thread): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both operands are class instances by construction
}

// Build/event callbacks are synchronous but may nest. Thread-local storage prevents a second app on
// another thread from binding its State objects to this app's scheduler.
private let activeFrameScheduler = ThreadLocal<FrameScheduler>()

/** Runs `body` with `scheduler` as the current UI scheduler, restoring any nested predecessor. */
protected func withFrameScheduler(scheduler: FrameScheduler, body: () -> Unit): Unit {
    scheduler.assertOwnerThread()
    let previous = activeFrameScheduler.get()
    activeFrameScheduler.set(Some(scheduler))
    try {
        body()
    } finally {
        activeFrameScheduler.set(previous)
    }
}

/** Returns the scheduler active on this thread, if the caller is inside a desktop frame/action. */
func currentFrameScheduler(): ?FrameScheduler {
    activeFrameScheduler.get()
}
