package cui.core

import std.collection.ArrayList
import sdl.FrameInfo

/* One explicit per-frame callback captured by the most recent successful build. */
class FrameSubscriber {
    private let callback: (UiContext, FrameInfo) -> Unit

    init(callback: (UiContext, FrameInfo) -> Unit) {
        this.callback = callback
    }

    func dispatch(ctx: UiContext, frame: FrameInfo): Unit {
        callback(ctx, frame)
    }
}

/* Immutable ordered callback fragment retained by automatic and explicit composition records. */
class FrameSubscriptionSnapshot {
    let subscribers: Array<FrameSubscriber>

    init(subscribers: Array<FrameSubscriber>) {
        this.subscribers = subscribers
    }

    prop size: Int64 {
        get() {
            subscribers.size
        }
    }

    func dispatch(ctx: UiContext, frame: FrameInfo): Unit {
        for (subscriber in subscribers) {
            subscriber.dispatch(ctx, frame)
        }
    }
}

/* Build-local free-monoid accumulator with O(1) adoption of one clean persistent fragment. */
class FrameSubscriptionRegistry {
    private let subscribers = ArrayList<FrameSubscriber>()
    private var adopted: ?FrameSubscriptionSnapshot = None
    private var snapshotCreations: UInt64 = UInt64(0)

    prop size: Int64 {
        get() {
            match (adopted) {
                case Some(snapshot) => snapshot.size
                case None => subscribers.size
            }
        }
    }

    func clear(): Unit {
        adopted = None
        subscribers.clear()
    }

    func register(subscriber: FrameSubscriber): Unit {
        materializeAdopted()
        subscribers.add(subscriber)
    }

    func replay(snapshot: FrameSubscriptionSnapshot): Unit {
        if (adopted.isNone() && subscribers.isEmpty()) {
            adopted = Some(snapshot)
            return
        }
        materializeAdopted()
        for (subscriber in snapshot.subscribers) {
            subscribers.add(subscriber)
        }
    }

    func fragmentFrom(start: Int64): FrameSubscriptionSnapshot {
        if (start <= 0) {
            return snapshot()
        }
        let values = match (adopted) {
            case Some(value) => value.subscribers
            case None => subscribers.toArray()
        }
        if (start >= values.size) {
            return createSnapshot([])
        }
        let first = max(0, start)
        createSnapshot(Array<FrameSubscriber>(values.size - first, {index => values[first + index]}))
    }

    func snapshot(): FrameSubscriptionSnapshot {
        match (adopted) {
            case Some(value) => value
            case None =>
                let value = createSnapshot(subscribers.toArray())
                subscribers.clear()
                adopted = Some(value)
                value
        }
    }

    func creations(): UInt64 {
        snapshotCreations
    }

    func dispatch(ctx: UiContext, frame: FrameInfo): Unit {
        match (adopted) {
            case Some(snapshot) => snapshot.dispatch(ctx, frame)
            case None => for (subscriber in subscribers) {
                subscriber.dispatch(ctx, frame)
            }
        }
    }

    private func createSnapshot(values: Array<FrameSubscriber>): FrameSubscriptionSnapshot {
        snapshotCreations = nextRevision(snapshotCreations)
        FrameSubscriptionSnapshot(values)
    }

    private func materializeAdopted(): Unit {
        match (adopted) {
            case Some(snapshot) =>
                adopted = None
                for (subscriber in snapshot.subscribers) {
                    subscribers.add(subscriber)
                }
            case None => ()
        }
    }
}

func emptyFrameSubscriptionSnapshot(): FrameSubscriptionSnapshot {
    FrameSubscriptionSnapshot([])
}

protected func registerFrameSubscriber(callback: (UiContext, FrameInfo) -> Unit): Unit {
    match (currentStateStoreIfActive()) {
        case Some(store) => store.frameSubscriptionRegistry.register(FrameSubscriber(callback))
        case None => ()
    }
}

/**
 * Registers one callback for synthesized frame ticks in the active build. Call this from a custom
 * Widget constructor when it needs per-frame work; retained boundaries preserve the subscription
 * across build hits. Prefer `FrameHandler` when a wrapper is sufficient.
 */
public func subscribeFrame(callback: (UiContext, FrameInfo) -> Unit): Unit {
    registerFrameSubscriber(callback)
}

protected func frameSubscriberCount(store: StateStore): Int64 {
    store.frameSubscriptionRegistry.size
}

func frameSubscribersFrom(store: StateStore, start: Int64): FrameSubscriptionSnapshot {
    store.frameSubscriptionRegistry.fragmentFrom(start)
}

func replayFrameSubscribers(store: StateStore, subscribers: FrameSubscriptionSnapshot): Unit {
    store.frameSubscriptionRegistry.replay(subscribers)
}

/** Cumulative immutable-fragment creations, exposed to deterministic test/benchmark diagnostics. */
protected func frameSubscriptionSnapshotCreations(store: StateStore): UInt64 {
    store.frameSubscriptionRegistry.creations()
}

/** Dispatches the synthesized frame tick only to widgets that explicitly subscribed while building. */
protected func dispatchFrameSubscribers(store: StateStore, ctx: UiContext, frame: FrameInfo): Unit {
    store.frameSubscriptionRegistry.dispatch(ctx, frame)
}
