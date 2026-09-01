package cui.core

private class ModifierTrace {
    var value = ""

    func append(part: String): Unit {
        value += part
    }
}

private class ModifierOrderProbe {
    var next: Int64 = 0
    var ordered = true

    func visit(expected: Int64): Unit {
        if (next != expected) {
            ordered = false
        }
        next += 1
    }
}

@Test
func modifierCompositionRunsInSourceOrderAndIsAssociative(): Unit {
    let leftTrace = ModifierTrace()
    let rightTrace = ModifierTrace()
    let leftA = tracedModifier(leftTrace, "a")
    let leftB = tracedModifier(leftTrace, "b")
    let leftC = tracedModifier(leftTrace, "c")
    let rightA = tracedModifier(rightTrace, "a")
    let rightB = tracedModifier(rightTrace, "b")
    let rightC = tracedModifier(rightTrace, "c")

    let _ = Spacer().modifier(leftA.then(leftB).then(leftC))
    let _ = Spacer().modifier(rightA.then(rightB.then(rightC)))

    @Expect(leftTrace.value, "abc")
    @Expect(rightTrace.value, "abc")
}

@Test
func identityModifierReturnsTheOriginalWidget(): Unit {
    let widget: Widget = Spacer()
    let result = widget.modifier(Modifier())

    @Expect(refEq((widget as Object).getOrThrow(), (result as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # identity law is an object identity assertion
}

@Test
func modifierCompositionPreservesOrderAcrossGrouping(): Unit {
    let leftProbe = ModifierOrderProbe()
    let rightProbe = ModifierOrderProbe()
    let left = orderedModifier(1024, leftProbe, false)
    let right = orderedModifier(1024, rightProbe, true)
    let widget: Widget = Spacer()

    let _ = widget.modifier(left)
    let _ = widget.modifier(right)

    @Expect(leftProbe.ordered)
    @Expect(rightProbe.ordered)
    @Expect(leftProbe.next, Int64(1024))
    @Expect(rightProbe.next, Int64(1024))
}

@Test
func veryDeepModifierCompositionExecutesExactlyOnce(): Unit {
    let probe = ModifierOrderProbe()
    let modifier = orderedModifier(8192, probe, false)
    let widget: Widget = Spacer()

    let result = widget.modifier(modifier)

    @Expect(probe.ordered)
    @Expect(probe.next, Int64(8192))
    @Expect(refEq((widget as Object).getOrThrow(), (result as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # every custom step is identity, so the final widget must remain identical
}

@Test
func modifierConcatBalancesRuntimeCollectionsAndPreservesIdentity(): Unit {
    let probe = ModifierOrderProbe()
    let parts = Array<Modifier>(1024, {index => tracedOrderModifier(probe, index)})
    let combined = Modifier.concat(parts)
    let widget: Widget = Spacer()
    let single = Modifier.custom({value => value})

    let _ = widget.modifier(combined)
    let emptyResult = widget.modifier(Modifier.concat([]))
    let singleResult = Modifier.concat([single])

    @Expect(probe.ordered)
    @Expect(probe.next, Int64(1024))
    @Expect(refEq((widget as Object).getOrThrow(), (emptyResult as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # the empty product is the identity transform
    @Expect(refEq((single as Object).getOrThrow(), (singleResult as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # the one-element product reuses its only modifier
}

private func orderedModifier(count: Int64, probe: ModifierOrderProbe, rightAssociated: Bool): Modifier {
    var result = Modifier()
    if (rightAssociated) {
        var index = count - 1
        while (index >= 0) {
            let expected = index
            result = tracedOrderModifier(probe, expected).then(result)
            index -= 1
        }
        return result
    }
    for (index in 0..count) {
        let expected = index
        result = result.then(tracedOrderModifier(probe, expected))
    }
    result
}

private func tracedOrderModifier(probe: ModifierOrderProbe, expected: Int64): Modifier {
    Modifier.custom({widget =>
        probe.visit(expected)
        widget
    })
}

private func tracedModifier(trace: ModifierTrace, value: String): Modifier {
    Modifier.custom(
        {
            widget =>
                trace.append(value)
                widget
        }
    )
}
