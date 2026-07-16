package cui.controls

import sdl.{MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{Theme, UiContext}

private func badgeTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

@Test
func badgeMeasuresPill(): Unit {
    let ctx = badgeTestContext()
    let badge = Badge("进行中", kind: BadgeKind.Info)
    let size = badge.measure(ctx, Size(200.0, 100.0))
    let height: Float32 = 22.0
    let zero: Float32 = 0.0
    @Expect(size.h, height)
    @Expect(size.w > zero)
}

@Test
func badgeIsPureDisplay(): Unit {
    let ctx = badgeTestContext()
    let badge = Badge("标签")
    badge.layout(ctx, Rect(0.0, 0.0, 60.0, 22.0))
    @Expect(!badge.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)))
}

@Test
func badgeColorsBySemantics(): Unit {
    let ctx = badgeTestContext()
    // Fixed semantic palette.
    @Expect(Int64(badgeColor(ctx, BadgeKind.Success).g), 158)
    @Expect(Int64(badgeColor(ctx, BadgeKind.Warning).r), 198)
    @Expect(Int64(badgeColor(ctx, BadgeKind.Info).b), 214)
    // Theme-tracking kinds mirror the theme's own colors.
    @Expect(Int64(badgeColor(ctx, BadgeKind.Neutral).r), Int64(ctx.theme.mutedText.r))
    @Expect(Int64(badgeColor(ctx, BadgeKind.Danger).r), Int64(ctx.theme.danger.r))
    @Expect(Int64(badgeColor(ctx, BadgeKind.Accent).b), Int64(ctx.theme.accent.b))
}
