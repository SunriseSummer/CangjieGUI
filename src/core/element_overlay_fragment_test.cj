package cui.core

import sdl.{Renderer, UiEvent}

private class ElementOverlayFragmentProbe {
    var trace = ""
}

private func elementOverlay(probe: ElementOverlayFragmentProbe, owner: String, value: String): Overlay {
    Overlay(
        handleEvent: {_, _ => false},
        render: {_ => probe.trace += value},
        owner: owner
    )
}

@Test
func overlaySnapshotIfAnyFromSkipsEmptyAndNormalizesOnlyTheSuffix(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = ElementOverlayFragmentProbe()
    @Expect(context.overlaySnapshotIfAnyFrom(0).isNone())

    context.setOverlay(elementOverlay(probe, "base", "base"))
    let start = context.overlayRegistrationCount()
    context.setOverlay(elementOverlay(probe, "popup", "stale"))
    context.setOverlay(elementOverlay(probe, "popup", "fresh"))
    context.setOverlay(elementOverlay(probe, "tip", "tip"))
    let suffix = context.overlaySnapshotIfAnyFrom(start).getOrThrow()

    context.clearActiveOverlay()
    context.registerOverlayFragment(suffix)
    context.drawActiveOverlay()
    @Expect(probe.trace, "freshtip")
    @Expect(context.overlayCount(), Int64(2))
    @Expect(!context.dispatchOverlay(UiEvent.Unknown(UInt32(0))))
}

@Test
func overlaySnapshotIfAnyFromReusesAnAdoptedWholeFragmentBehavior(): Unit {
    let source = UiContext(Renderer.headless(), Theme.light())
    let target = UiContext(Renderer.headless(), Theme.light())
    let probe = ElementOverlayFragmentProbe()
    let snapshot = overlaySnapshotFromRegistrations([
        elementOverlay(probe, "dialog", "dialog"),
        elementOverlay(probe, "popup", "popup")
    ])
    source.registerOverlayFragment(snapshot)

    let captured = source.overlaySnapshotIfAnyFrom(0).getOrThrow()
    @Expect(refEq(snapshot, captured))
    target.registerOverlayFragment(captured)
    target.drawActiveOverlay()

    @Expect(probe.trace, "dialogpopup")
    @Expect(target.overlayCount(), Int64(2))
    @Expect(overlayFragmentReplayVisits(target), UInt64(0))
}
