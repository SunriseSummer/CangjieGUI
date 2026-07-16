package cui_goals

private func approxEq(a: Float32, b: Float32): Bool {
    let d = a - b
    (if (d < 0.0) {
        -d
    } else {
        d
    }) < 0.001
}

@Test
func goalFractionClampsAndDivides(): Unit {
    @Expect(approxEq(goalFraction(5200, 8000), 0.65))
    @Expect(approxEq(goalFraction(8000, 8000), 1.0))
    @Expect(approxEq(goalFraction(10000, 8000), 1.0)) // 超出目标封顶为 1
    @Expect(approxEq(goalFraction(0, 8000), 0.0))
    @Expect(approxEq(goalFraction(5, 0), 0.0)) // 目标为零时的保护
}

@Test
func overallIsAverageOfFractions(): Unit {
    let goals = [Goal("a", "x", 10, 1), Goal("b", "x", 10, 1)]
    // 5/10 与 10/10 → (0.5 + 1.0) / 2 = 0.75
    @Expect(approxEq(overallFraction([5, 10], goals), 0.75))
    @Expect(approxEq(overallFraction([0, 0], goals), 0.0))
}

@Test
func withUpdatedIntReplacesOne(): Unit {
    let base = [1, 2, 3]
    let next = withUpdatedInt(base, 1, 20)
    @Expect(next[1], 20)
    @Expect(next[0], 1)
    @Expect(base[1], 2) // 原数组不受影响
}

@Test
func modelBumpStepsAndClamps(): Unit {
    let model = GoalsModel()
    let start = model.current(1) // 饮水初始值 6，步长 1
    model.bump(1, 1)
    @Expect(model.current(1), start + 1)
    model.bump(1, -1)
    @Expect(model.current(1), start)
    // 不能低于零。
    var i = 0
    while (i < 20) {
        model.bump(1, -1)
        i += 1
    }
    @Expect(model.current(1), 0)
}
