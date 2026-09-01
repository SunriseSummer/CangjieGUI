package cui.core

private class DerivedProductProbe {
    var fourComputes: Int64 = 0
    var fourNotifications: Int64 = 0
    var fourPrevious: Int64 = 0
    var fourCurrent: Int64 = 0
    var fiveComputes: Int64 = 0
    var fiveNotifications: Int64 = 0
    var fivePrevious: Int64 = 0
    var fiveCurrent: Int64 = 0
}

@Test
func heterogeneousFourSourceDeriveStaysFusedAndObservable(): Unit {
    let first = State<Int64>(1)
    let second = State<Int32>(Int32(2))
    let third = State<UInt16>(UInt16(3))
    let fourth = State<Bool>(true)
    let probe = DerivedProductProbe()
    let scheduler = FrameScheduler()
    let four = derive(first, second, third, fourth,
        {
            a, b, c, d =>
                probe.fourComputes += 1
                a + Int64(b) + Int64(c) + if (d) {Int64(10)} else {Int64(0)}
        })

    @Expect(four.value, Int64(16))
    @Expect(four.value, Int64(16))
    @Expect(probe.fourComputes, Int64(1))
    let fourObservation = four.observe(
        {
            previous, current =>
                probe.fourNotifications += 1
                probe.fourPrevious = previous
                probe.fourCurrent = current
        })
    withFrameScheduler(scheduler, {=> scheduler.transaction({=> fourth.value = false})})
    @Expect(probe.fourComputes, Int64(2))
    @Expect(probe.fourNotifications, Int64(1))
    @Expect(probe.fourPrevious, Int64(16))
    @Expect(probe.fourCurrent, Int64(6))
    fourObservation.close()
}

@Test
func heterogeneousFiveSourceDeriveObservesOneTransactionalResult(): Unit {
    let first = State<Int64>(1)
    let second = State<Int32>(Int32(2))
    let third = State<UInt16>(UInt16(3))
    let fourth = State<Bool>(false)
    let fifth = State<String>("ok")
    let probe = DerivedProductProbe()
    let scheduler = FrameScheduler()
    let five = derive(first, second, third, fourth, fifth,
        {
            a, b, c, d, e =>
                probe.fiveComputes += 1
                a + Int64(b) + Int64(c) + if (d) {Int64(10)} else {Int64(0)} + e.size
        })
    let fiveObservation = five.observe(
        {
            previous, current =>
                probe.fiveNotifications += 1
                probe.fivePrevious = previous
                probe.fiveCurrent = current
        })
    @Expect(five.value, Int64(8))
    @Expect(probe.fiveComputes, Int64(1))

    withFrameScheduler(
        scheduler,
        {=> scheduler.transaction({
            =>
                first.value = 5
                fifth.value = "done"
        })})
    @Expect(probe.fiveNotifications, Int64(1))
    @Expect(probe.fivePrevious, Int64(8))
    @Expect(probe.fiveCurrent, Int64(14))
    @Expect(probe.fiveComputes, Int64(2))

    fiveObservation.close()
    withFrameScheduler(scheduler, {=> scheduler.transaction({=> second.value = Int32(9)})})
    @Expect(probe.fiveNotifications, Int64(1))
}
