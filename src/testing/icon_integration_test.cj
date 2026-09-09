package cui.testing

import cui.core.{HStack, SemanticsAction, State}
import cui.media.{Icon, IconButton, IconSource, ImageStatus, clearImageCache, imageCacheStats, invalidateIcon}
import sdl.{Color, Rect, SdlWindow, Surface, WindowSpec}
import sdl.system.FileSystem

private class RetainedIconProbe { var icon: ?Icon = None }

@Test
func retainedIconFailureRecoversWithoutRebuildingItsOwner(): Unit {
    let path = "__retained_icon_recovery.png"
    if (FileSystem.exists(path)) { FileSystem.remove(path) }
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Retained icon recovery", 80, 60, supersample: 1), hidden: true)) {
        let host = WidgetTestHost(renderer: window.renderer)
        let probe = RetainedIconProbe()
        let source = IconSource(path)
        let build = {=> probe.icon = Some(Icon(source))}
        let bounds = Rect(0.0, 0.0, 80.0, 60.0)
        try {
            window.renderer.beginScene(80.0, 60.0, Color.rgb(255, 255, 255))
            let _ = host.frame(bounds, body: build)
            let first = probe.icon.getOrThrow()
            @Expect(match (first.status()) { case ImageStatus.Failed => true; case _ => false })
            let misses = imageCacheStats().misses
            let _ = host.frame(bounds, body: build)
            @Expect(imageCacheStats().misses, misses)
            try (surface = Surface.create(8, 8)) {
                surface.clear(Color.rgb(0, 0, 0))
                surface.savePng(path)
            }
            invalidateIcon(source)
            let _ = host.frame(bounds, body: build)
            @Expect(refEq(first, probe.icon.getOrThrow()))
            @Expect(match (first.status()) { case ImageStatus.Ready => true; case _ => false })
            @Expect(imageCacheStats().misses, misses + UInt64(1))
            window.renderer.endScene()
        } finally {
            host.reset()
            clearImageCache()
            if (FileSystem.exists(path)) { FileSystem.remove(path) }
        }
    }
}

@Test
func disabledIconButtonIsRemovedFromFocusAndCannotActivateBySemantics(): Unit {
    let host = WidgetTestHost()
    let enabled = State<Bool>(true)
    let clicks = State<Int64>(0)
    let body: () -> Unit = {=>
        HStack {
            IconButton("__first.svg", onClick: {=> clicks.value += 1}).accessibilityLabel("First").key("first").enabled(enabled.value)
            IconButton("__second.svg", onClick: {=> clicks.value += 1}).accessibilityLabel("Second").key("second")
        }
    }
    try {
        let _ = host.frame(Rect(0.0, 0.0, 160.0, 50.0), body: body)
        host.context.focus("first")
        enabled.value = false
        let _ = host.frame(Rect(0.0, 0.0, 160.0, 50.0), body: body)
        @Expect(host.context.focusId != "first")
        @Expect(!host.context.performSemanticsAction("first", SemanticsAction.Activate))
        @Expect(host.context.performSemanticsAction("second", SemanticsAction.Activate))
        @Expect(clicks.value, 1)
    } finally { host.reset(); clearImageCache() }
}
