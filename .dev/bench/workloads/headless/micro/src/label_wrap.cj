/*
 * 场景：一段超长中文文本在固定宽度里整段换行（条款、公告类页面把长文直接交给 Label.wrap）。
 * 换行引擎逐行求「最大可容纳字符数」，每行度量串的长度决定成本：gallop 定界让每行只度量
 * 几个行宽级的前缀；若按旧法对整段剩余文本反复构串探测，两万字文本是数量级的差距。
 * 每帧重建 Label（即时模式的真实形态），度量含换行缓存的冷启动成本。
 */
package bench_micro

import cui.{Label, Size}
import bench_harness.{printSection, report, reportCount, timeit}

public func runLabelWrapBench(): Unit {
    printSection("长文换行（Label.wrap）")
    measureWrap("2000 字", 2000, 120)
    measureWrap("20000 字", 20000, 24)
    measureMixedUnicodeWrap()
}

private func measureWrap(name: String, chars: Int64, frames: Int64): Unit {
    let text = makeLongText(chars)
    measureColdAndWarm(name, text, frames)
}

private func measureMixedUnicodeWrap(): Unit {
    let unit = "Cafe\u{0301} 👩‍💻 🇨🇳 中文（标点） a\u{00A0}b — paragraph。"
    let builder = StringBuilder()
    for (_ in 0..200) {
        builder.append(unit)
    }
    measureColdAndWarm("混合 Unicode", builder.toString(), 40)
}

private func measureColdAndWarm(name: String, text: String, frames: Int64): Unit {
    let coldFrames = max(Int64(3), min(Int64(12), frames / 4))
    report("frame", "长文换行（冷）", timeit(name, coldFrames, {=>
        let cold = headlessContext()
        let label = Label(text).wrap()
        let size = label.measure(cold, Size(320.0, 1000000.0))
        Int64(size.h)
    }))

    let ctx = headlessContext()
    let warmup = Label(text).wrap()
    let _ = warmup.measure(ctx, Size(320.0, 1000000.0))
    ctx.resetParagraphCacheStats()
    report("frame", "长文换行", timeit(name, frames, {=>
        let label = Label(text).wrap()
        let size = label.measure(ctx, Size(320.0, 1000000.0))
        Int64(size.h)
    }))
    let stats = ctx.paragraphCacheStats()
    reportCount("段落缓存", "${name} 命中", stats.hits)
    reportCount("段落缓存", "${name} 未命中", stats.misses)
}

// 以固定字符盘循环生成 n 字中文文本；相邻行内容不同，贴近真实段落的前缀分布。
private func makeLongText(chars: Int64): String {
    let palette = "仓颉语言声明式界面框架渲染布局状态驱动组件示例文档测试性能基准超长文本换行引擎按行度量前缀二分定界避免整段探测每帧成本数量级差异条款公告页面把长文交给标签自动折行滚动视图配合虚拟化列表呈现大量内容真实场景覆盖中西混排标点符号与空格断点优先规则回退逐字符切分保证进展".toRuneArray()
    let builder = StringBuilder()
    for (i in 0..chars) {
        builder.append(palette[i % palette.size])
    }
    builder.toString()
}
