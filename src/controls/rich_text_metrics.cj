package cui.controls

import std.collection.ArrayList
import sdl.{Color, FontStyle}

// The production layout supplies a baseline. Tests/custom metric adapters may retain centered rows.
internal struct RichTextMeasurements {
    let widthOf: (String, Float32, FontStyle, ?String) -> Float32
    let heightOf: (Float32, FontStyle, ?String) -> Float32
    let ascentOf: ?(Float32, FontStyle, ?String) -> Float32

    init(widthOf: (String, Float32, FontStyle, ?String) -> Float32, heightOf: (Float32, FontStyle, ?String) -> Float32,
        ascentOf!: ?(Float32, FontStyle, ?String) -> Float32 = None) {
        this.widthOf = widthOf
        this.heightOf = heightOf
        this.ascentOf = ascentOf
    }
}

// Merge only indistinguishable, noninteractive paint runs. Keeping links/highlights separate
// preserves source identity and rounded highlight edges until cluster-based paint spans exist.
internal func canMergeRichText(left: RichSpan, right: RichSpan, leftSize: Float32, rightSize: Float32): Bool {
    leftSize.toBits() == rightSize.toBits() && left.style == right.style && left.fontFace == right.fontFace &&
        left.isMuted == right.isMuted && sameRichColor(left.color, right.color) && left.tapAction.isNone() &&
        right.tapAction.isNone() && left.highlightColor.isNone() && right.highlightColor.isNone()
}

private func sameRichColor(left: ?Color, right: ?Color): Bool {
    match ((left, right)) {
        case (None, None) => true
        case (Some(a), Some(b)) => a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a
        case _ => false
    }
}

internal func coalesceRichText(spans: Array<RichSpan>, sizes: Array<Float32>, start: Int64, text: String): (String, 
    Int64, Array<Int64>) {
    let joined = StringBuilder()
    joined.append(text)
    let ends = ArrayList<Int64>([text.size])
    var bytes = text.size
    var next = start + 1
    while (next < spans.size && canMergeRichText(spans[start], spans[next], sizes[start], sizes[next])) {
        match (spans[next].kind) {
            case RichSpanKind.SpanText(part) =>
                joined.append(part)
                bytes += part.size
                ends.add(bytes)
            case _ => break
        }
        next += 1
    }
    (joined.toString(), next, ends.toArray())
}
