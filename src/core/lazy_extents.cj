package cui.core

/** Fenwick-tree extent index: point updates and prefix/range lookup stay O(log N). */
class LazyExtentIndex {
    private var heights = Array<Float32>(0, {_ => 0.0})
    private var tree = Array<Float32>(1, {_ => 0.0})
    private var lowBits = Array<Int64>(1, {_ => Int64(1)})
    private var spacingValue: Float32 = 0.0

    func reset(count: Int64, heightOf: (Int64) -> Float32, spacing: Float32): Unit {
        let size = max(Int64(0), count)
        spacingValue = max(0.0, spacing)
        heights = Array<Float32>(size, {index => max(0.0, heightOf(index))})
        tree = Array<Float32>(size + 1, {_ => 0.0})
        lowBits = Array<Int64>(size + 1, {
            index => if (index <= 0) {
                Int64(1)
            } else {
                fenwickLowBit(index)
            }
        })
        var index: Int64 = 1
        while (index <= size) {
            tree[index] += heights[index - 1] + spacingValue
            let parent = index + lowBits[index]
            if (parent <= size) {
                tree[parent] += tree[index]
            }
            index += 1
        }
    }

    func count(): Int64 {
        heights.size
    }

    func heightAt(index: Int64): Float32 {
        heights[index]
    }

    func topOf(index: Int64): Float32 {
        prefix(min(heights.size, max(Int64(0), index)))
    }

    func contentExtent(): Float32 {
        if (heights.isEmpty()) {
            0.0
        } else {
            max(0.0, prefix(heights.size) - spacingValue)
        }
    }

    func update(index: Int64, height: Float32): Bool {
        if (index < 0 || index >= heights.size) {
            throw IllegalArgumentException("Lazy list extent index is out of range")
        }
        let next = max(0.0, height)
        let previous = heights[index]
        if (previous.toBits() == next.toBits()) {
            return false
        }
        heights[index] = next
        let delta = next - previous
        var treeIndex = index + 1
        while (treeIndex < tree.size) {
            tree[treeIndex] += delta
            treeIndex += lowBits[treeIndex]
        }
        true
    }

    func rowAt(offset: Float32): Int64 {
        let size = heights.size
        if (size <= 0) {
            return -1
        }
        let target = max(0.0, offset)
        var bit: Int64 = 1
        while (bit * 2 <= size) {
            bit *= 2
        }
        var index: Int64 = 0
        var accumulated: Float32 = 0.0
        while (bit > 0) {
            let candidate = index + bit
            if (candidate <= size && accumulated + tree[candidate] <= target) {
                index = candidate
                accumulated += tree[candidate]
            }
            bit /= 2
        }
        min(size - 1, index)
    }

    func visibleRange(
        scroll: Float32,
        viewportExtent: Float32,
        overscan: LazyOverscanInsets
    ): (Int64, Int64) {
        if (heights.isEmpty()) {
            return (0, -1)
        }
        let start = max(0.0, scroll - overscan.before)
        let end = max(start, scroll + max(0.0, viewportExtent) + overscan.after)
        let first = max(Int64(0), rowAt(start))
        let last = min(heights.size - 1, max(first, rowAt(end)))
        (first, last)
    }

    private func prefix(end: Int64): Float32 {
        var index = end
        var result: Float32 = 0.0
        while (index > 0) {
            result += tree[index]
            index -= lowBits[index]
        }
        result
    }
}

private func fenwickLowBit(value: Int64): Int64 {
    var remaining = value
    var result: Int64 = 1
    while (remaining % 2 == 0) {
        result *= 2
        remaining /= 2
    }
    result
}

/**
 * Mutable variable-row extent model for high-frequency feeds. `update` is O(log N), schedules one
 * frame, and lets an attached `LazyList` update its visible range without rescanning all rows.
 */
public class LazyListExtents {
    private let index = LazyExtentIndex()
    private let revisionSignal = State<Int64>(0)
    private let structuralSignal = State<Int64>(0)

    public init(heights: Array<Float32>, spacing!: Float32 = 0.0) {
        index.reset(heights.size, {row => heights[row]}, spacing)
    }

    /** Number of rows represented by this model. */
    public prop count: Int64 {
        get() {
            index.count()
        }
    }

    /** Current height of one row. */
    public func heightAt(row: Int64): Float32 {
        index.heightAt(row)
    }

    /** Updates one row height in O(log N); returns whether the value changed. */
    public func update(row: Int64, height: Float32): Bool {
        if (index.update(row, height)) {
            revisionSignal.value += 1
            true
        } else {
            false
        }
    }

    /** Replaces all extents after an insert/remove/reorder and schedules one viewport rebuild. */
    public func reset(heights: Array<Float32>, spacing!: Float32 = 0.0): Unit {
        index.reset(heights.size, {row => heights[row]}, spacing)
        structuralSignal.value += 1
        revisionSignal.value += 1
    }

    func currentIndex(): LazyExtentIndex {
        index
    }

    func revision(): UInt64 {
        revisionSignal.revision
    }

    func structuralRevision(): UInt64 {
        structuralSignal.revision
    }
}

class LazyExtentCache {
    private let index = LazyExtentIndex()
    private var initialized: Bool = false
    private var cachedRevision: UInt64 = UInt64(0)
    private var cachedCount: Int64 = -1
    private var cachedSpacing: Float32 = -1.0

    func prepare(
        count: Int64,
        heightOf: (Int64) -> Float32,
        spacing: Float32,
        revision: ?UInt64
    ): LazyExtentIndex {
        let mustRebuild = match (revision) {
            case Some(value) => !initialized || value != cachedRevision || count != cachedCount || spacing.toBits() !=
                cachedSpacing.toBits()
            case None => true
        }
        if (mustRebuild) {
            index.reset(count, heightOf, spacing)
            initialized = true
            cachedCount = count
            cachedSpacing = spacing
            match (revision) {
                case Some(value) => cachedRevision = value
                case None => ()
            }
        }
        index
    }
}
