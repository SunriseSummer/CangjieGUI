/*
 * Scenario: the layout-traversal cost of a deeply nested tree. Each level wraps the previous in a
 * Panel and a VStack and adds `breadth` sibling labels, so the widget count is depth × breadth.
 * Label caches its own text measurement, so repeated layouts at a fixed size isolate the container
 * traversal and arithmetic — the overhead every stack level adds on every frame.
 */
package bench_micro

import cui.{Label, LengthUnits, Panel, Rect, VStack, Widget, emit}
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
    measureLayout("深 12 宽 6", 12, 6, 500)
    measureLayout("深 20 宽 8", 20, 8, 200)
}

private func measureLayout(name: String, depth: Int64, breadth: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let tree = nestedTree(depth, breadth)
    report("frame", "深层布局", timeit(name, frames, {=> tree.layout(ctx, rect); 0}))
}
