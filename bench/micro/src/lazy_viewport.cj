/*
 * Viewport-kernel guards: a stable height revision must remove the O(total rows) scan from steady
 * frames, while a mutable extent model must keep one-row updates logarithmic even at 100k rows.
 */
package bench_micro

import cui.{LazyList, LazyListExtents, Rect, Spacer, State, WidgetTestHost, emit}
import bench_harness.{printSection, report, reportCount, timeit}

private class LazyHeightProbe {
    var reads: Int64 = 0
    var rowsBuilt: Int64 = 0

    func height(_: Int64): Float32 {
        reads += 1
        48.0
    }

    func row(): Unit {
        rowsBuilt += 1
        emit(Spacer())
    }

    func reset(): Unit {
        reads = 0
        rowsBuilt = 0
    }
}

private class ExtentUpdateDriver {
    private let count: Int64
    private var row: Int64 = 0
    private var tall: Bool = false

    init(count: Int64) {
        this.count = count
    }

    func update(model: LazyListExtents): Unit {
        let _ = model.update(row, if (tall) {
            48.0
        } else {
            49.0
        })
        tall = !tall
        row = (row + 7919) % count
    }
}

public func runLazyViewportBench(): Unit {
    printSection("惰性视口内核")
    measureHeightRevision("10000 行 legacy 每帧高度扫描", 10000, None, 80)
    measureHeightRevision("10000 行 revision 缓存", 10000, Some(UInt64(1)), 200)
    measureExtentUpdates(100000, 300)
}

private func measureHeightRevision(name: String, rows: Int64, revision: ?UInt64, frames: Int64): Unit {
    let host = WidgetTestHost()
    let viewport = Rect(0.0, 0.0, 600.0, 720.0)
    let scroll = State<Float32>(0.0)
    let probe = LazyHeightProbe()
    let body: () -> Unit = {
        => match (revision) {
            case Some(value) => let _ = LazyList(rows, {index => probe.height(index)}, scroll: scroll,
                revision: Some(value), id: name) {_ => probe.row()}
            case None => let _ = LazyList(rows, {index => probe.height(index)}, scroll: scroll, id: name) {
                _ => probe.row()
            }
        }
    }
    let _ = host.frame(viewport, body: body)
    probe.reset()
    let result = timeit(
        name,
        frames,
        {
            =>
                let next = scroll.value + 37.0
                scroll.value = if (next >= 200000.0) {
                    0.0
                } else {
                    next
                }
                let frame = host.frame(viewport, body: body)
                frame.metrics.stabilizationPasses
        }
    )
    report("frame", "惰性视口", result)
    reportCount("惰性视口", "${name} 高度读取", UInt64(probe.reads / frames))
    reportCount("惰性视口", "${name} 实体行", UInt64(probe.rowsBuilt / frames))
}

private func measureExtentUpdates(rows: Int64, frames: Int64): Unit {
    let model = LazyListExtents(Array<Float32>(rows, {_ => 48.0}), spacing: 4.0)
    let host = WidgetTestHost()
    let viewport = Rect(0.0, 0.0, 600.0, 720.0)
    let driver = ExtentUpdateDriver(rows)
    let body: () -> Unit = {
        => LazyList(model, id: "extent.update") {_ => emit(Spacer())}
    }
    let _ = host.frame(viewport, body: body)
    report(
        "micro",
        "惰性视口",
        timeit(
            "${rows} 行单点高度更新+帧",
            frames,
            {
                =>
                    driver.update(model)
                    let frame = host.frame(viewport, body: body)
                    frame.metrics.stabilizationPasses
            }
        )
    )
}
