/*
 * Scenario: the layout-traversal cost of a deeply nested tree. Each level wraps the previous in a
 * Panel and a VStack and adds `breadth` sibling labels, so the widget count is depth × breadth.
 * The stable-instance case isolates exact-constraint measure memoization inside one committed tree;
 * the rebuild case reconstructs and measures the whole tree each iteration, matching ordinary
 * immediate-mode frames. Reporting both prevents an instance-local cache from disguising rebuild cost.
 */
package bench_micro

import cui.{Label, LengthUnits, Panel, Rect, Size, VStack, Widget, emit}
import bench_harness.{printSection, report, timeit}

private func leafRow(breadth: Int64): Widget {
    VStack {
        var i = 0
        while (i < breadth) {
            Label("叶节点 ${i}")
            i += 1
        }
    }.spacing(6.vp).flexible(false)
}

private func wrap(inner: Widget, breadth: Int64): Widget {
    Panel {
        VStack {
            emit(inner)
            var i = 0
            while (i < breadth) {
                Label("层级标签 ${i}")
                i += 1
            }
        }.spacing(6.vp).flexible(false)
    }.contentPadding(8.vp)
}

private func nestedTree(depth: Int64, breadth: Int64): Widget {
    var tree = leafRow(breadth)
    var d = 0
    while (d < depth) {
        tree = wrap(tree, breadth)
        d += 1
    }
    tree
}

public func runLayoutBench(): Unit {
    printSection("深层嵌套布局")
    // Each sample runs for roughly 100 ms or more: shorter layout loops amplify scheduler jitter
    // enough to hide single-digit regressions, especially on Windows power-managed CPUs.
    measureLayout("深 12 宽 6", 12, 6, 4000)
    measureLayout("深 20 宽 8", 20, 8, 2500)
    measureRebuiltLayout("深 12 宽 6", 12, 6, 1600)
    measureRebuiltLayout("深 20 宽 8", 20, 8, 800)
}

private func measureRebuiltLayout(name: String, depth: Int64, breadth: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    report(
        "frame",
        "深层布局（逐帧重建）",
        timeit(
            name,
            frames,
            {
                =>
                    let tree = nestedTree(depth, breadth)
                    let _ = tree.measure(ctx, Size(rect.w, rect.h))
                    tree.layout(ctx, rect)
                    0
            }
        )
    )
}

private func measureLayout(name: String, depth: Int64, breadth: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let tree = nestedTree(depth, breadth)
    let _ = tree.measure(ctx, Size(rect.w, rect.h))
    report(
        "frame",
        "深层布局",
        timeit(
            name,
            frames,
            {
                =>
                    tree.layout(ctx, rect)
                    0
            }
        )
    )
}
