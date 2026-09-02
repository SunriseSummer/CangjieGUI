package bench_micro

import cui.{Modifier, Spacer, Widget}
import bench_harness.{report, reportCount, timeit}

private class ModifierBenchProbe {
    var steps: Int64 = 0
}

func runModifierBenches(): Unit {
    measureModifierDepth(1, 300000)
    measureModifierDepth(8, 100000)
    measureModifierDepth(128, 10000)
    measureModifierDepth(1024, 1000)
    measureModifierDepth(8192, 100)
}

private func measureModifierDepth(depth: Int64, iterations: Int64): Unit {
    let probe = ModifierBenchProbe()
    let widget: Widget = Spacer()
    let parts = modifierParts(depth, probe)
    let leftAssociated = leftModifierProduct(parts)
    let balanced = Modifier.concat(parts)
    report(
        "micro",
        "Modifier composition",
        timeit(
            "${depth} 步左结合稳定应用",
            iterations,
            {
                =>
                    let before = probe.steps
                    let _ = widget.modifier(leftAssociated)
                    probe.steps - before
            }
        )
    )
    report(
        "micro",
        "Modifier composition",
        timeit(
            "${depth} 步平衡 concat 稳定应用",
            iterations,
            {
                =>
                    let before = probe.steps
                    let _ = widget.modifier(balanced)
                    probe.steps - before
            }
        )
    )
    report(
        "micro",
        "Modifier composition",
        timeit(
            "${depth} 步左结合组合并应用",
            iterations,
            {
                =>
                    let before = probe.steps
                    let _ = widget.modifier(leftModifierProduct(parts))
                    probe.steps - before
            }
        )
    )
    report(
        "micro",
        "Modifier composition",
        timeit(
            "${depth} 步平衡 concat 并应用",
            iterations,
            {
                =>
                    let before = probe.steps
                    let _ = widget.modifier(Modifier.concat(parts))
                    probe.steps - before
            }
        )
    )
    reportCount("Modifier composition", "${depth} 步执行数", UInt64(probe.steps))
}

private func modifierParts(depth: Int64, probe: ModifierBenchProbe): Array<Modifier> {
    Array<Modifier>(depth, {_ => benchModifier(probe)})
}

private func leftModifierProduct(parts: Array<Modifier>): Modifier {
    if (parts.isEmpty()) {
        return Modifier()
    }
    var result = parts[0]
    for (index in 1..parts.size) {
        result = result.then(parts[index])
    }
    result
}

private func benchModifier(probe: ModifierBenchProbe): Modifier {
    Modifier.custom(
        {
            widget =>
                probe.steps += 1
                widget
        }
    )
}
