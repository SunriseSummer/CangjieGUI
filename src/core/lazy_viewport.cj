package cui.core

import std.collection.HashMap

internal let LAZY_DEFAULT_OVERSCAN_PIXELS: Float32 = 144.0

/** Placement of an item requested through `LazyViewportController.scrollToKey`. */
public enum LazyScrollAlignment {
    | Start
    | Center
    | End
    | Nearest
}

/**
 * External scroll owner for lazy viewports. It exposes a bindable offset and can reveal an item by
 * stable key without requiring the caller to know its current index or accumulated extent.
 * `scrollToKey` schedules a frame through observable state; the attached viewport resolves the key
 * on that frame. Keep one controller in the application model rather than recreating it per build.
 */
public class LazyViewportController {
    private let offsetState: State<Float32>
    private let requestSignal = State<Int64>(0)
    private var targetKey: String = ""
    private var targetAlignment: LazyScrollAlignment = LazyScrollAlignment.Nearest
    private var targetFound: Bool = true

    public init(initialOffset!: Float32 = 0.0) {
        offsetState = State<Float32>(max(0.0, initialOffset))
    }

    /** Current logical-pixel offset. Assign through `jumpTo` or bind via `state`. */
    public prop offset: Float32 {
        get() {
            offsetState.value
        }
    }

    /** The observable offset used by scrollbars, animation and coordinated views. */
    public func state(): State<Float32> {
        offsetState
    }

    /** Jumps to an absolute logical-pixel offset; the viewport clamps it to current content. */
    public func jumpTo(offset: Float32): Unit {
        targetKey = ""
        offsetState.value = max(0.0, offset)
    }

    /** Requests that the item with `key` be revealed at `alignment` on the next frame. */
    public func scrollToKey(key: String, alignment!: LazyScrollAlignment = LazyScrollAlignment.Nearest): Unit {
        if (key.isEmpty()) {
            throw IllegalArgumentException("Lazy viewport target key must not be empty")
        }
        targetKey = key
        targetAlignment = alignment
        targetFound = false
        requestSignal.value += 1
    }

    /** Whether the most recently processed key request matched the attached viewport. */
    public func lastTargetFound(): Bool {
        targetFound
    }

    func requestRevision(): UInt64 {
        requestSignal.revision
    }

    func requestedKey(): String {
        targetKey
    }

    func requestedAlignment(): LazyScrollAlignment {
        targetAlignment
    }

    func markTargetFound(): Unit {
        targetFound = true
    }

    func markTargetMissing(): Unit {
        targetFound = false
    }
}

// Persistent, non-observable viewport facts. Mutating these during layout does not schedule a
// stabilization rebuild; the next independently requested frame consumes them.
class LazyViewportMemory {
    var viewportExtent: Float32 = LAZY_DEFAULT_VIEWPORT
    var previousScroll: Float32 = 0.0
    var contentRevision: UInt64
    var structuralRevision: UInt64
    var controllerRevision: UInt64 = UInt64(0)
    var keyIndex = HashMap<String, Int64>()
    var keyIndexStructuralRevision: UInt64 = UInt64(0)
    var keyIndexCount: Int64 = -1
    var keyIndexReady = false
    var anchorKey: String = ""
    var anchorIndex: Int64 = -1
    var anchorWithinItem: Float32 = 0.0

    init(contentRevision: UInt64) {
        this.contentRevision = contentRevision
        this.structuralRevision = contentRevision
    }
}

internal struct LazyItemGeometry {
    let count: Int64
    let key: (Int64) -> String
    let itemTop: (Int64) -> Float32
    let itemExtent: (Int64) -> Float32
    let contentExtent: Float32

    init(
        count: Int64,
        key: (Int64) -> String,
        itemTop: (Int64) -> Float32,
        itemExtent: (Int64) -> Float32,
        contentExtent: Float32
    ) {
        this.count = count
        this.key = key
        this.itemTop = itemTop
        this.itemExtent = itemExtent
        this.contentExtent = contentExtent
    }
}

struct LazyOverscanInsets {
    let before: Float32
    let after: Float32

    init(before: Float32, after: Float32) {
        this.before = before
        this.after = after
    }
}

// Pixel-based overscan is stable across short/tall rows. Motion expands only the leading edge in
// the travel direction, capped at one viewport so a jump never materializes the whole collection.
internal func lazyAdaptiveOverscan(
    base: Float32,
    currentScroll: Float32,
    previousScroll: Float32,
    viewportExtent: Float32
): LazyOverscanInsets {
    let baseline = max(0.0, base)
    let movement = currentScroll - previousScroll
    let extra = min(max(0.0, viewportExtent), absF32(movement) * 1.5)
    if (movement > 0.0) {
        LazyOverscanInsets(baseline, baseline + extra)
    } else if (movement < 0.0) {
        LazyOverscanInsets(baseline + extra, baseline)
    } else {
        LazyOverscanInsets(baseline, baseline)
    }
}

internal func lazyFixedVisibleRange(
    scroll: Float32,
    viewportExtent: Float32,
    itemExtent: Float32,
    spacing: Float32,
    count: Int64,
    overscan: LazyOverscanInsets
): (Int64, Int64) {
    if (count <= 0 || itemExtent <= 0.0) {
        return (0, -1)
    }
    let stride = itemExtent + max(0.0, spacing)
    let start = max(0.0, scroll - overscan.before)
    let end = max(start, scroll + max(0.0, viewportExtent) + overscan.after)
    let first = min(count - 1, max(Int64(0), Int64(start / stride)))
    let last = min(count - 1, max(first, Int64(end / stride)))
    (first, last)
}

internal func lazyScrollForItem(
    current: Float32,
    itemTop: Float32,
    itemExtent: Float32,
    contentExtent: Float32,
    viewportExtent: Float32,
    alignment: LazyScrollAlignment
): Float32 {
    let itemBottom = itemTop + max(0.0, itemExtent)
    let target = match (alignment) {
        case LazyScrollAlignment.Start => itemTop
        case LazyScrollAlignment.Center => itemTop - (viewportExtent - itemExtent) / 2.0
        case LazyScrollAlignment.End => itemBottom - viewportExtent
        case LazyScrollAlignment.Nearest =>
            if (itemTop < current) {
                itemTop
            } else if (itemBottom > current + viewportExtent) {
                itemBottom - viewportExtent
            } else {
                current
            }
    }
    clampScrollOffset(target, contentExtent, viewportExtent)
}

internal func lazyResolveAnchoredScroll(
    memory: LazyViewportMemory,
    contentRevision: UInt64,
    structuralRevision: UInt64,
    current: Float32,
    geometry: LazyItemGeometry
): Float32 {
    if (memory.contentRevision == contentRevision) {
        return current
    }
    let structureChanged = memory.structuralRevision != structuralRevision
    memory.contentRevision = contentRevision
    memory.structuralRevision = structuralRevision
    if (memory.anchorKey.isEmpty()) {
        return current
    }
    if (!structureChanged && memory.anchorIndex >= 0 && memory.anchorIndex < geometry.count &&
        geometry.key(memory.anchorIndex) == memory.anchorKey) {
        let within = min(memory.anchorWithinItem, max(0.0, geometry.itemExtent(memory.anchorIndex)))
        return clampScrollOffset(geometry.itemTop(memory.anchorIndex) + within, geometry.contentExtent,
            memory.viewportExtent)
    }
    var index: Int64 = 0
    while (index < geometry.count) {
        if (geometry.key(index) == memory.anchorKey) {
            let within = min(memory.anchorWithinItem, max(0.0, geometry.itemExtent(index)))
            return clampScrollOffset(geometry.itemTop(index) + within, geometry.contentExtent, memory.viewportExtent)
        }
        index += 1
    }
    current
}

internal func lazyResolveControllerScroll(
    controller: ?LazyViewportController,
    memory: LazyViewportMemory,
    current: Float32,
    geometry: LazyItemGeometry
): Float32 {
    match (controller) {
        case Some(value) =>
            let revision = value.requestRevision()
            if (revision == memory.controllerRevision) {
                return current
            }
            memory.controllerRevision = revision
            let target = value.requestedKey()
            rebuildLazyKeyIndexIfNeeded(memory, geometry)
            match (memory.keyIndex.get(target)) {
                case Some(index) =>
                    value.markTargetFound()
                    return lazyScrollForItem(current, geometry.itemTop(index), geometry.itemExtent(index),
                        geometry.contentExtent, memory.viewportExtent, value.requestedAlignment())
                case None => ()
            }
            value.markTargetMissing()
            current
        case None => current
    }
}

private func rebuildLazyKeyIndexIfNeeded(memory: LazyViewportMemory, geometry: LazyItemGeometry): Unit {
    if (memory.keyIndexReady && memory.keyIndexStructuralRevision == memory.structuralRevision &&
        memory.keyIndexCount == geometry.count) {
        return
    }
    if (memory.keyIndex.capacity < geometry.count) {
        memory.keyIndex = HashMap<String, Int64>(geometry.count)
    } else {
        memory.keyIndex.clear()
    }
    // Reverse insertion preserves the previous linear search's first-match behavior for duplicate keys.
    var index = geometry.count - 1
    while (index >= 0) {
        memory.keyIndex.add(geometry.key(index), index)
        index -= 1
    }
    memory.keyIndexStructuralRevision = memory.structuralRevision
    memory.keyIndexCount = geometry.count
    memory.keyIndexReady = true
}

internal func lazyFloatChanged(left: Float32, right: Float32): Bool {
    left.toBits() != right.toBits()
}

internal func lazyRememberAnchor(
    memory: LazyViewportMemory,
    scroll: Float32,
    count: Int64,
    indexAt: (Float32) -> Int64,
    key: (Int64) -> String,
    itemTop: (Int64) -> Float32
): Unit {
    memory.previousScroll = scroll
    if (count <= 0) {
        memory.anchorKey = ""
        memory.anchorIndex = -1
        memory.anchorWithinItem = 0.0
        return
    }
    let index = min(count - 1, max(Int64(0), indexAt(scroll)))
    memory.anchorKey = key(index)
    memory.anchorIndex = index
    memory.anchorWithinItem = max(0.0, scroll - itemTop(index))
}
