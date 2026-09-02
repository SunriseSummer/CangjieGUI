/*
 * CUI headless benchmarks: single-point and single-scenario measurements that run without a
 * display, so they are deterministic and reproducible anywhere. Each case prints a human-readable
 * per-iteration timing plus a machine-readable @@RESULT line that `bench run` parses into the
 * HTML report. See .dev/bench/README.md for methodology and for the display-based end-to-end benchmarks.
 *
 * Run: cd .dev/bench/workloads/headless/micro && cjpm run   (or, for the full report, python .dev/cli.py bench run)
 */
package bench_micro

import std.env.getCommandLine

main(): Int64 {
    println("CUI 基准（无头）")
    let arguments = getCommandLine()
    if (arguments.size > 1) {
        if (arguments[1] == "daily" && arguments.size > 2) {
            let reverse = arguments.size > 3 && arguments[3] == "reverse"
            if (runDailyGroup(arguments[2], reverse: reverse)) {
                return 0
            }
            println("未知日常基准组 '${arguments[2]}'；有效编号为 0..24")
            return 1
        }
        if (arguments[1] == "state") {
            runStateSchedulerBench()
            return 0
        }
        if (arguments[1] == "derived") {
            runDerivedBench()
            return 0
        }
        if (arguments[1] == "binding") {
            runBindingCompositionBench()
            return 0
        }
        if (arguments[1] == "scene-patch") {
            runScenePatchBench()
            return 0
        }
        if (arguments[1] == "automatic") {
            runAutomaticCompositionBench()
            return 0
        }
        if (arguments[1] == "declaration-replay") {
            runDeclarationReplayBench()
            return 0
        }
        if (arguments[1] == "retained") {
            runRetainedFrameBench()
            return 0
        }
        if (arguments[1] == "retained-hit") {
            runRetainedHitBench()
            return 0
        }
        if (arguments[1] == "retained-miss") {
            runRetainedMissBench()
            return 0
        }
        if (arguments[1] == "semantics-scale") {
            runSemanticsScaleBench()
            return 0
        }
        if (arguments[1] == "semantic-empty") {
            runEmptySemanticsBench()
            return 0
        }
        if (arguments[1] == "event-scale") {
            runEventScaleBench()
            return 0
        }
        if (arguments[1] == "overlay-scale") {
            runOverlayScaleBench()
            return 0
        }
        if (arguments[1] == "focus-scale") {
            runFocusScaleBench()
            return 0
        }
        if (arguments[1] == "state-scale") {
            runStateReadScaleBench()
            return 0
        }
        if (arguments[1] == "lazy-navigation") {
            runLazyNavigationScaleBench()
            return 0
        }
        if (arguments[1] == "content-scroll") {
            runContentScrollBench()
            return 0
        }
        if (arguments[1] == "observable-lazy") {
            runObservableLazyDataBench()
            return 0
        }
        if (arguments[1] == "paint-outset") {
            runPaintOutsetBench()
            return 0
        }
        if (arguments[1] == "layout") {
            runLayoutBench()
            return 0
        }
        if (arguments[1] == "feature-path") {
            runFeaturePathBenches()
            return 0
        }
        if (arguments[1] == "scoped-store") {
            runScopedStoreBenches()
            return 0
        }
        if (arguments[1] == "effect-store") {
            runEffectStoreBenches()
            return 0
        }
        if (arguments[1] == "entity-table") {
            runEntityTableBenches()
            return 0
        }
        if (arguments[1] == "identified-array") {
            runIdentifiedArrayBenches()
            return 0
        }
        if (arguments[1] == "modifier") {
            runModifierBenches()
            return 0
        }
        if (arguments[1] == "media-cache") {
            runMediaCacheBench()
            return 0
        }
        if (arguments[1] == "reducer-concat") {
            runReducerConcatBenches()
            return 0
        }
        println(
            "未知场景 '${arguments[1]}'；可用场景: state, derived, binding, scene-patch, automatic, declaration-replay, retained, retained-hit, semantics-scale, semantic-empty, event-scale, overlay-scale, focus-scale, state-scale, lazy-navigation, content-scroll, observable-lazy, paint-outset, layout, feature-path, scoped-store, effect-store, entity-table, identified-array, modifier, media-cache, reducer-concat")
        return 1
    }
    runStringScanBench()
    runDerivedBench()
    runTableSortBench(2000, 60)
    runTableSortBench(20000, 1500)
    runTableEdgeBench()
    runListBench()
    runLazyViewportBench()
    runTextBench()
    runLabelWrapBench()
    runLayoutBench()
    runControlsFormBench()
    runContentScrollBench()
    runObservableLazyDataBench()
    runRebuildPhaseBench()
    runLargeRebuildPhaseBench()
    runInstanceReuseBench()
    runLargeInstanceReuseBench()
    runAutomaticCompositionBench()
    runDeclarationReplayBench()
    runRetainedFrameBench()
    runStateSchedulerBench()
    runScalabilityProbeBench()
    runOverlayScaleBench()
    runPaintOutsetBench()
    runTextMeasureDiag()
    println("")
    return 0
}

// The report runner executes these groups in isolated processes and rotates their order across
// samples. Keeping the mapping beside the default sequence prevents process lifetime/GC history
// from becoming an undocumented part of any individual benchmark definition.
private func runDailyGroup(group: String, reverse!: Bool = false): Bool {
    if (group == "0") {
        runStringScanBench()
    } else if (group == "1") {
        runDerivedBench()
    } else if (group == "2") {
        runTableSortBench(2000, 60)
        runTableSortBench(20000, 1500)
        runTableEdgeBench()
    } else if (group == "3") {
        runListBench()
    } else if (group == "4") {
        runLazyViewportBench()
    } else if (group == "5") {
        runTextBench()
    } else if (group == "6") {
        runLabelWrapBench()
    } else if (group == "7") {
        runLayoutBench()
    } else if (group == "8") {
        runControlsFormBench()
    } else if (group == "9") {
        runContentScrollBench(reverse: reverse)
    } else if (group == "10") {
        runObservableLazyDataBench()
    } else if (group == "11") {
        runRebuildPhaseBench()
    } else if (group == "12") {
        runAutomaticCompositionBench()
    } else if (group == "13") {
        runDeclarationReplayBench()
    } else if (group == "14") {
        runRetainedFrameBench()
    } else if (group == "15") {
        runStateSchedulerBench(includeModelStore: false)
    } else if (group == "16") {
        runDailyScalabilityWithoutLazyBench()
    } else if (group == "17") {
        runOverlayScaleBench()
    } else if (group == "18") {
        runPaintOutsetBench()
    } else if (group == "19") {
        runTextMeasureDiag()
    } else if (group == "20") {
        runLargeInstanceReuseBench()
    } else if (group == "21") {
        runInstanceReuseBench()
    } else if (group == "22") {
        runLazyNavigationScaleBench(reverse: reverse)
    } else if (group == "23") {
        runModelStoreBenches()
    } else if (group == "24") {
        runLargeRebuildPhaseBench()
    } else {
        return false
    }
    true
}
