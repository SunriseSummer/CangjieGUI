package cui.core

import std.collection.ArrayList
import sdl.text as nativeText

internal struct GraphemeCluster {
    let start: Int64
    let end: Int64
    let first: UInt32
    let last: UInt32

    init(start: Int64, end: Int64, first: UInt32, last: UInt32) {
        this.start = start
        this.end = end
        this.first = first
        this.last = last
    }
}

internal func preferredBreak(clusters: Array<GraphemeCluster>, start: Int64, fittedEnd: Int64): Int64 {
    var candidate = fittedEnd
    while (candidate > start) {
        if (canBreakBetween(clusters[candidate - 1], clusters[candidate])) {
            return candidate
        }
        candidate -= 1
    }
    fittedEnd
}

internal func nextMandatoryBreak(clusters: Array<GraphemeCluster>, start: Int64): Int64 {
    var index = start
    while (index < clusters.size && !isMandatoryBreak(clusters[index])) {
        index += 1
    }
    index
}

internal func segmentGraphemes(text: String): Array<GraphemeCluster> {
    let runes = text.toRuneArray()
    let boundaries = graphemeRuneBoundaries(runes)
    let clusters = ArrayList<GraphemeCluster>()
    var offset: Int64 = 0
    for (i in 1..boundaries.size) {
        let start = offset
        for (j in boundaries[i - 1]..boundaries[i]) {
            offset += runeByteLength(UInt32(runes[j]))
        }
        clusters.add(GraphemeCluster(start, offset, UInt32(runes[boundaries[i - 1]]), UInt32(runes[boundaries[i] - 1])))
    }
    clusters.toArray()
}

/** Unicode 17 extended-grapheme ends in rune indices, shared with the SDL text backend. */
protected func graphemeRuneBoundaries(runes: Array<Rune>): Array<Int64> {
    nativeText.graphemeRuneBoundaries(runes)
}

/** The same boundaries expressed as UTF-8 byte offsets. */
protected func graphemeByteBoundaries(text: String): Array<Int64> {
    nativeText.graphemeByteBoundaries(text)
}

private func runeByteLength(codePoint: UInt32): Int64 {
    if (codePoint <= UInt32(0x7F)) {
        1
    } else if (codePoint <= UInt32(0x7FF)) {
        2
    } else if (codePoint <= UInt32(0xFFFF)) {
        3
    } else {
        4
    }
}

private func isLineControl(codePoint: UInt32): Bool {
    codePoint == UInt32(0x000A) || codePoint == UInt32(0x000D)
}

internal func isMandatoryBreak(cluster: GraphemeCluster): Bool {
    isLineControl(cluster.first)
}

private func canBreakBetween(previous: GraphemeCluster, current: GraphemeCluster): Bool {
    if (isNonBreaking(previous.last) || isNonBreaking(current.first) || isOpeningPunctuation(previous.last) ||
        isClosingPunctuation(current.first)) {
        return false
    }
    if (isBreakSpace(previous.last) || isBreakAfter(previous.last)) {
        return true
    }
    if (isCjk(previous.last) || isCjk(current.first)) {
        return true
    }
    false
}

internal func isBreakSpace(codePoint: UInt32): Bool {
    codePoint == UInt32(0x0009) || codePoint == UInt32(0x0020) || codePoint == UInt32(0x1680) || (codePoint >= UInt32(0x2000) &&
        codePoint <= UInt32(0x200A)) || codePoint == UInt32(0x205F) || codePoint == UInt32(0x3000) || codePoint ==
        UInt32(0x200B)
}

private func isNonBreaking(codePoint: UInt32): Bool {
    codePoint == UInt32(0x00A0) || codePoint == UInt32(0x202F) || codePoint == UInt32(0x2060) || codePoint == UInt32(0xFEFF)
}

private func isBreakAfter(codePoint: UInt32): Bool {
    codePoint == UInt32(0x002D) || codePoint == UInt32(0x002F) || codePoint == UInt32(0x058A) || codePoint == UInt32(0x2010) ||
        codePoint == UInt32(0x2012) || codePoint == UInt32(0x2013)
}

private func isOpeningPunctuation(codePoint: UInt32): Bool {
    codePoint == UInt32(0x0028) || codePoint == UInt32(0x005B) || codePoint == UInt32(0x007B) || codePoint == UInt32(0x2018) ||
        codePoint == UInt32(0x201C) || codePoint == UInt32(0x3008) || codePoint == UInt32(0x300A) || codePoint == UInt32(0x300C) ||
        codePoint == UInt32(0x300E) || codePoint == UInt32(0x3010) || codePoint == UInt32(0x3014) || codePoint == UInt32(0x3016) ||
        codePoint == UInt32(0x3018) || codePoint == UInt32(0x301A) || codePoint == UInt32(0xFF08)
}

private func isClosingPunctuation(codePoint: UInt32): Bool {
    codePoint == UInt32(0x0021) || codePoint == UInt32(0x0025) || codePoint == UInt32(0x0029) || codePoint == UInt32(0x002C) ||
        codePoint == UInt32(0x002E) || codePoint == UInt32(0x003A) || codePoint == UInt32(0x003B) || codePoint == UInt32(0x003F) ||
        codePoint == UInt32(0x005D) || codePoint == UInt32(0x007D) || codePoint == UInt32(0x2019) || codePoint == UInt32(0x201D) ||
        codePoint == UInt32(0x3001) || codePoint == UInt32(0x3002) || codePoint == UInt32(0x3009) || codePoint == UInt32(0x300B) ||
        codePoint == UInt32(0x300D) || codePoint == UInt32(0x300F) || codePoint == UInt32(0x3011) || codePoint == UInt32(0x3015) ||
        codePoint == UInt32(0x3017) || codePoint == UInt32(0x3019) || codePoint == UInt32(0x301B) || codePoint == UInt32(0xFF01) ||
        codePoint == UInt32(0xFF09) || codePoint == UInt32(0xFF0C) || codePoint == UInt32(0xFF0E) || codePoint == UInt32(0xFF1A) ||
        codePoint == UInt32(0xFF1B) || codePoint == UInt32(0xFF1F)
}

private func isCjk(codePoint: UInt32): Bool {
    (codePoint >= UInt32(0x2E80) && codePoint <= UInt32(0xA4CF)) || (codePoint >= UInt32(0xAC00) && codePoint <= UInt32(0xD7AF)) ||
        (codePoint >= UInt32(0xF900) && codePoint <= UInt32(0xFAFF)) || (codePoint >= UInt32(0xFE30) && codePoint <=
        UInt32(0xFE4F)) || (codePoint >= UInt32(0xFF00) && codePoint <= UInt32(0xFFEF)) || (codePoint >= UInt32(0x20000) &&
        codePoint <= UInt32(0x323AF))
}
