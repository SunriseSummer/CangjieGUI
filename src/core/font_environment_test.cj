package cui.core

import sdl.{Size, FontStyle, UiEvent}

@Test
func paragraphCacheTracksRasterScaleWithoutDisplayScaleChange(): Unit {
    let ctx = testContext()
    let text = "AVAVAV office iiiWWWmmm 0123456789"
    let first = Label(text).fontSize(13.fp).wrap()
    first.measure(ctx, Size(120.0, 600.0))
    @Expect(ctx.paragraphCacheStats().misses, UInt64(1))
    ctx.renderer.setScale(2.0)
    first.measure(ctx, Size(120.0, 600.0))
    @Expect(ctx.paragraphCacheStats().misses, UInt64(2))
    Label(text).fontSize(13.fp).wrap().measure(ctx, Size(120.0, 600.0))
    @Expect(ctx.paragraphCacheStats().hits, UInt64(1))
}

@Test
func buttonHeightAccommodatesUserFontScale(): Unit {
    let ctx = testContext()
    let button = Button("Font scale", {=> ()})
    let normal = button.measure(ctx, Size(500.0, 200.0))
    for (scale in [Float32(1.25), Float32(1.5), Float32(2.0)]) {
        ctx.fontScale = scale
        let large = button.measure(ctx, Size(500.0, 200.0))
        @Expect(large.h >= normal.h)
        @Expect(large.h >= ctx.textHeight() + 12.0)
    }
    @Expect(button.measure(ctx, Size(500.0, 200.0)).h > normal.h)
}

@Test
func inheritedTextDefaultsRespectOverridesAndRestoreCaches(): Unit {
    let ctx = testContext()
    let label = Label("AV office")
    let available = Size(800.0, 200.0)
    let base = label.measure(ctx, available)
    let style = TextStyle(fontSize: 24.fp, fontStyle: FontStyle(bold: true), fontFamily: "Scoped")
    let styled = ctx.withTextStyle(style, {=> label.measure(ctx, available)})
    @Expect(styled.w > base.w)
    let again = ctx.withTextStyle(style, {=> label.measure(ctx, available)})
    @Expect(again.w, styled.w)
    @Expect(label.measure(ctx, available).w, base.w)
    ctx.withTextStyle(style) {
        @Expect(ctx.textSize(), Float32(24.0))
        @Expect(ctx.effectiveFontStyle().bold)
        @Expect(ctx.renderer.effectiveFontFamily().getOrThrow(), "Scoped")
        let explicit = Label("AV office").fontSize(12.fp).fontStyle(FontStyle.regular).measure(ctx, available)
        @Expect(explicit.w, ctx.renderer.textWidth("AV office", pointSize: 12.0))
        ctx.withTextStyle(TextStyle(fontSize: 18.fp)) {
            @Expect(ctx.textSize(), Float32(18.0))
            @Expect(ctx.effectiveFontStyle().bold)
            @Expect(ctx.renderer.effectiveFontFamily().getOrThrow(), "Scoped")
        }
    }
    @Expect(ctx.renderer.effectiveFontFamily().isNone())
    @Expect(!ctx.effectiveFontStyle().bold)
}

@Test
func textStyleModifierAppliesToMeasureAndDeferredOverlay(): Unit {
    let ctx = testContext()
    let styled = Button("Large", {=> ()}).textStyle(TextStyle(fontSize: 32.fp))
    @Expect(styled.measure(ctx, Size(500.0, 200.0)).h >= ctx.renderer.textHeight(pointSize: 32.0) + 12.0)
    let renderedSize = State<Float32>(0.0)
    let eventSize = State<Float32>(0.0)
    ctx.withTextStyle(TextStyle(fontSize: 29.fp, fontFamily: "OverlayFont")) {
        ctx.setOverlay(Overlay(owner: "styled-popup", render: {c => renderedSize.value = c.textSize()},
            handleEvent: {c, _ => eventSize.value = c.textSize(); true}))
    }
    ctx.drawActiveOverlay()
    @Expect(ctx.dispatchOverlay(UiEvent.Unknown(UInt32(0))))
    @Expect(renderedSize.value, Float32(29.0))
    @Expect(eventSize.value, Float32(29.0))
    @Expect(ctx.renderer.effectiveFontFamily().isNone())
}
