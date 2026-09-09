package cui.text

import std.collection.ArrayList
import cui.core.{UiContext, UiEnvironmentKey, sameUiEnvironment, wrapTextByteRanges}

internal struct TextVisualRow {
    let start: Int64
    let end: Int64
    let next: Int64
    init(start: Int64, end: Int64, next: Int64) {
        this.start = start
        this.end = end
        this.next = next
    }
}

// Visual rows retain document/display byte offsets; wrapping never edits the bound value.
internal class TextEditorLayout {
    let text: String
    let rows: Array<TextVisualRow>
    private let widths: Array<Float32>
    init(text: String, rows: Array<TextVisualRow>) {
        this.text = text
        this.rows = rows
        this.widths = Array<Float32>(rows.size, repeat: -1.0)
    }
    func rowAt(offset: Int64, upstream!: Bool = false): Int64 {
        let wanted = max(0, min(text.size, offset))
        var low: Int64 = 0;
        var high = rows.size - 1
        while (low < high) {
            let middle = low + (high - low + 1) / 2
            if (rows[middle].start <= wanted) {
                low = middle
            } else {
                high = middle - 1
            }
        }
        if (upstream && low > 0 && rows[low - 1].end == wanted && rows[low].start == wanted) {
            low - 1
        } else {
            low
        }
    }
    func width(ctx: UiContext, row: Int64): Float32 {
        if (widths[row] < 0.0) {
            widths[row] = ctx.textWidth(text[rows[row].start..rows[row].end])
        }
        widths[row]
    }
}

internal class TextEditorLayoutCache {
    private var value: ?TextEditorLayout = None
    private var environment: ?UiEnvironmentKey = None
    private var widthBits: UInt32 = 0
    private var wrapValue = false
    private var multilineValue = true
    func get(ctx: UiContext, text: String, width: Float32, wrap: Bool, multiline: Bool): TextEditorLayout {
        let current = ctx.uiEnvironmentKey()
        let widthKey = if (wrap) {
            width.toBits()
        } else {
            UInt32(0)
        }
        if (let Some(cached) <- value) {
            if (let Some(previous) <- environment) {
                if (cached.text == text && sameUiEnvironment(previous, current) && widthBits == widthKey && wrapValue ==
                    wrap && multilineValue == multiline) {
                    return cached
                }
            }
        }
        let result = buildEditorRows(ctx, text, width, wrap, multiline)
        value = Some(result)
        environment = Some(current)
        widthBits = widthKey
        wrapValue = wrap
        multilineValue = multiline
        result
    }
}

private func buildEditorRows(ctx: UiContext, text: String, width: Float32, wrap: Bool, multiline: Bool): TextEditorLayout {
    let rows = ArrayList<TextVisualRow>()
    if (!multiline) {
        return TextEditorLayout(text, [TextVisualRow(0, text.size, text.size)])
    }
    var start: Int64 = 0
    while (true) {
        let end = lineEndAfterOrAt(text, start)
        let next = if (end < text.size) {
            nextTextBoundary(text, end)
        } else {
            end
        }
        if (wrap && start < end) {
            appendWrappedRows(ctx, text, TextVisualRow(start, end, next), width, rows)
        } else {
            rows.add(TextVisualRow(start, end, next))
        }
        if (end == text.size) {
            break
        }
        start = next
    }
    TextEditorLayout(text, rows.toArray())
}

private func appendWrappedRows(ctx: UiContext, text: String, line: TextVisualRow, width: Float32,
    rows: ArrayList<TextVisualRow>): Unit {
    let content = text[line.start..line.end]
    try (session = ctx.textMeasureSession(content)) {
        let ranges = wrapTextByteRanges(content, width, session)
        for (i in 0..ranges.size) {
            let (a, b) = ranges[i]
            rows.add(TextVisualRow(line.start + a, line.start + b, if (i + 1 == ranges.size) {
                line.next
            } else {
                line.start + b
            }))
        }
    }
}
