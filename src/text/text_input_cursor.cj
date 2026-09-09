package cui.text

import sdl.FontSizes
import cui.core.{UiContext, graphemeByteBoundaries}

internal func textCursorForOffset(
    ctx: UiContext,
    text: String,
    lineStart: Int64,
    lineEnd: Int64,
    targetX: Float32
): Int64 {
    if (lineStart >= lineEnd) {
        return lineStart
    }
    let line = text[lineStart..lineEnd]
    let session = ctx.textMeasureSession(line, pointSize: ctx.textSize(fallback: FontSizes.BODY))
    var result = lineStart
    try (resource = session) {
        let hit = resource.hitTest(targetX).byteOffset
        let boundaries = graphemeByteBoundaries(line)
        var lower: Int64 = 0
        var upper = boundaries.size - 1
        while (lower < upper) {
            let middle = lower + (upper - lower + 1) / 2
            if (boundaries[middle] <= hit) {
                lower = middle
            } else {
                upper = middle - 1
            }
        }
        var offset = boundaries[lower]
        if (offset != hit && lower + 1 < boundaries.size) {
            let next = boundaries[lower + 1]
            let midpoint = (resource.measure(0, offset) + resource.measure(0, next)) / 2.0
            if (targetX >= midpoint) {
                offset = next
            }
        }
        result = lineStart + offset
    }
    result
}

internal func textCursorVisible(ctx: UiContext, epoch!: UInt64 = UInt64(0), interval!: UInt64 = UInt64(530)): Bool {
    let elapsed = if (ctx.frame.elapsedMs >= epoch) {
        ctx.frame.elapsedMs - epoch
    } else {
        UInt64(0)
    }
    interval == 0 || (elapsed / interval) % UInt64(2) == UInt64(0)
}
