package cui.core

import sdl.{FontStyle, FontWeight, FontVariations, FontVariation, Size}

@Test
func fontWeightAndSlantInheritIndependently(): Unit {
    let ctx = testContext()
    ctx.withTextStyle(TextStyle(fontWeight: FontWeight.semiBold, italic: true, underline: true)) {
        let inherited = ctx.effectiveFontStyle()
        @Expect(inherited.weight, FontWeight.semiBold)
        @Expect(inherited.italic && inherited.underline)
        ctx.withTextStyle(TextStyle(fontWeight: FontWeight.light, italic: false)) {
            @Expect(ctx.effectiveFontStyle().weight, FontWeight.light)
            @Expect(!ctx.effectiveFontStyle().italic && ctx.effectiveFontStyle().underline)
        }
        let label = Label("Inherited styles").bold(value: false)
        let expected = inherited.withWeight(FontWeight.normal)
        @Expect(label.measure(ctx, Size(1000.0, 200.0)).w,
            ctx.renderer.textWidth("Inherited styles", style: expected))
        let reset = Label("Reset").fontStyle(FontStyle.regular)
        @Expect(reset.measure(ctx, Size(1000.0, 200.0)).w, ctx.renderer.textWidth("Reset"))
    }
    @Expect(ctx.effectiveFontStyle(), FontStyle.regular)
}

@Test
func fontEnvironmentSeparatesNumericWeightsAndCoordinates(): Unit {
    let ctx = testContext()
    let first = ctx.withTextStyle(TextStyle(fontWeight: FontWeight(350)), {=> ctx.uiEnvironmentKey()})
    let second = ctx.withTextStyle(TextStyle(fontWeight: FontWeight(400)), {=> ctx.uiEnvironmentKey()})
    @Expect(!sameUiEnvironment(first, second))
    let axes = FontVariations([FontVariation("wdth", 90.0)])
    let third = ctx.withTextStyle(TextStyle(fontVariations: axes), {=> ctx.uiEnvironmentKey()})
    @Expect(!sameUiEnvironment(second, third))
    ctx.withTextStyle(TextStyle(fontVariations: axes, italic: true)) {
        let merged = mergeFontStyle(ctx.effectiveFontStyle(), FontStyle(weight: FontWeight(600)), 1)
        @Expect(merged.variations, axes)
        @Expect(merged.italic && merged.weight == FontWeight.semiBold)
    }
}

