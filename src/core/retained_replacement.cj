package cui.core

/* A retained replacement is staged until the enclosing root build commits. */
class PendingRetainedReplacement {
    let record: RetainedRecord
    let revision: UInt64
    let cachePaint: Bool
    let child: Widget
    let frameSubscribers: Array<FrameSubscriber>

    init(
        record: RetainedRecord,
        revision: UInt64,
        cachePaint: Bool,
        child: Widget,
        frameSubscribers: Array<FrameSubscriber>
    ) {
        this.record = record
        this.revision = revision
        this.cachePaint = cachePaint
        this.child = child
        this.frameSubscribers = frameSubscribers
    }

    func commit(): Unit {
        record.replace(revision, cachePaint, child, frameSubscribers)
    }
}

func stageRetainedReplacement(
    store: StateStore,
    record: RetainedRecord,
    revision: UInt64,
    cachePaint: Bool,
    child: Widget,
    frameSubscribers: Array<FrameSubscriber>
): Unit {
    store.retainedReplacements.add(PendingRetainedReplacement(record, revision, cachePaint, child, frameSubscribers))
}
