package bench_micro

import cui.{LazyColumn, Rect, Spacer, State, WidgetTestHost}
import bench_harness.{BenchResult, printSection, report, timeit}

private let OBSERVABLE_LAZY_ITEMS: Int64 = 10000
private let OBSERVABLE_LAZY_FRAMES: Int64 = 4000

public func runObservableLazyDataBench(): Unit {
    printSection("可观察惰性数据（手工 revision vs State 自动版本）")
    let values = Array<Int64>(OBSERVABLE_LAZY_ITEMS, {index => index})
    let manualData = State<Array<Int64>>(values)
    let observedData = State<Array<Int64>>(values)
    let manualHost = WidgetTestHost()
    let observedHost = WidgetTestHost()
    let viewport = Rect(0.0, 0.0, 300.0, 180.0)
    let manualBody: () -> Unit = {
        =>
            let snapshot = manualData.value
            LazyColumn.of(snapshot, 40.0, key: {value => "row.${value}"}, revision: manualData.revision,
                id: "bench.observable") {_ => Spacer()}
    }
    let observedBody: () -> Unit = {
        => LazyColumn.of(observedData, 40.0, key: {value => "row.${value}"},
            id: "bench.observable") {_ => Spacer()}
    }
    let _ = manualHost.frame(viewport, body: manualBody)
    let _ = observedHost.frame(viewport, body: observedBody)

    let blocks: Int64 = 16
    let blockFrames = OBSERVABLE_LAZY_FRAMES / blocks
    var manualNs: UInt64 = UInt64(0)
    var observedNs: UInt64 = UInt64(0)
    var manualChecksum: Int64 = 0
    var observedChecksum: Int64 = 0
    for (block in 0..blocks) {
        if (block % 2 == 0) {
            let manual = measureFrames(manualHost, viewport, manualBody, blockFrames)
            manualNs += manual.totalNs
            manualChecksum += manual.checksum
            let observed = measureFrames(observedHost, viewport, observedBody, blockFrames)
            observedNs += observed.totalNs
            observedChecksum += observed.checksum
        } else {
            let observed = measureFrames(observedHost, viewport, observedBody, blockFrames)
            observedNs += observed.totalNs
            observedChecksum += observed.checksum
            let manual = measureFrames(manualHost, viewport, manualBody, blockFrames)
            manualNs += manual.totalNs
            manualChecksum += manual.checksum
        }
    }
    report("frame", "可观察惰性数据",
        BenchResult("10000 项 显式 snapshot+revision", OBSERVABLE_LAZY_FRAMES, manualNs, manualChecksum))
    report("frame", "可观察惰性数据",
        BenchResult("10000 项 State 自动版本", OBSERVABLE_LAZY_FRAMES, observedNs, observedChecksum))
}

private func measureFrames(
    host: WidgetTestHost,
    viewport: Rect,
    body: () -> Unit,
    iterations: Int64
): BenchResult {
    timeit("interleaved chunk", iterations, {
        =>
            let _ = host.frame(viewport, body: body)
            0
    })
}
