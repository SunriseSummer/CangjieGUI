/*
 * Real SDL_ttf paragraph-layout benchmark. The stable mode rebuilds the same 20k-Han Label every
 * frame and should hit UiContext's paragraph LRU. The default churn mode walks 48 prebuilt texts;
 * their combined weight exceeds the 4 MiB cache, forcing sustained cold layouts without measuring
 * text construction or drawing thousands of off-screen lines (maxLines keeps paint bounded).
 */
package bench_text_layout

import std.collection.ArrayList
import std.env.getCommandLine
import cui.{DesktopApp, Label, State, VStack, WindowSpec}
import cui.LengthUnits
import bench_harness.ScrollSweep
import bench_scenes.{BenchAccumulator, BenchDriver}

private let TEXT_CHARS: Int64 = 20000
private let VARIANT_COUNT: Int64 = 96

main(): Int64 {
    if (pairedArgument()) {
        runTextLayout(true)
        runTextLayout(false)
        return 0
    }
    runTextLayout(stableArgument())
    0
}

private func runTextLayout(stable: Bool): Unit {
    let texts = makeVariants(TEXT_CHARS, VARIANT_COUNT)
    let selector = State<Float32>(0.0)
    let accumulator = if (stable) {
        BenchAccumulator(group: "段落布局（上机实测）", name: "20000 字 热缓存", frames: 100)
    } else {
        BenchAccumulator(group: "段落布局（上机实测）", name: "20000 字 LRU 冷抖动", scroll: selector,
            sweep: ScrollSweep(Float32(VARIANT_COUNT - 1), 1.0), frames: 100)
    }
    let app = DesktopApp(WindowSpec("CUI bench: paragraph layout", 720, 420, vsync: false, supersample: 1),
        frameDelay: 0)
    app.run {
        BenchDriver(accumulator)
        let index = Int64(selector.value) % texts.size
        VStack {
            Label(texts[index]).maxLines(8)
        }.padding(20.vp)
    }
}

private func stableArgument(): Bool {
    for (argument in getCommandLine()) {
        if (argument == "stable") {
            return true
        }
    }
    false
}

private func pairedArgument(): Bool {
    for (argument in getCommandLine()) {
        if (argument == "pair") {
            return true
        }
    }
    false
}

private func makeVariants(chars: Int64, count: Int64): Array<String> {
    let palette = "仓颉语言声明式界面框架渲染布局状态驱动组件示例文档测试性能基准长文换行段落缓存"
        .toRuneArray()
    let variants = ArrayList<String>()
    for (seed in 0..count) {
        let builder = StringBuilder()
        // A shifted periodic palette repeats after palette.size seeds. Prefix the seed so all
        // VARIANT_COUNT cache keys are genuinely distinct and the churn case exceeds 4 MiB.
        builder.append("variant-${seed}: ")
        for (index in 0..chars) {
            builder.append(palette[(index + seed) % palette.size])
        }
        variants.add(builder.toString())
    }
    variants.toArray()
}
