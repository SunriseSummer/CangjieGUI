/*
 * CUI micro-benchmarks: isolated single-scenario measurements, run headless so they work without
 * a display. Each scenario prints its per-iteration timing. See bench/README.md for methodology
 * and for the end-to-end (display-based) benchmarks.
 *
 * Run: cd bench/micro && cjpm run
 */
package bench_micro

main(): Int64 {
    println("CUI micro-benchmarks (headless)")
    runTableSortBench(2000, 60)
    runTableSortBench(20000, 20)
    runStringScanBench()
    println("")
    return 0
}
