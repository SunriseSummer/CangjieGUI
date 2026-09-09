package cui.controls

@Test
func richTextHardeningPreservesMandatoryAndEmptyLines(): Unit {
    let metrics = RichTextMeasurements({text, _, _, _ => Float32(text.toRuneArray().size) * 8.0},
        {_, _, _ => 12.0}, ascentOf: {_, _, _ => 9.0})
    for (lineBreak in ["\n", "\r\n", "\r", "\u{0085}", "\u{2028}", "\u{2029}"]) {
        let layout = layoutRichSpans([RichSpan.text("A${lineBreak}${lineBreak}B${lineBreak}")], [10.0],
            500.0, 10.0, 0.0, metrics)
        @Expect(layout.lines, Int64(4))
        @Expect(layout.height, Float32(48.0))
        @Expect(layout.width, Float32(8.0))
        @Expect(layout.items[0].y, Float32(0.0))
        @Expect(layout.items[layout.items.size - 1].y, Float32(24.0))
    }
    let blank = layoutRichSpans([RichSpan.text("\n\n")], [10.0], 500.0, 10.0, 0.0, metrics)
    @Expect(blank.lines, Int64(3))
    @Expect(blank.height, Float32(36.0))
}

@Test
func richTextHardeningKeepsSourceIdentityAcrossSplitCrLf(): Unit {
    let metrics = RichTextMeasurements({text, _, _, _ => Float32(text.toRuneArray().size) * 8.0},
        {_, _, _ => 12.0}, ascentOf: {_, _, _ => 9.0})
    let layout = layoutRichSpans([RichSpan.text("A\r"), RichSpan.text("\nB").onTap({=> ()})],
        [10.0, 10.0], 500.0, 10.0, 0.0, metrics)
    @Expect(layout.lines, Int64(2))
    @Expect(layout.items[layout.items.size - 1].spanIndex, Int64(1))
    @Expect(layout.items[layout.items.size - 1].y, Float32(12.0))
}
