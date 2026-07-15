/*
 * A content-dense, vertically scrollable page modeled on the planner overview: metric cards in a
 * grid, a progress panel, and wrapping chips, repeated `blocks` times.
 *
 * ScrollView does not window generic container content — every descendant is measured, laid out
 * and drawn each frame whether on screen or not — so this scene is the honest per-frame cost of
 * scrolling a long composed page, and that cost grows with `blocks`. The scroll offset is
 * externally owned so a headless benchmark (sweeping it) and a display driver (animating it)
 * exercise the identical tree.
 */
package bench_scenes

import cui.{FlowRow, FontSizes, Grid, Label, LazyColumn, LengthUnits, Panel, ProgressBar, ScrollView, Size, State,
    UiContext, VStack, Widget}

private let SCENE_HEADING: Float32 = 16.0
// Fixed row height for the virtualized page, matched to the block's measured natural height (330
// logical pixels at the bench width; see contentBlockHeight). LazyColumn forces each row to exactly
// this height, so it must equal the item's height or rows overlap. 1 vp == 1 logical pixel, so this
// is scale-independent. Reflowing content (the chips wrap at very narrow widths) is why fixed-height
// virtualization wants stable-height items — see LazyColumn's doc comment.
private let LAZY_BLOCK_HEIGHT: Float32 = 330.0

/** Builds the scrollable content page over `blocks` repeated sections, bound to `scroll`. */
public func contentScrollScene(scroll: State<Float32>, blocks: Int64): Widget {
    let view = ScrollView(key: "bench.content") {
        VStack {
            var i = 0
            while (i < blocks) {
                contentBlock(i)
                i += 1
            }
        }.spacing(14.vp).flexible(false)
    }
    view.scrollState(scroll)
    view
}

private func contentBlock(index: Int64): Unit {
    Panel {
        VStack {
            Label("专注区块 ${index}").fontSize(SCENE_HEADING)
            Label("把今天最重要的事，放在注意力最清醒的时段").muted().fontSize(FontSizes.CAPTION)
            Grid(3) {
                metricCard("专注时长", "3 小时 25 分", "比昨日多 35 分钟")
                metricCard("完成任务", "8 / 12", "两项正在进行")
                metricCard("能量峰值", "10:00 至 12:00", "适合高认知任务")
            }.spacing(12.vp)
            ProgressBar(State<Float32>(progressFor(index))).height(20.vp).fillWidth()
            FlowRow {
                chip("先完成方案评审")
                chip("整理访谈纪要")
                chip("回复协作消息")
                chip("散步与补水")
            }.spacing(10.vp)
        }.spacing(12.vp).flexible(false)
    }.contentPadding(16.vp)
}

private func metricCard(title: String, value: String, caption: String): Unit {
    Panel {
        VStack {
            Label(title).muted().fontSize(FontSizes.CAPTION)
            Label(value).fontSize(SCENE_HEADING)
            Label(caption).muted().fontSize(FontSizes.CAPTION)
        }.spacing(5.vp).flexible(false)
    }.contentPadding(14.vp)
}

private func chip(text: String): Unit {
    Panel {
        Label(text).fontSize(FontSizes.CAPTION)
    }.contentPadding(12.vp).width(210.vp)
}

// A stable fill fraction in [0, 1] so progress bars vary block to block without randomness.
private func progressFor(index: Int64): Float32 {
    Float32(index % 10) / 10.0
}

/*
 * The same content page as `contentScrollScene`, but virtualized with LazyColumn: only the rows near
 * the viewport are built, laid out and drawn, so the per-frame cost is O(visible) instead of
 * O(blocks). Blocks are uniform, so a fixed row height fits LazyColumn's model.
 */
public func lazyContentScrollScene(scroll: State<Float32>, blocks: Int64): Widget {
    LazyColumn(blocks, LAZY_BLOCK_HEIGHT, spacing: 12.0, scroll: scroll, id: "bench.lazy") {
        index => contentBlock(index)
    }
}

/** The natural height of one content block at `width` — used to verify the LazyColumn row height. */
public func contentBlockHeight(ctx: UiContext, width: Float32): Float32 {
    let probe = VStack {
        contentBlock(0)
    }.flexible(false)
    probe.measure(ctx, Size(width, 100000.0)).h
}
