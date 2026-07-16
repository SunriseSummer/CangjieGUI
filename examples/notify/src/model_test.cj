package cui_notify

import cui.ToastKind

@Test
func modelSeedsTwoToasts(): Unit {
    let model = NotifyModel()
    @Expect(model.toaster.count(), 2)
}

@Test
func notifyAddsAToastAndCounts(): Unit {
    let model = NotifyModel()
    let before = model.toaster.count()
    model.notify(ToastKind.Error)
    @Expect(model.toaster.count(), before + 1)
    @Expect(model.shown, 1)
    model.notify(ToastKind.Success)
    @Expect(model.shown, 2)
}

@Test
func messagesDifferByKindAndNumber(): Unit {
    // 消息内嵌递增编号，且随类型而异。
    @Expect(messageFor(ToastKind.Error, 3).contains("第 3 条"))
    @Expect(messageFor(ToastKind.Info, 1) != messageFor(ToastKind.Warning, 1))
    @Expect(messageFor(ToastKind.Success, 2).contains("成功"))
}
