/*
 * Phase-three decision and evolution probes. They compare the full tree, explicit revision, and
 * automatic build dependencies while continuing to expose retained scene/event fan-out.
 * Machine records are consumed by bench/phase3_probe.py; see bench/README.md for methodology.
 */
package bench_phase3

private let SMALL_REGIONS: Int64 = 24
private let MEDIUM_REGIONS: Int64 = 96
private let LARGE_REGIONS: Int64 = 256
private let SMALL_REGION_FRAMES: Int64 = 80
private let MEDIUM_REGION_FRAMES: Int64 = 50
private let LARGE_REGION_FRAMES: Int64 = 24
private let SMALL_STATE_COUNT: Int64 = 256
private let MEDIUM_STATE_COUNT: Int64 = 2048
private let LARGE_STATE_COUNT: Int64 = 8192
private let EMPTY_STATE_FRAMES: Int64 = 120
private let SMALL_STATE_FRAMES: Int64 = 100
private let MEDIUM_STATE_FRAMES: Int64 = 50
private let LARGE_STATE_FRAMES: Int64 = 20

main(): Int64 {
    emitLine("CUI 增量架构压力与演进回归实验")
    runManualRevisionProbe()
    runAutomaticDependencyProbe()
    runLocalUpdatePressure(SMALL_REGIONS, SMALL_REGION_FRAMES)
    runLocalUpdatePressure(MEDIUM_REGIONS, MEDIUM_REGION_FRAMES)
    runLocalUpdatePressure(LARGE_REGIONS, LARGE_REGION_FRAMES)
    runRetainedStatePressure(0, EMPTY_STATE_FRAMES)
    runRetainedStatePressure(SMALL_STATE_COUNT, SMALL_STATE_FRAMES)
    runRetainedStatePressure(MEDIUM_STATE_COUNT, MEDIUM_STATE_FRAMES)
    runRetainedStatePressure(LARGE_STATE_COUNT, LARGE_STATE_FRAMES)
    runRetainedEffectPressure(0, EMPTY_STATE_FRAMES)
    runRetainedEffectPressure(SMALL_STATE_COUNT, SMALL_STATE_FRAMES)
    runRetainedEffectPressure(MEDIUM_STATE_COUNT, MEDIUM_STATE_FRAMES)
    runRetainedEffectPressure(LARGE_STATE_COUNT, LARGE_STATE_FRAMES)
    return 0
}
