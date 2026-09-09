package cui.controls

private let RICH_LF: UInt8 = 10
private let RICH_CR: UInt8 = 13
private let RICH_NEL_LEAD: UInt8 = 0xC2
private let RICH_NEL_TAIL: UInt8 = 0x85
private let RICH_SEPARATOR_LEAD: UInt8 = 0xE2
private let RICH_SEPARATOR_MIDDLE: UInt8 = 0x80
private let RICH_LINE_SEPARATOR_TAIL: UInt8 = 0xA8
private let RICH_PARAGRAPH_SEPARATOR_TAIL: UInt8 = 0xA9

// Hard breaks are layout boundaries, never glyphs sent to a single-line paint fragment.
// Scan UTF-8 without allocating a per-character array; keep offsets in the original joined run
// so source spans, links and highlights remain correctly identified across line breaks.
internal func flowTextSpan(flow: RichFlow, run: SpanRun, text: String, fragHeight!: Float32,
    spanMeasure!: (String) -> Float32): Unit {
    if (text.isEmpty()) {
        return
    }
    var start: Int64 = 0
    if (flow.pendingCr && text[0] == RICH_LF) {
        start = 1
    }
    flow.pendingCr = false
    var index = start
    while (index < text.size) {
        let length = richMandatoryBreakLength(text, index)
        if (length == 0) {
            index += 1
            continue
        }
        if (start < index) {
            flowWrappedText(flow, run, text[start..index], byteOffset: start, fragHeight: fragHeight,
                spanMeasure: spanMeasure)
        }
        flow.lineHeights[flow.line] = max(flow.lineHeights[flow.line], fragHeight)
        flow.wrapLine()
        flow.lineHeights[flow.line] = max(flow.lineHeights[flow.line], fragHeight)
        flow.pendingCr = text[index] == RICH_CR && length == 1 && index + length == text.size
        index += length
        start = index
    }
    if (start < text.size) {
        flowWrappedText(flow, run, text[start..text.size], byteOffset: start, fragHeight: fragHeight,
            spanMeasure: spanMeasure)
    }
}

private func richMandatoryBreakLength(text: String, index: Int64): Int64 {
    let byte = text[index]
    if (byte == RICH_CR) {
        return if (index + 1 < text.size && text[index + 1] == RICH_LF) {
            2
        } else {
            1
        }
    }
    if (byte == RICH_LF) {
        return 1
    }
    if (byte == RICH_NEL_LEAD && index + 1 < text.size && text[index + 1] == RICH_NEL_TAIL) {
        return 2
    }
    if (byte == RICH_SEPARATOR_LEAD && index + 2 < text.size && text[index + 1] == RICH_SEPARATOR_MIDDLE && (text[index +
            2] == RICH_LINE_SEPARATOR_TAIL || text[index + 2] == RICH_PARAGRAPH_SEPARATOR_TAIL)) {
        return 3
    }
    0
}
