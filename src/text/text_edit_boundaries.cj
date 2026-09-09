package cui.text

import cui.core.{Bindable, graphemeByteBoundaries}

// One immutable boundary map per live document value. Rebinding a widget to another
// Bindable with the same revision must not reuse unrelated text or invalidate equal projections.
class TextEditBoundaryCache {
    private var owner: ?Object = None
    private var revision: UInt64 = 0
    private var initialized = false
    private var value = ""
    private var offsets: Array<Int64> = [0]

    func prepare(source: Bindable<String>): TextEditBoundaryCache {
        let currentOwner = source as Object
        let sameOwner = match ((owner, currentOwner)) {
            case (Some(previous), Some(current)) => refEq(previous, current)
            case _ => false
        }
        let currentRevision = source.revision
        if (!initialized || !sameOwner || currentRevision != revision) {
            let current = source.value
            if (!initialized || current != value) {
                offsets = graphemeByteBoundaries(current)
                value = current
            }
            initialized = true
            owner = currentOwner
            revision = currentRevision
        }
        this
    }

    func index(position: Int64): Int64 {
        var lower: Int64 = 0
        var upper = offsets.size
        while (lower < upper) {
            let middle = lower + (upper - lower) / 2
            if (offsets[middle] <= position) {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        max(0, lower - 1)
    }

    func at(index: Int64): Int64 {
        offsets[max(0, min(index, offsets.size - 1))]
    }
    func floor(position: Int64): Int64 {
        at(index(position))
    }
    func ceiling(position: Int64): Int64 {
        let i = index(position)
        if (at(i) < position) {
            at(i + 1)
        } else {
            at(i)
        }
    }
    func previous(position: Int64): Int64 {
        at(index(position) - 1)
    }
    func next(position: Int64): Int64 {
        at(index(position) + 1)
    }
}
