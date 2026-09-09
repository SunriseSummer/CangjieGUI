package cui.controls

import cui.core.{State, Theme, UiContext}
import sdl.{MouseButton, Rect, Renderer, UiEvent}

@Test
func sliderConstructorSortsBoundsLikeRangeModifier(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Float32>(5.0)
    let slider = Slider(value, lower: 10.0, upper: 0.0)
    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    let _ = slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0))
    @Expect(value.value, Float32(5.0))
}

@Test
func discreteSliderHandlesNonFiniteDataAndSubnormalSteps(): Unit {
    let value = State<Float32>(Float32.NaN)
    let _ = Slider(value, step: 0.1)
    @Expect(value.value, Float32(0.0))
    value.value = 0.5
    let _ = Slider(value, step: 1.0e-40)
    @Expect(value.value, Float32(0.5))
}

@Test
func valueControlsRejectNonFiniteConfiguration(): Unit {
    let value = State<Float32>(0.0)
    var rejected = 0
    try { let _ = Slider(value, lower: Float32.NaN) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { let _ = Slider(value, step: Float32.NaN) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { let _ = ProgressBar(value, upper: Float32.NaN) } catch (_: IllegalArgumentException) { rejected += 1 }
    @Expect(rejected, 3)
}
