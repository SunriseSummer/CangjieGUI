package cui.desktop

import sdl.{Rect, SdlWindow, Size, UiEvent, WindowSpec}
import std.env.getVariable
import std.sort.sort
import cui.core.{Button, Semantics, SemanticsNode, SemanticsRole, UiContext, VStack, Widget, ZStack, emit}
import cui.testing.WidgetTestHost

private class UiaScaleWidget <: Widget {
    private let id: String

    init(index: Int64) {
        id = "uia-scale-${index}"
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        ctx.registerSemantics(SemanticsNode(id, Semantics(label: id, role: SemanticsRole.Button), rect))
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@When[os == "Windows"]
@Test
func windowsUiaAbiRejectsMismatchedVersionAndLayouts(): Unit {
    let nodeLayout = windowsUiaNodeLayout()
    let changeLayout = windowsUiaChangeLayout()
    @Expect(windowsUiaAbiCompatible(UInt64(2), nodeLayout, changeLayout))
    @Expect(!windowsUiaAbiCompatible(UInt64(1), nodeLayout, changeLayout))
    @Expect(!windowsUiaAbiCompatible(UInt64(2), nodeLayout + UInt64(1), changeLayout))
    @Expect(!windowsUiaAbiCompatible(UInt64(2), nodeLayout, changeLayout + UInt64(1)))
}

@When[os == "Windows"]
@Test
func windowsUiaStringArenaEncodesUtf8OffsetsAndTerminators(): Unit {
    let nodes = [SemanticsNode("节点-🙂", Semantics(label: "按钮", value: "值-✓", hint: "提示"),
        Rect(0.0, 0.0, 20.0, 10.0))]
    let arena = createStringArena(nodes)
    @Expect(arena.offsets[0], Int64(0))
    @Expect(arena.offsets[1], "节点-🙂".size + Int64(1))
    @Expect(arena.offsets[2], arena.offsets[1] + "按钮".size + Int64(1))
    @Expect(arena.offsets[3], arena.offsets[2] + "值-✓".size + Int64(1))
    @Expect(arena.bytes[arena.offsets[1] - Int64(1)], UInt8(0))
    @Expect(arena.bytes[arena.offsets[2] - Int64(1)], UInt8(0))
    @Expect(arena.bytes[arena.offsets[3] - Int64(1)], UInt8(0))
    @Expect(arena.bytes[arena.bytes.size - Int64(1)], UInt8(0))
}

@When[os == "Windows"]
@Test
func windowsUiaBridgePublishesHierarchyAndFocusRevisions(): Unit {
    let window = SdlWindow(WindowSpec("CUI UIA provider test", 240, 100, vsync: false, supersample: 1))
    try {
        let windows = requireWindowsUiaBridge(window)
        try {
            verifySmallWindowsUiaPublication(window, windows)
            verifyStableWindowsUiaScale(window, windows)
            @Expect(windows.nativeNodeCount(), Int64(10000))
        } finally {
            windows.close()
        }
    } finally {
        window.close()
    }
}

@When[os == "Windows"]
private func requireWindowsUiaBridge(window: SdlWindow): WindowsUiaBridge {
    match (createDesktopAccessibilityBridge(window)) {
        case Some(value) => match (value as WindowsUiaBridge) {
            case Some(windows) => windows
            case None => throw IllegalStateException("Windows bridge has an unexpected implementation")
        }
        case None => throw IllegalStateException("Windows UIA bridge could not resolve the SDL HWND")
    }
}

@When[os == "Windows"]
private func verifySmallWindowsUiaPublication(window: SdlWindow, windows: WindowsUiaBridge): Unit {
    let host = WidgetTestHost(renderer: window.renderer)
    host.context.setAccessibilityAdapter(windows)
    let body: () -> Unit = {
        => VStack {
            Button("Alpha", {=>}).key("uia-alpha")
            Button("Beta", {=>}).key("uia-beta")
        }.semantics(Semantics(label: "Actions", role: SemanticsRole.List), key: "uia-actions")
    }
    let _ = host.frame(Rect(0.0, 0.0, 240.0, 100.0), body: body)
    @Expect(windows.nativeRevision(), UInt64(1))
    @Expect(windows.nativeNodeCount(), Int64(3))
    host.context.focus("uia-alpha")
    let _ = host.frame(Rect(0.0, 0.0, 240.0, 100.0), body: body)
    @Expect(windows.nativeRevision(), UInt64(2))
    @Expect(host.context.semanticsTreeSnapshot().focusedId, "uia-alpha")
}

@When[os == "Windows"]
private func verifyStableWindowsUiaScale(window: SdlWindow, windows: WindowsUiaBridge): Unit {
    let body: () -> Unit = {
        => ZStack {
            for (index in 0..Int64(10000)) {
                UiaScaleWidget(index)
            }
        }
    }
    let host = WidgetTestHost(renderer: window.renderer)
    host.context.setAccessibilityAdapter(windows)
    let scale = host.frame(Rect(0.0, 0.0, 240.0, 100.0), body: body)
    println("@@UIA_SCALE|nodes=10000|commit_ns=${scale.metrics.semanticsNs}")
    @Expect(windows.nativeNodeCount(), Int64(10000))
    // Coverage instrumentation deliberately changes every branch and clock window. Keep this
    // performance gate on normal optimized tests while coverage runs retain all deterministic
    // publication/revision assertions below.
    match (getVariable("GCOV_PREFIX")) {
        case Some(_) => ()
        case None => @Expect(scale.metrics.semanticsNs < UInt64(100000000))
    }
    let publishedRevision = windows.nativeRevision()
    for (_ in 0..3) {
        let _ = host.frame(Rect(0.0, 0.0, 240.0, 100.0), body: body)
    }
    let stableSamples = Array<UInt64>(5, repeat: UInt64(0))
    for (index in 0..stableSamples.size) {
        stableSamples[index] = host.frame(Rect(0.0, 0.0, 240.0, 100.0), body: body).metrics.semanticsNs
    }
    sort(stableSamples)
    let stableP50 = stableSamples[2]
    println("@@UIA_SCALE_STABLE|nodes=10000|p50_ns=${stableP50}|samples=${stableSamples}")
    @Expect(stableP50 < UInt64(250000))
    @Expect(windows.nativeRevision(), publishedRevision)
    @Expect(windows.nativeRevision(), host.context.semanticsTreeSnapshot().revision)
}
