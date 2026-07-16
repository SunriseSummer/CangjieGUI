package cui.core

import sdl.{MouseButton, Rect, Renderer, Size, UiEvent}

private func bcTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

@Test
func breadcrumbItemsShowAllWhenShort(): Unit {
    @Expect(breadcrumbItems(3, 0), [0, 1, 2]) // no cap
    @Expect(breadcrumbItems(4, 5), [0, 1, 2, 3]) // cap ≥ count
    @Expect(breadcrumbItems(0, 4), []) // empty trail
}

@Test
func breadcrumbItemsCollapseMiddle(): Unit {
    @Expect(breadcrumbItems(7, 4), [0, -1, 4, 5, 6]) // first + … + last 3
    @Expect(breadcrumbItems(5, 3), [0, -1, 3, 4]) // first + … + last 2
    @Expect(breadcrumbItems(6, 2), [0, -1, 5]) // first + … + last 1
}

@Test
func breadcrumbMeasuresRow(): Unit {
    let ctx = bcTestContext()
    let bc = Breadcrumb(["首页", "文档"])
    let size = bc.measure(ctx, Size(400.0, 100.0))
    let height: Float32 = 28.0
    let zero: Float32 = 0.0
    @Expect(size.h, height)
    @Expect(size.w > zero)
}

@Test
func breadcrumbClicksLinkSegment(): Unit {
    let ctx = bcTestContext()
    let picked = State<Int64>(-1)
    let bc = Breadcrumb(["首页", "文档", "项目"], onSelect: {i => picked.value = i})
    bc.layout(ctx, Rect(20.0, 40.0, 400.0, 28.0))
    // The first crumb starts at x=20; clicking just inside it selects index 0 (it is a link, not the current).
    @Expect(bc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 24.0, 54.0)))
    @Expect(picked.value, 0)
}

@Test
func breadcrumbCurrentNotClickable(): Unit {
    let ctx = bcTestContext()
    let picked = State<Int64>(-1)
    let bc = Breadcrumb(["只有当前"], onSelect: {i => picked.value = i})
    bc.layout(ctx, Rect(20.0, 40.0, 400.0, 28.0))
    // A lone segment is the current location, so it does not act as a link.
    @Expect(!bc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 24.0, 54.0)))
    @Expect(picked.value, -1)
}

@Test
func breadcrumbDisplayOnlyIgnoresClicks(): Unit {
    let ctx = bcTestContext()
    let bc = Breadcrumb(["首页", "文档", "项目"]) // no onSelect → pure display
    bc.layout(ctx, Rect(20.0, 40.0, 400.0, 28.0))
    @Expect(!bc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 24.0, 54.0)))
}

@Test
func breadcrumbCollapsedClicksFirst(): Unit {
    let ctx = bcTestContext()
    let picked = State<Int64>(-1)
    let bc = Breadcrumb(["A", "B", "C", "D", "E", "F", "G"], onSelect: {i => picked.value = i}, maxItems: 4)
    bc.layout(ctx, Rect(20.0, 40.0, 500.0, 28.0))
    // items = [0, -1, 4, 5, 6]; the first crumb still sits at the left edge and links to index 0.
    @Expect(bc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 24.0, 54.0)))
    @Expect(picked.value, 0)
}
