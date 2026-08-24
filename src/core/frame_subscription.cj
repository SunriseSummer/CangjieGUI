package cui.core

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

protected func registerFrameSubscriber(callback: (UiContext, FrameInfo) -> Unit): Unit {
    match (currentStateStoreIfActive()) {
        case Some(store) => store.frameSubscribers.add(FrameSubscriber(callback))
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
    store.frameSubscribers.size
}

func frameSubscribersFrom(store: StateStore, start: Int64): Array<FrameSubscriber> {
    if (start >= store.frameSubscribers.size) {
        return []
    }
    let from = max(0, start)
    Array<FrameSubscriber>(store.frameSubscribers.size - from, {i => store.frameSubscribers[from + i]})
}

func replayFrameSubscribers(store: StateStore, subscribers: Array<FrameSubscriber>): Unit {
    for (subscriber in subscribers) {
        store.frameSubscribers.add(subscriber)
    }
}

/** Dispatches the synthesized frame tick only to widgets that explicitly subscribed while building. */
protected func dispatchFrameSubscribers(store: StateStore, ctx: UiContext, frame: FrameInfo): Unit {
    let snapshot = store.frameSubscribers.toArray()
    for (subscriber in snapshot) {
        subscriber.dispatch(ctx, frame)
    }
}
