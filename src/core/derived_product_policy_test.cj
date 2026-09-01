package cui.core

private class DerivedProductPolicyProbe {
    var computes: Int64 = 0
    var notifications: Int64 = 0
    var previous: Int64 = -1
    var current: Int64 = -1
}

@Test
func fixedProductPolicyOverloadsFuseOneThroughFiveSources(): Unit {
    let first = State<Int64>(1)
    let second = State<Int64>(2)
    let third = State<Int64>(3)
    let fourth = State<Int64>(4)
    let fifth = State<Int64>(5)
    let policy = structuralEqualityPolicy<Int64>()

    let one = derive(first, {a => a * 2}, policy: policy)
    let two = derive(first, second, {a, b => a + b}, policy: policy)
    let three = derive(first, second, third, {a, b, c => a + b + c}, policy: policy)
    let four = derive(first, second, third, fourth, {a, b, c, d => a + b + c + d}, policy: policy)
    let five = derive(first, second, third, fourth, fifth,
        {a, b, c, d, e => a + b + c + d + e}, policy: policy)

    @Expect(one.value, Int64(2))
    @Expect(two.value, Int64(3))
    @Expect(three.value, Int64(6))
    @Expect(four.value, Int64(10))
    @Expect(five.value, Int64(15))
}

@Test
func fiveSourceFusedPolicyObservesOnlyQuotientChanges(): Unit {
    let first = State<Int64>(1)
    let second = State<Int64>(2)
    let third = State<Int64>(3)
    let fourth = State<Int64>(4)
    let fifth = State<Int64>(5)
    let probe = DerivedProductPolicyProbe()
    let parity = derive(first, second, third, fourth, fifth,
        {
            a, b, c, d, e =>
                probe.computes += 1
                (a + b + c + d + e) % 2
        }, policy: structuralEqualityPolicy<Int64>())
    let observation = parity.observe(
        {
            previous, current =>
                probe.notifications += 1
                probe.previous = previous
                probe.current = current
        })
    let scheduler = FrameScheduler()

    withFrameScheduler(
        scheduler,
        {=> scheduler.transaction({
            =>
                first.value += 1
                fifth.value -= 1
        })})
    @Expect(probe.computes, Int64(2))
    @Expect(probe.notifications, Int64(0))

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> fifth.value += 1})})
    @Expect(probe.computes, Int64(3))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(1))
    @Expect(probe.current, Int64(0))

    observation.close()
    withFrameScheduler(scheduler, {=> scheduler.transaction({=> second.value += 1})})
    @Expect(probe.notifications, Int64(1))
}
