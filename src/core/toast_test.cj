package cui.core

import sdl.{FrameInfo, Size, UiEvent}

@Test
func toasterShowAddsAndTickExpires(): Unit {
    let toaster = Toaster()
    toaster.show("hello", durationMs: 1000)
    @Expect(toaster.count(), 1)
    toaster.tick(500)
    @Expect(toaster.count(), 1) // still within its lifetime
    toaster.tick(600) // 1100 total ≥ 1000 → removed
    @Expect(toaster.count(), 0)
}

@Test
func toasterExpiresIndependentlyByDuration(): Unit {
    let toaster = Toaster()
    toaster.show("short", durationMs: 300)
    toaster.show("long", durationMs: 2000)
    @Expect(toaster.count(), 2)
    toaster.tick(400) // short is gone, long remains
    @Expect(toaster.count(), 1)
    @Expect(toaster.snapshot()[0].message, "long")
    toaster.tick(2000)
    @Expect(toaster.count(), 0)
}

@Test
func toasterSnapshotKeepsPostOrder(): Unit {
    let toaster = Toaster()
    toaster.show("a")
    toaster.show("b")
    toaster.show("c")
    let snap = toaster.snapshot()
    @Expect(snap.size, 3)
    @Expect(snap[0].message, "a") // oldest first
    @Expect(snap[2].message, "c") // newest last
}

@Test
func toastLayerTicksToasterAndRequestsFramesWhileActive(): Unit {
    let ctx = testContext()
    let toaster = Toaster()
    toaster.show("x", durationMs: 1000)
    let layer = ToastLayer(toaster)

    // A frame ages the toast and, because one is alive, asks the loop for another frame.
    @Expect(!layer.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(100)))))
    @Expect(toaster.count(), 1)
    @Expect(ctx.takeFrameRequest()) // requestFrame was called (and is now cleared)

    // Drain the toast; with none alive, no further frame is requested.
    toaster.tick(2000)
    @Expect(toaster.count(), 0)
    let _ = layer.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(100))))
    @Expect(!ctx.takeFrameRequest())
}

@Test
func toastLayerTakesNoLayoutSpace(): Unit {
    let ctx = testContext()
    let layer = ToastLayer(Toaster())
    @Expect(!layer.participatesInLayout())
    @Expect(layer.measure(ctx, Size(300.0, 200.0)).h, Float32(0.0))
}
