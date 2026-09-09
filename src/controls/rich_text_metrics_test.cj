package cui.controls

import sdl.FontStyle

@Test
func richTextMergesIdenticalSpansBeforeShaping(): Unit {
    let width: (String, Float32, FontStyle, ?String) -> Float32 = {
        text, _, _, _ => if (text == "AV") {
            56.0
        } else {
            Float32(text.size) * 29.0
        }
    }
    let metrics = RichTextMeasurements(width, {_, _, _ => 40.0})
    let layout = layoutRichSpans([RichSpan.text("A"), RichSpan.text("V")], [40.0, 40.0], 500.0, 16.0, 3.0, metrics)
    @Expect(layout.width, Float32(56.0))
    @Expect(layout.items.size, Int64(2))
    @Expect(layout.items[0].paintText.getOrThrow(), "AV")
    @Expect(layout.items[1].paintText.getOrThrow(), "")
    let linked = layoutRichSpans([RichSpan.text("A"), RichSpan.text("V").onTap({=> ()})], [40.0, 40.0], 500.0, 16.0, 3.0,
        metrics)
    @Expect(linked.items.size, Int64(2))
    @Expect(linked.items[1].spanIndex, Int64(1))
}

@Test
func richTextAlignsMixedSizesOnSharedBaseline(): Unit {
    let metrics = RichTextMeasurements({text, size, _, _ => Float32(text.size) * size}, {size, _, _ => size * 1.2},
        ascentOf: {size, _, _ => size})
    let layout = layoutRichSpans([RichSpan.text("Big"), RichSpan.text("small")], [30.0, 10.0], 2000.0, 16.0, 3.0,
        metrics)
    @Expect(layout.items[0].y + 30.0, layout.items[1].y + 10.0)
    @Expect(layout.height, Float32(36.0))
}

// Compatibility adapter for deterministic centered-layout fixtures; production supplies a baseline.
internal func layoutRichSpans(spans: Array<RichSpan>, sizes: Array<Float32>, width: Float32, iconSize: Float32,
    gap: Float32, widthOf: (String, Float32, FontStyle, ?String) -> Float32,
    heightOf: (Float32, FontStyle, ?String) -> Float32): RichLayout {
    layoutRichSpans(spans, sizes, width, iconSize, gap, RichTextMeasurements(widthOf, heightOf))
}
