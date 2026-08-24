package cui.controls

import sdl.{Rect, Renderer, Size}
import cui.core.{State, Theme, UiContext}

@Test
func segmentedControlNaturalWidthTracksItsWidestLabelAndRespectsConstraints(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let selected = State<Int64>(0)
    let short = SegmentedControl(["One", "Two", "Three"], selected)
    let descriptive = SegmentedControl(["系统默认 System", "衬线 Serif", "等宽 Monospace"], selected)

    @Expect(short.measure(ctx, Size(1000.0, 80.0)).w, 288.0)
    let natural = descriptive.measure(ctx, Size(1000.0, 80.0)).w
    @Expect(natural > 288.0)
    @Expect(natural < 1000.0)
    @Expect(descriptive.measure(ctx, Size(180.0, 80.0)).w, 180.0)
}

@Test
func segmentedControlEllipsizesAndClipsEveryLabelInsideItsCell(): Unit {
    let renderer = Renderer.headless()
    let ctx = UiContext(renderer, Theme.light())
    let selected = State<Int64>(0)
    let longLabel = "系统默认 System"
    let control = SegmentedControl([longLabel, "衬线 Serif", "等宽 Monospace"], selected)
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    let fitted = fittedSegmentLabel(ctx, longLabel, 60.0)
    @Expect(fitted != longLabel)
    @Expect(fitted.contains("…"))
    @Expect(renderer.textWidth(fitted) <= 36.0)
    let commands = renderer.recordCommands {control.draw(ctx)}
    @Expect(commands.stats().clipCommandCount, Int64(6))
    @Expect(renderer.currentClip().isNone())
}
