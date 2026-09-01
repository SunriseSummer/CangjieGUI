package cui.core

@Test
func eventOutcomeCombinationObeysJoinSemilatticeLaws(): Unit {
    let a = EventOutcome.Handled
    let b = EventOutcome.StopPropagation
    let c = EventOutcome.Continue

    expectSameOutcome(a.combined(c), a)
    expectSameOutcome(a.combined(a), a)
    expectSameOutcome(a.combined(b), b.combined(a))
    expectSameOutcome(a.combined(b).combined(c), a.combined(b.combined(c)))
    expectSameOutcome(a.combined(b), EventOutcome.Consume)
    @Expect(eventOutcomeHandled(a.combined(b)) && eventOutcomeStopped(a.combined(b)))
}

private func expectSameOutcome(actual: EventOutcome, expected: EventOutcome): Unit {
    @Expect(eventOutcomeHandled(actual), eventOutcomeHandled(expected))
    @Expect(eventOutcomeStopped(actual), eventOutcomeStopped(expected))
}
