/*
 * 通知视图层：内容层 + 通知层叠放。
 *
 *  - 外层 `ZStack`：正常内容（抬头 + 弹出按钮）在下，`ToastLayer` 在上，故通知浮于内容之上。
 *  - 四个按钮各弹一种类型的通知；`ToastLayer` 负责渲染、计时、滑入/淡出，并在有通知时驱动帧刷新。
 *  - `ToastLayer` 不占布局空间、不吞事件，按钮点击照常。
 */
package cui_notify

import cui.{Button, ButtonRole, FontSizes, HStack, Label, LengthUnits, Panel, Spacer, ToastKind, ToastLayer, VStack,
    ZStack}

func notifyView(model: NotifyModel): Unit {
    ZStack {
        VStack {
            appHeader()
            triggerPanel(model)
            Spacer()
        }.spacing(16.vp).padding(20.vp)
        ToastLayer(model.toaster)
    }
}

func appHeader(): Unit {
    VStack {
        Label("通知 · Toast").fontSize(FontSizes.TITLE)
        Label("点击按钮弹出不同类型的通知，几秒后自动淡出；右下角自底向上堆叠").muted().fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func triggerPanel(model: NotifyModel): Unit {
    Panel {
        VStack {
            Label("弹出通知").muted().fontSize(FontSizes.CAPTION)
            HStack {
                Button("成功", {=> model.notify(ToastKind.Success)}).role(ButtonRole.Primary)
                Button("信息", {=> model.notify(ToastKind.Info)})
                Button("警告", {=> model.notify(ToastKind.Warning)})
                Button("错误", {=> model.notify(ToastKind.Error)}).role(ButtonRole.Danger)
            }.spacing(10.vp).hug()
        }.spacing(10.vp)
    }.contentPadding(16.vp).hug()
}
