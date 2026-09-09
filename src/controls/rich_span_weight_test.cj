package cui.controls

import sdl.{FontStyle, FontWeight}

@Test
func richSpanWeightBuildersPreserveInheritedSlantAndDecoration(): Unit {
    let inherited = FontStyle(weight: FontWeight.light, italic: true, underline: true)
    let span = RichSpan.text("weight").fontWeight(FontWeight.semiBold).inheritedStyle(inherited)
    @Expect(span.style.weight, FontWeight.semiBold)
    @Expect(span.style.italic && span.style.underline)
    let upright = RichSpan.text("upright").italic(value: false).inheritedStyle(inherited)
    @Expect(!upright.style.italic && upright.style.underline)
    @Expect(upright.style.weight, FontWeight.light)
    let reset = RichSpan.text("reset").fontStyle(FontStyle.regular).inheritedStyle(inherited)
    @Expect(reset.style, FontStyle.regular)
}
