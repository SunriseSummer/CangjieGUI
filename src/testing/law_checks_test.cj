package cui.testing

import cui.core.{Lens, Prism, stateMutationPolicy, structuralEqualityPolicy}

private class AlternatingPolicyProbe {
    var result = false

    func next(): Bool {
        result = !result
        result
    }
}

@Test
func lensLawCheckAcceptsIdentityAndIdentifiesBrokenProjection(): Unit {
    let lawful = checkLensLaws<Int64, Int64>(
        Lens<Int64, Int64>(get: {value => value}, set: {_, value => value}),
        source: 3,
        first: 5,
        second: 8
    )
    @Expect(lawful.getPut)
    @Expect(lawful.putGet)
    @Expect(lawful.putPut)
    @Expect(lawful.isLawful())

    let broken = checkLensLaws<Int64, Int64>(
        Lens<Int64, Int64>(get: {value => value}, set: {_, value => value + 1}),
        source: 3,
        first: 5,
        second: 8
    )
    @Expect(!broken.isLawful())
    @Expect(!broken.getPut || !broken.putGet || !broken.putPut)
}

@Test
func prismLawCheckCoversMatchedUnmatchedAndBrokenRoundTrips(): Unit {
    let even = Prism<Int64, Int64>(
        extract: {source => if (source % 2 == 0) { Some(source / 2) } else { None }},
        embed: {value => value * 2}
    )
    @Expect(checkPrismLaws<Int64, Int64>(even, source: 8, value: 7).isLawful())
    @Expect(checkPrismLaws<Int64, Int64>(even, source: 9, value: 7).isLawful())

    let broken = Prism<Int64, Int64>(extract: {source => Some(source)}, embed: {value => value + 1})
    let report = checkPrismLaws<Int64, Int64>(broken, source: 4, value: 7)
    @Expect(!report.extractAfterEmbed)
    @Expect(!report.embedAfterExtract)
    @Expect(!report.isLawful())
}

@Test
func policyLawCheckSeparatesEquivalenceFailuresAndDetectsNondeterminism(): Unit {
    let lawful = checkStateMutationPolicyLaws<Int64>(
        structuralEqualityPolicy<Int64>(),
        first: 0,
        second: 1,
        third: 2
    )
    @Expect(lawful.isLawful())

    let nonTransitive = checkStateMutationPolicyLaws<Int64>(
        stateMutationPolicy<Int64>({left, right =>
            left == right || left + right == 1 || left + right == 3
        }),
        first: 0,
        second: 1,
        third: 2
    )
    @Expect(nonTransitive.deterministic)
    @Expect(nonTransitive.reflexive)
    @Expect(nonTransitive.symmetric)
    @Expect(!nonTransitive.transitive)

    let probe = AlternatingPolicyProbe()
    let nondeterministic = checkStateMutationPolicyLaws<Int64>(
        stateMutationPolicy<Int64>({_, _ => probe.next()}),
        first: 0,
        second: 1,
        third: 2
    )
    @Expect(!nondeterministic.deterministic)
    @Expect(!nondeterministic.isLawful())
}

@Test
func lawChecksPropagateUserProjectionAndPolicyFailures(): Unit {
    var lensFailed = false
    try {
        let _ = checkLensLaws<Int64, Int64>(
            Lens<Int64, Int64>(
                get: {_ => throw IllegalStateException("expected Lens law failure")},
                set: {_, value => value}
            ),
            source: 1,
            first: 2,
            second: 3
        )
    } catch (_: IllegalStateException) {
        lensFailed = true
    }
    @Expect(lensFailed)

    var prismFailed = false
    try {
        let _ = checkPrismLaws<Int64, Int64>(
            Prism<Int64, Int64>(
                extract: {_ => throw IllegalStateException("expected Prism law failure")},
                embed: {value => value}
            ),
            source: 1,
            value: 2
        )
    } catch (_: IllegalStateException) {
        prismFailed = true
    }
    @Expect(prismFailed)

    var policyFailed = false
    try {
        let _ = checkStateMutationPolicyLaws<Int64>(
            stateMutationPolicy<Int64>({_, _ => throw IllegalStateException("expected policy law failure")}),
            first: 0,
            second: 1,
            third: 2
        )
    } catch (_: IllegalStateException) {
        policyFailed = true
    }
    @Expect(policyFailed)
}
