package cui_wizard

@Test
func startsAtFirstStepAndCannotAdvanceUntilValid(): Unit {
    let model = WizardModel()
    @Expect(model.step.value, 0)
    @Expect(!model.canAdvance()) // email 为空
    model.email.value = "a@b.com"
    @Expect(model.canAdvance())
}

@Test
func nextAndBackWalkTheSteps(): Unit {
    let model = WizardModel()
    model.email.value = "a@b.com"
    model.next()
    @Expect(model.step.value, 1)
    model.displayName.value = "林小满"
    model.next()
    @Expect(model.step.value, 2)
    model.back()
    @Expect(model.step.value, 1)
}

@Test
func nextIsBlockedByFailedValidation(): Unit {
    let model = WizardModel()
    // 步骤 0 要求填写 email；未填写时 next() 无任何效果。
    model.next()
    @Expect(model.step.value, 0)
}

@Test
func goToOnlyJumpsToReachedSteps(): Unit {
    let model = WizardModel()
    model.email.value = "a@b.com"
    model.next() // 此时处于步骤 1
    // 可跳回已完成的步骤。
    model.goTo(0)
    @Expect(model.step.value, 0)
    // 越过当前步骤向前跳转被拒绝。
    model.goTo(3)
    @Expect(model.step.value, 0)
}

@Test
func lastStepReportsAndReset(): Unit {
    let model = WizardModel()
    model.email.value = "a@b.com"
    model.displayName.value = "林小满"
    model.next() // 1
    model.next() // 2
    model.next() // 3 (完成)
    @Expect(model.isLast())
    @Expect(!model.canAdvance()) // 最后一步不能再前进
    model.goTo(0) // "重新开始"
    @Expect(model.step.value, 0)
}

@Test
func advanceLabelSwitchesBeforeLastStep(): Unit {
    @Expect(advanceLabel(0, 3), "下一步")
    @Expect(advanceLabel(2, 3), "提交") // 最后一步之前的步骤显示提交
    @Expect(themeLabel(1), "深色")
}
