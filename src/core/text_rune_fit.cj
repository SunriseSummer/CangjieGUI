package cui.core

private let WRAP_GALLOP_SEED: Int64 = 32
private let WRAP_GALLOP_THRESHOLD: Int64 = 512

/*
 * Returns the largest rune count that fits. Short inputs get one whole-run probe; long inputs first
 * gallop to a narrow bracket so wrapping a document never rebuilds its full remaining suffix per line.
 */
protected func maxRunesFitting(
    runes: Array<Rune>,
    start: Int64,
    maxW: Float32,
    measure: (String) -> Float32
): Int64 {
    let remaining = runes.size - start
    if (remaining <= 0 || maxW <= 0.0) {
        return 0
    }
    if (remaining <= WRAP_GALLOP_THRESHOLD) {
        if (measure(runeSlice(runes, start, start + remaining)) <= maxW) {
            return remaining
        }
        return largestFitting(runes, start, 0, remaining - 1, measure, maxW)
    }
    var fits = 0
    var probe = WRAP_GALLOP_SEED
    while (probe < remaining) {
        if (measure(runeSlice(runes, start, start + probe)) <= maxW) {
            fits = probe
            probe *= 4
        } else {
            return largestFitting(runes, start, fits, probe - 1, measure, maxW)
        }
    }
    if (measure(runeSlice(runes, start, start + remaining)) <= maxW) {
        return remaining
    }
    largestFitting(runes, start, fits, remaining - 1, measure, maxW)
}

private func largestFitting(
    runes: Array<Rune>,
    start: Int64,
    knownFit: Int64,
    highBound: Int64,
    measure: (String) -> Float32,
    maxW: Float32
): Int64 {
    var low = knownFit + 1
    var high = highBound
    var answer = knownFit
    while (low <= high) {
        let middle = (low + high) / 2
        if (measure(runeSlice(runes, start, start + middle)) <= maxW) {
            answer = middle
            low = middle + 1
        } else {
            high = middle - 1
        }
    }
    answer
}

// Module-visible so RichText shares one allocation-conscious slice helper.
protected func runeSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var index = start
    while (index < end) {
        builder.append(runes[index])
        index += 1
    }
    builder.toString()
}
