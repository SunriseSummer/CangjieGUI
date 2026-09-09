package cui.media

import cui.core.*
import sdl.{Renderer, Rect, UiEvent, MouseButton}

@Test
func iconButtonSupportsTrailingLambdaAction(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let pressed = State<Bool>(false)
    let button = IconButton(IconSource("__test_icon.svg"), label: "Save", role: ButtonRole.Primary) {
        => pressed.value = true
    }

    button.layout(ctx, Rect(0.0, 0.0, 100.0, 34.0))

    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

/*
 * Regression: two icon-only buttons in one row used to share the "IconButton" identity.
 * The later button then swallowed the release meant for the earlier one, so a calendar's
 * previous-month chevron never fired. Build-order identities keep them separate.
 */
@Test
func iconOnlyButtonsInOneRowKeepSeparatePressIdentity(): Unit {
    let store = StateStore()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let leftClicks = State<Int64>(0)
    let rightClicks = State<Int64>(0)
    let view = buildRoot({
        => HStack {
            IconButton(IconSource("__test_icon.svg")) {
                => leftClicks.value += 1
            }
            IconButton(IconSource("__test_icon.svg")) {
                => rightClicks.value += 1
            }
        }
    }, store)

    view.layout(ctx, Rect(0.0, 0.0, 200.0, 40.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)))
    @Expect(leftClicks.value, Int64(1))
    @Expect(rightClicks.value, Int64(0))
}

@Test
func heterogeneousControlsAllJoinFocusRing(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        => VStack {
            Button("Save", {=>})
            IconButton(IconSource("__test_icon.svg"), onClick: {=>})
            Button("Cancel", {=>})
        }
    }, store)
    @Expect(store.focusRing().size, 3)
}
