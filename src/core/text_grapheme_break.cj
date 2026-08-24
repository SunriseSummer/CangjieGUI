package cui.core

import std.collection.ArrayList

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
    if (runes.isEmpty()) {
        return []
    }
    let clusters = ArrayList<GraphemeCluster>(runes.size)
    var clusterStart: Int64 = 0
    var byteOffset = runeByteLength(UInt32(runes[0]))
    var clusterFirst = UInt32(runes[0])
    var previous = clusterFirst
    var regionalRun: Int64 = if (isRegionalIndicator(previous)) {
        1
    } else {
        0
    }
    var viramaPending = isVirama(previous)
    var index: Int64 = 1
    while (index < runes.size) {
        let current = UInt32(runes[index])
        let currentIsMark = isUnicodeMark(current)
        if (graphemeBreaksBefore(previous, current, currentIsMark, regionalRun, viramaPending)) {
            clusters.add(GraphemeCluster(clusterStart, byteOffset, clusterFirst, previous))
            clusterStart = byteOffset
            clusterFirst = current
        }
        byteOffset += runeByteLength(current)
        if (isRegionalIndicator(current)) {
            regionalRun = if (isRegionalIndicator(previous)) {
                regionalRun + 1
            } else {
                1
            }
        } else {
            regionalRun = 0
        }
        if (isVirama(current)) {
            viramaPending = true
        } else if (!currentIsMark && current != UInt32(0x200D)) {
            viramaPending = false
        }
        previous = current
        index += 1
    }
    clusters.add(GraphemeCluster(clusterStart, byteOffset, clusterFirst, previous))
    clusters.toArray()
}

/** Rune indices (0 plus every extended-grapheme end) for styled text layout. */
protected func graphemeRuneBoundaries(runes: Array<Rune>): Array<Int64> {
    if (runes.isEmpty()) {
        return [0]
    }
    let boundaries = ArrayList<Int64>(runes.size + 1)
    boundaries.add(0)
    var previous = UInt32(runes[0])
    var regionalRun: Int64 = if (isRegionalIndicator(previous)) {
        1
    } else {
        0
    }
    var viramaPending = isVirama(previous)
    var index: Int64 = 1
    while (index < runes.size) {
        let current = UInt32(runes[index])
        let currentIsMark = isUnicodeMark(current)
        if (graphemeBreaksBefore(previous, current, currentIsMark, regionalRun, viramaPending)) {
            boundaries.add(index)
        }
        if (isRegionalIndicator(current)) {
            regionalRun = if (isRegionalIndicator(previous)) {
                regionalRun + 1
            } else {
                1
            }
        } else {
            regionalRun = 0
        }
        if (isVirama(current)) {
            viramaPending = true
        } else if (!currentIsMark && current != UInt32(0x200D)) {
            viramaPending = false
        }
        previous = current
        index += 1
    }
    boundaries.add(runes.size)
    boundaries.toArray()
}

private func graphemeBreaksBefore(
    previous: UInt32,
    current: UInt32,
    currentIsMark: Bool,
    regionalRun: Int64,
    viramaPending: Bool
): Bool {
    if (previous == UInt32(0x000D) && current == UInt32(0x000A)) {
        return false
    }
    if (isLineControl(previous) || isLineControl(current)) {
        return true
    }
    if (currentIsMark || current == UInt32(0x200D) || isEmojiModifier(current) || isEmojiTag(current)) {
        return false
    }
    if (previous == UInt32(0x200D) || isPrepend(previous) || viramaPending) {
        return false
    }
    if (hangulJoins(previous, current)) {
        return false
    }
    if (isRegionalIndicator(previous) && isRegionalIndicator(current) && regionalRun % 2 == 1) {
        return false
    }
    true
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

private func isEmojiModifier(codePoint: UInt32): Bool {
    codePoint >= UInt32(0x1F3FB) && codePoint <= UInt32(0x1F3FF)
}

private func isEmojiTag(codePoint: UInt32): Bool {
    codePoint >= UInt32(0xE0020) && codePoint <= UInt32(0xE007F)
}

private func isRegionalIndicator(codePoint: UInt32): Bool {
    codePoint >= UInt32(0x1F1E6) && codePoint <= UInt32(0x1F1FF)
}

private func isPrepend(codePoint: UInt32): Bool {
    (codePoint >= UInt32(0x0600) && codePoint <= UInt32(0x0605)) || codePoint == UInt32(0x06DD) || codePoint == UInt32(0x070F) ||
        (codePoint >= UInt32(0x0890) && codePoint <= UInt32(0x0891)) || codePoint == UInt32(0x08E2) || codePoint ==
        UInt32(0x110BD) || codePoint == UInt32(0x110CD)
}

private func isVirama(codePoint: UInt32): Bool {
    codePoint == UInt32(0x094D) || codePoint == UInt32(0x09CD) || codePoint == UInt32(0x0A4D) || codePoint == UInt32(0x0ACD) ||
        codePoint == UInt32(0x0B4D) || codePoint == UInt32(0x0BCD) || codePoint == UInt32(0x0C4D) || codePoint == UInt32(0x0CCD) ||
        codePoint == UInt32(0x0D4D) || codePoint == UInt32(0x1039) || codePoint == UInt32(0x17D2) || codePoint == UInt32(0x1A60)
}

private func hangulJoins(previous: UInt32, current: UInt32): Bool {
    let previousL = previous >= UInt32(0x1100) && previous <= UInt32(0x115F)
    let currentL = current >= UInt32(0x1100) && current <= UInt32(0x115F)
    let currentV = current >= UInt32(0x1160) && current <= UInt32(0x11A7)
    let currentT = current >= UInt32(0x11A8) && current <= UInt32(0x11FF)
    let syllable = previous >= UInt32(0xAC00) && previous <= UInt32(0xD7A3)
    let syllableHasTail = syllable && (previous - UInt32(0xAC00)) % UInt32(28) != UInt32(0)
    (previousL && (currentL || currentV)) || ((currentV || (syllable && !syllableHasTail)) && (currentV || currentT)) ||
        ((currentT || syllableHasTail) && currentT)
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
