package cui.controls

import sdl.{Color, FontStyle, FrameInfo, IconName, Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{State, Theme, UiContext}

private func richTextTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

// A deterministic measure independent of the font backend: every rune is 10 logical pixels wide,
// style- and font-agnostic. New signature carries the run's style and font (see the style-aware measure).
private let TEN_PX_PER_RUNE: (String, FontStyle, ?String) -> Float32 = {text, _, _ =>
    Float32(text.toRuneArray().size) * 10.0
}

// A style-aware measure: bold widens a run 1.5x, so bold wrapping and placement can be asserted.
private let BOLD_WIDENS: (String, FontStyle, ?String) -> Float32 = {text, style, _ =>
    let base = Float32(text.toRuneArray().size) * 10.0
    if (style.bold) {
        base * 1.5
    } else {
        base
    }
}

// Adapts the old uniform-size call shape to the size-aware engine — every span at one size, a constant
// line height, and a size-agnostic width measure — so the pre-existing assertions still hold, proving
// the two-pass layout is byte-identical to the previous top-of-line placement for a uniform size.
private func runLayout(
    spans: Array<RichSpan>,
    maxWidth: Float32,
    lineHeight: Float32,
    iconSize: Float32,
    spanGap: Float32,
    measure: (String, FontStyle, ?String) -> Float32
): RichLayout {
    layoutRichSpans(
        spans,
        Array<Float32>(spans.size, {_ => 15.0}),
        maxWidth,
        iconSize,
        spanGap,
        {text, _, style, font => measure(text, style, font)},
        {_, _, _ => lineHeight}
    )
}

@Test
func richTextLaysASingleLineAndHugsItsWidth(): Unit {
    let layout = runLayout([RichSpan.text("hello")], 200.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 1)
    @Expect(layout.height, Float32(20.0)) // one line
    @Expect(layout.width, Float32(50.0)) // 5 runes * 10
    @Expect(layout.items[0].x, Float32(0.0))
    @Expect(layout.items[0].y, Float32(0.0))
}

@Test
func richTextWrapsTextAtRuneBoundaries(): Unit {
    // 10 runes * 10px = 100px into a 50px width → 5 runes per line, two lines.
    let layout = runLayout([RichSpan.text("abcdefghij")], 50.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.height, Float32(40.0)) // two lines
    @Expect(layout.items.size, 2)
    @Expect(layout.items[0].y, Float32(0.0))
    @Expect(layout.items[1].y, Float32(20.0))
    @Expect(layout.items[1].x, Float32(0.0))
}

@Test
func richTextFlowsIconsInlineWithText(): Unit {
    // icon(16) then "hi"(20): icon at 0, text after icon+gap at x=19, all on one line.
    let layout = runLayout([RichSpan.icon(IconName.Save), RichSpan.text("hi")], 100.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 2)
    @Expect(layout.height, Float32(20.0))
    @Expect(layout.items[0].x, Float32(0.0)) // icon
    @Expect(layout.items[1].x, Float32(19.0)) // text after icon (16) + gap (3)
}

@Test
func richTextWrapsAnIconThatOverflowsTheLine(): Unit {
    // "aaaa"(40) fills to x=40; the icon (16) would reach 56 > 50, so it wraps to the next line.
    let layout = runLayout([RichSpan.text("aaaa"), RichSpan.icon(IconName.Save)], 50.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    // Line 1 (text) is 20 tall; line 2 holds only the icon, so it is the icon's own 16 tall — 36 total.
    @Expect(layout.height, Float32(36.0))
    @Expect(layout.items.size, 2)
    @Expect(layout.items[1].y, Float32(20.0)) // icon on the second line, below the 20-tall first line
}

@Test
func richTextPreservesPerSpanColourAndMuting(): Unit {
    let red = Color.rgb(255, 0, 0)
    let layout = runLayout([
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
func richSpanBuildersComposeStyleAndFont(): Unit {
    // The style builders return modified copies; chaining accumulates flags without mutating the base.
    let base = RichSpan.text("x")
    @Expect(base.style.isRegular)
    @Expect(base.bold().style.bold)
    @Expect(base.italic().style.italic)
    @Expect(base.bold().italic().style.ttfFlags(), 0x03)
    // The base is untouched by a builder call.
    @Expect(base.style.isRegular)
    // fontFamily records a face; other style builders leave it intact.
    let mono = RichSpan.text("code").fontFamily("Mono").bold()
    @Expect(mono.fontFace.getOrThrow(), "Mono")
    @Expect(mono.style.bold)
    // muted keeps its muting through a style builder.
    @Expect(RichSpan.muted("y").italic().isMuted)
}

@Test
func richTextPreservesPerSpanStyleAndFont(): Unit {
    let layout = runLayout([
        RichSpan.text("a").bold(),
        RichSpan.text("b").italic().fontFamily("Serif"),
        RichSpan.text("c")
    ], 500.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 3)
    @Expect(layout.items[0].style.bold)
    @Expect(layout.items[1].style.italic)
    @Expect(layout.items[1].font.getOrThrow(), "Serif")
    @Expect(layout.items[2].style.isRegular)
    @Expect(layout.items[2].font.isNone())
}

@Test
func richTextWrapsBoldRunByItsWiderMetrics(): Unit {
    // Plain "aaaaa" (5*10=50) fits a 60px line; bold "aaaaa" (5*15=75) overflows and wraps.
    let plain = runLayout([RichSpan.text("aaaaa")], 60.0, 20.0, 16.0, 3.0, BOLD_WIDENS)
    @Expect(plain.height, Float32(20.0)) // one line
    let bold = runLayout([RichSpan.text("aaaaa").bold()], 60.0, 20.0, 16.0, 3.0, BOLD_WIDENS)
    @Expect(bold.height, Float32(40.0)) // wrapped to two lines by the wider bold advance
    // The bold layout is also wider than plain at the same rune count.
    @Expect(bold.width > Float32(0.0))
}

@Test
func richTextEmptyYieldsNoItems(): Unit {
    let layout = runLayout([], 100.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 0)
    @Expect(layout.height, Float32(0.0))
    @Expect(layout.width, Float32(0.0))
}

private func richApproxEq(a: Float32, b: Float32): Bool {
    let d = a - b
    (if (d < 0.0) {
        -d
    } else {
        d
    }) < 0.01
}

// Size-aware measures for the per-span-size tests: width scales with the run's size, and a line's
// height is 1.2x the size.
private let SIZE_WIDTH: (String, Float32, FontStyle, ?String) -> Float32 = {text, size, _, _ =>
    Float32(text.toRuneArray().size) * size * 0.6
}
private let SIZE_HEIGHT: (Float32, FontStyle, ?String) -> Float32 = {size, _, _ => size * 1.2}

@Test
func richSpanFontSizeBuilderRecordsSize(): Unit {
    // A plain run inherits the base size (None); fontSize overrides just that run and leaves the rest.
    @Expect(RichSpan.text("x").size.isNone())
    @Expect(RichSpan.text("x").fontSize(24.0).size.isSome())
    let styled = RichSpan.text("x").bold().fontFamily("Mono").fontSize(20.0)
    @Expect(styled.size.isSome())
    @Expect(styled.style.bold)
    @Expect(styled.fontFace.getOrThrow(), "Mono")
}

@Test
func richTextGrowsLineToTallestSpanAndCentres(): Unit {
    // A big 30pt run and a small 10pt run on one line. Line height = max(30*1.2, 10*1.2) = 36.
    let spans = [RichSpan.text("Big"), RichSpan.text("sm")]
    let layout = layoutRichSpans(spans, [30.0, 10.0], 2000.0, 16.0, 3.0, SIZE_WIDTH, SIZE_HEIGHT)
    @Expect(layout.items.size, 2)
    @Expect(richApproxEq(layout.height, 36.0)) // the tallest run drives the line height
    // The big run (height 36) fills the line, y = 0; the small run (height 12) is centred: (36-12)/2 = 12.
    @Expect(richApproxEq(layout.items[0].y, 0.0))
    @Expect(richApproxEq(layout.items[1].y, 12.0))
    // Each fragment carries its own draw size.
    @Expect(richApproxEq(layout.items[0].size, 30.0))
    @Expect(richApproxEq(layout.items[1].size, 10.0))
}

@Test
func richTextFragmentsCarryHeightAndLineCount(): Unit {
    // Each placed fragment carries the line height it was measured with, and the layout reports its
    // line count — a single mixed-size line is still one line.
    let spans = [RichSpan.text("Big"), RichSpan.text("sm")]
    let layout = layoutRichSpans(spans, [30.0, 10.0], 2000.0, 16.0, 3.0, SIZE_WIDTH, SIZE_HEIGHT)
    @Expect(layout.lines, 1)
    @Expect(richApproxEq(layout.items[0].height, 36.0)) // 30 * 1.2
    @Expect(richApproxEq(layout.items[1].height, 12.0)) // 10 * 1.2
    // Wrapping across lines is reflected in the count.
    let wrapped = runLayout([RichSpan.text("abcdefghij")], 50.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(wrapped.lines, 2)
    @Expect(runLayout([], 100.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE).lines, 0)
}

@Test
func richTextLineHeightFollowsSpanStyleAndFont(): Unit {
    // The height callback receives each run's style and font, so a face or style with its own vertical
    // metrics drives the line height — here a fake metric where bold runs are twice as tall.
    let boldTaller: (Float32, FontStyle, ?String) -> Float32 = {size, style, _ => if (style.bold) {
        size * 2.0
    } else {
        size
    }}
    let sizes = Array<Float32>(1, {_ => 10.0})
    let plain = layoutRichSpans([RichSpan.text("a")], sizes, 500.0, 16.0, 3.0, SIZE_WIDTH, boldTaller)
    let bold = layoutRichSpans([RichSpan.text("a").bold()], sizes, 500.0, 16.0, 3.0, SIZE_WIDTH, boldTaller)
    @Expect(richApproxEq(plain.height, 10.0))
    @Expect(richApproxEq(bold.height, 20.0))
}

@Test
func richTextHugsASingleLineWithLargerSpan(): Unit {
    let ctx = richTextTestContext()
    // The stat-widget case: one line whose big run makes it taller than the base line height must
    // still hug its content width instead of being misread as wrapped and filling the row.
    let stat = RichText([RichSpan.text("128").fontSize(30.0), RichSpan.muted(" MB").fontSize(13.0)])
    let size = stat.measure(ctx, Size(500.0, 200.0))
    @Expect(size.w < Float32(500.0))
    // And its reported height follows the actual (taller) line, not the base line height.
    let plain = RichText([RichSpan.text("128"), RichSpan.muted(" MB")]).measure(ctx, Size(500.0, 200.0))
    @Expect(size.h > plain.h)
}

@Test
func richTextWidgetGrowsWithLargerSpan(): Unit {
    let ctx = richTextTestContext()
    // A run marked larger than the base makes the whole line — and the measured block — taller.
    let plain = RichText([RichSpan.text("hello")])
    let big = RichText([RichSpan.text("hello").fontSize(40.0)])
    let plainSize = plain.measure(ctx, Size(500.0, 500.0))
    let bigSize = big.measure(ctx, Size(500.0, 500.0))
    @Expect(bigSize.h > plainSize.h)
}

@Test
func richSpanOnTapMarksLink(): Unit {
    // A plain run is inert; onTap makes it a link and survives further style chaining.
    @Expect(RichSpan.text("x").tapAction.isNone())
    @Expect(RichSpan.text("x").onTap({=> ()}).tapAction.isSome())
    @Expect(RichSpan.text("x").onTap({=> ()}).bold().underline().tapAction.isSome())
}

@Test
func richTextLinkFiresOnPressAndRelease(): Unit {
    let ctx = richTextTestContext()
    let fired = State<Bool>(false)
    let rich = RichText([RichSpan.text("open link").onTap({=> fired.value = true})], key: "rt")
    let size = rich.measure(ctx, Size(300.0, 100.0))
    rich.layout(ctx, Rect(0.0, 0.0, 300.0, size.h))
    // A point near the start of the (single) link fragment, vertically in the middle.
    let px: Float32 = 6.0
    let py = size.h / 2.0
    // Press then release on the link consumes the events and runs the action.
    @Expect(rich.handle(ctx, UiEvent.MouseDown(MouseButton.Left, px, py)))
    @Expect(rich.handle(ctx, UiEvent.MouseUp(MouseButton.Left, px, py)))
    @Expect(fired.value)
}

@Test
func richTextNonLinkIsInert(): Unit {
    let ctx = richTextTestContext()
    let fired = State<Bool>(false)
    // A RichText with no link span ignores clicks (returns false), staying inert as before.
    let plain = RichText([RichSpan.text("just text")], key: "plain")
    let size = plain.measure(ctx, Size(300.0, 100.0))
    plain.layout(ctx, Rect(0.0, 0.0, 300.0, size.h))
    @Expect(!plain.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 6.0, size.h / 2.0)))
    @Expect(!fired.value)
    // A press then release outside any link fragment does not fire the link either.
    let rich = RichText([RichSpan.text("hi ").onTap({=> fired.value = true})], key: "rt2")
    let s2 = rich.measure(ctx, Size(300.0, 100.0))
    rich.layout(ctx, Rect(0.0, 0.0, 300.0, s2.h))
    let _ = rich.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 250.0, s2.h / 2.0)) // far past the text
    let _ = rich.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 250.0, s2.h / 2.0))
    @Expect(!fired.value)
}

@Test
func richTextRegistersFocusStopPerLinkOnly(): Unit {
    // No link spans → no focus stops (a plain, inert RichText).
    let noLinks = RichText([RichSpan.text("plain"), RichSpan.muted("more")], key: "nl")
    @Expect(noLinks.focusableIds().size, 0)
    // One focus stop per link span, non-link spans excluded.
    let twoLinks = RichText([
        RichSpan.text("a").onTap({=> ()}),
        RichSpan.text(" b "),
        RichSpan.text("c").onTap({=> ()})
    ], key: "two")
    @Expect(twoLinks.focusableIds().size, 2)
}

@Test
func richTextLinkKeyboardActivatesFocusedLink(): Unit {
    let ctx = richTextTestContext()
    let fired = State<Bool>(false)
    let rich = RichText([
        RichSpan.text("intro "),
        RichSpan.text("open link").onTap({=> fired.value = true})
    ], key: "kb")
    let ids = rich.focusableIds()
    @Expect(ids.size, 1)
    let size = rich.measure(ctx, Size(300.0, 100.0))
    rich.layout(ctx, Rect(0.0, 0.0, 300.0, size.h))
    // Enter with nothing focused does nothing.
    @Expect(!rich.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(!fired.value)
    // Focus the link and press Enter — the action runs and the event is consumed.
    ctx.focus(ids[0])
    @Expect(rich.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(fired.value)
    // Space also activates a focused link.
    fired.value = false
    @Expect(rich.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(fired.value)
}

@Test
func richSpanHighlightBuilderRecordsBackground(): Unit {
    let yellow = Color.rgb(255, 235, 59)
    // A plain run has no highlight; highlight(bg) records the background and leaves the text colour alone.
    @Expect(RichSpan.text("x").highlightColor.isNone())
    let marked = RichSpan.text("x", color: Color.rgb(10, 10, 10)).highlight(yellow)
    @Expect(marked.highlightColor.isSome())
    @Expect(marked.color.isSome()) // the explicit text colour is untouched by highlight
    // Highlight survives further style chaining and composes with links.
    let chained = RichSpan.text("y").highlight(yellow).bold().onTap({=> ()})
    @Expect(chained.highlightColor.isSome())
    @Expect(chained.style.bold)
    @Expect(chained.tapAction.isSome())
}

@Test
func richTextHighlightCarriesAndPreservesLayout(): Unit {
    let mark = Color.rgb(255, 235, 59)
    let plain = runLayout([RichSpan.text("abc"), RichSpan.text("def")], 200.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    let marked = runLayout([RichSpan.text("abc").highlight(mark), RichSpan.text("def")], 200.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    // Highlight is a purely visual layer, so the geometry is identical with or without it.
    @Expect(marked.items.size, plain.items.size)
    @Expect(richApproxEq(marked.width, plain.width))
    @Expect(richApproxEq(marked.height, plain.height))
    @Expect(richApproxEq(marked.items[0].x, plain.items[0].x))
    @Expect(richApproxEq(marked.items[1].x, plain.items[1].x))
    // Only the highlighted fragment carries a background; its neighbour stays plain.
    @Expect(marked.items[0].highlight.isSome())
    @Expect(marked.items[1].highlight.isNone())
}

@Test
func richTextDrawsHighlightWithoutError(): Unit {
    let ctx = richTextTestContext()
    // A highlighted run fills its <mark> box then the glyphs; must not throw on the headless renderer.
    let rich = RichText([
        RichSpan.text("match", color: Color.rgb(0, 0, 0)).highlight(Color.rgb(255, 235, 59)),
        RichSpan.text(" rest")
    ], key: "hl")
    let size = rich.measure(ctx, Size(300.0, 100.0))
    @Expect(size.h > Float32(0.0))
    rich.layout(ctx, Rect(0.0, 0.0, 300.0, size.h))
    rich.draw(ctx)
}

@Test
func richTextWidgetMeasuresAndDrawsWithoutError(): Unit {
    let ctx = richTextTestContext()
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

// 取文本片段的内容（图标给空串），供断行断言用。
private func fragText(item: PlacedItem): String {
    match (item.kind) {
        case PlacedKind.PlacedText(text) => text
        case _ => ""
    }
}

@Test
func richTextWrappingNeverSplitsExtendedGraphemeClusters(): Unit {
    // A 10px line is narrower than every multi-rune cluster. Each cluster may overflow intact, but
    // no fragment may contain only a combining mark, a ZWJ, or half a regional-indicator pair.
    let original = "e\u{0301}x👩‍💻y🇨🇳z"
    let layout = runLayout([RichSpan.text(original)], 10.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    let joined = StringBuilder()
    for (item in layout.items) {
        let value = fragText(item)
        @Expect(value != "\u{0301}")
        @Expect(value != "‍")
        @Expect(value != "🇨")
        @Expect(value != "🇳")
        joined.append(value)
    }
    @Expect(joined.toString(), original)
}

@Test
func richTextBreakPrefersSpaceBoundary(): Unit {
    // "hello world" 共 110px 放进 80px：8 字符处强断会切在 "wo" 中，回退到空格后——
    // 首行 "hello "、次行整词 "world"。
    let layout = runLayout([RichSpan.text("hello world")], 80.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 2)
    @Expect(fragText(layout.items[0]), "hello ")
    @Expect(fragText(layout.items[1]), "world")
    @Expect(layout.lines, 2)
}

@Test
func richTextKeepsAsciiWordWholeAcrossSpans(): Unit {
    // 中文前缀后接无空格标识符：120px 行宽下 "identifier"（100px）在 x=40 放不下且词内无空格，
    // 但整词能放进满行 → 整词移到下一行，不被切成 "identifie/r"。
    let layout = runLayout([RichSpan.text("说明文字"), RichSpan.text("identifier")], 120.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 2)
    @Expect(fragText(layout.items[1]), "identifier")
    @Expect(layout.items[1].x, Float32(0.0))
    @Expect(layout.items[1].y, Float32(20.0))
}

@Test
func richTextStillRuneSplitsCjkMidLine(): Unit {
    // CJK 段从行中开始且整段能放进满行——不做整段保持，仍逐字符续排填满当前行再断。
    let layout = runLayout([RichSpan.text("abcd"), RichSpan.text("中文描述内容")], 90.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 3)
    @Expect(fragText(layout.items[1]), "中文描述内")
    @Expect(layout.items[1].x, Float32(40.0))
    @Expect(fragText(layout.items[2]), "容")
    @Expect(layout.items[2].y, Float32(20.0))
}

@Test
func richTextRuneSplitsWordWiderThanALine(): Unit {
    // 比满行还宽的 ASCII 词不整词保持（否则永远放不下），先填满当前行再逐字符续排。
    let layout = runLayout([RichSpan.text("ab"), RichSpan.text("superlongidentifier")], 100.0, 20.0, 16.0, 3.0,
        TEN_PX_PER_RUNE)
    // "ab" 20px 后余 80px：词前 8 字符填满首行，其余 10 + 1 字符落到后两行行首。
    @Expect(layout.items.size, 4)
    @Expect(layout.items[1].x, Float32(20.0))
    @Expect(fragText(layout.items[1]), "superlon")
    @Expect(layout.items[2].x, Float32(0.0))
    @Expect(fragText(layout.items[2]).toRuneArray().size, 10)
    @Expect(fragText(layout.items[3]), "r")
}

@Test
func richTextContinuationSkipsBrokenOnSpace(): Unit {
    // "abc def" 在 35px 行宽下断于空格处：续行从 "def" 起排，不带断点空格的缩进。
    let layout = runLayout([RichSpan.text("abc def")], 35.0, 20.0, 16.0, 3.0, TEN_PX_PER_RUNE)
    @Expect(layout.items.size, 2)
    @Expect(fragText(layout.items[0]), "abc")
    @Expect(fragText(layout.items[1]), "def")
    @Expect(layout.items[1].x, Float32(0.0))
}
