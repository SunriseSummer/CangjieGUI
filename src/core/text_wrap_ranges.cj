package cui.core

import std.collection.ArrayList
import sdl.TextMeasureSession

/** Editing counterpart of paragraph wrapping: preserves every byte, including break spaces. */
protected func wrapTextByteRanges(text: String, width: Float32, session: TextMeasureSession): Array<(Int64, Int64)> {
    let clusters = segmentGraphemes(text)
    if (clusters.isEmpty()) {
        return [(Int64(0), Int64(0))]
    }
    let result = ArrayList<(Int64, Int64)>()
    var start: Int64 = 0
    while (start < clusters.size) {
        let fit = session.fit(clusters[start].start, max(1.0, width))
        let limit = clusters[start].start + fit.byteLength
        var end = start
        while (end < clusters.size && clusters[end].end <= limit) {
            end += 1
        }
        end = max(start + 1, end)
        if (end < clusters.size) {
            end = preferredBreak(clusters, start, end)
        }
        result.add((clusters[start].start, clusters[end - 1].end))
        start = end
    }
    result.toArray()
}
