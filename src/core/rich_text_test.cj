package cui.core

import sdl.{Color, FrameInfo, IconName, Rect, Size, UiEvent}

// A deterministic measure independent of the font backend: every rune is 10 logical pixels wide.
private let TEN_PX_PER_RUNE: (String) -> Float32 = {text => Float32(text.toRuneArray().size) * 10.0}

@Test
func richTextLaysASingleLineAndHugsItsWidth(): Unit {
    let layout = layoutRichSpans([RichSpan.text("hello")], 200.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 1)
    @Expect(layout.height, Float32(20.0)) // one line
    @Expect(layout.width, Float32(50.0)) // 5 runes * 10
    @Expect(layout.items[0].x, Float32(0.0))
    @Expect(layout.items[0].y, Float32(0.0))
}

@Test
func richTextWrapsTextAtRuneBoundaries(): Unit {
    // 10 runes * 10px = 100px into a 50px width → 5 runes per line, two lines.
    let layout = layoutRichSpans([RichSpan.text("abcdefghij")], 50.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.height, Float32(40.0)) // two lines
    @Expect(layout.items.size, 2)
    @Expect(layout.items[0].y, Float32(0.0))
    @Expect(layout.items[1].y, Float32(20.0))
    @Expect(layout.items[1].x, Float32(0.0))
}

@Test
func richTextFlowsIconsInlineWithText(): Unit {
    // icon(16) then "hi"(20): icon at 0, text after icon+gap at x=19, all on one line.
    let layout = layoutRichSpans([RichSpan.icon(IconName.Save), RichSpan.text("hi")], 100.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 2)
    @Expect(layout.height, Float32(20.0))
    @Expect(layout.items[0].x, Float32(0.0)) // icon
    @Expect(layout.items[1].x, Float32(19.0)) // text after icon (16) + gap (3)
}

@Test
func richTextWrapsAnIconThatOverflowsTheLine(): Unit {
    // "aaaa"(40) fills to x=40; the icon (16) would reach 56 > 50, so it wraps to the next line.
    let layout = layoutRichSpans([RichSpan.text("aaaa"), RichSpan.icon(IconName.Save)], 50.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    @Expect(layout.height, Float32(40.0))
    @Expect(layout.items.size, 2)
    @Expect(layout.items[1].y, Float32(20.0)) // icon on the second line
}

@Test
func richTextPreservesPerSpanColourAndMuting(): Unit {
    let red = Color.rgb(255, 0, 0)
    let layout = layoutRichSpans([
        RichSpan.text("x", color: red),
        RichSpan.muted("y"),
        RichSpan.text("z")
    ], 200.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 3)
    @Expect(layout.items[0].color.isSome()) // explicit colour
    @Expect(layout.items[1].muted) // muted run
    @Expect(layout.items[2].color.isNone())
    @Expect(!layout.items[2].muted)
}

@Test
func richTextEmptyYieldsNoItems(): Unit {
    let layout = layoutRichSpans([], 100.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 0)
    @Expect(layout.height, Float32(0.0))
    @Expect(layout.width, Float32(0.0))
}

@Test
func richTextWidgetMeasuresAndDrawsWithoutError(): Unit {
    let ctx = testContext()
    let rich = RichText([
        RichSpan.icon(IconName.Save),
        RichSpan.text(" 已保存 "),
        RichSpan.muted("09:24")
    ])
    let size = rich.measure(ctx, Size(300.0, 100.0))
    @Expect(size.h > Float32(0.0))
    rich.layout(ctx, Rect(0.0, 0.0, 300.0, size.h))
    rich.draw(ctx) // must not throw against the headless renderer
    @Expect(!rich.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(0)))))
}
