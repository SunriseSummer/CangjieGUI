/*
 * CUI headless benchmarks: single-point and single-scenario measurements that run without a
 * display, so they are deterministic and reproducible anywhere. Each case prints a human-readable
 * per-iteration timing plus a machine-readable @@RESULT line that bench/run.ps1 parses into the
 * HTML report. See bench/README.md for methodology and for the display-based end-to-end benchmarks.
 *
 * Run: cd bench/micro && cjpm run   (or, for the full report, bench/run.ps1)
 */
package bench_micro

main(): Int64 {
    println("CUI 基准（无头）")
    runStringScanBench()
    runDerivedBench()
    runTableSortBench(2000, 60)
    runTableSortBench(20000, 20)
    runTableEdgeBench()
    runListBench()
    runTextBench()
    runLayoutBench()
    runControlsFormBench()
    runContentScrollBench()
    runTextMeasureDiag()
    println("")
    return 0
}
