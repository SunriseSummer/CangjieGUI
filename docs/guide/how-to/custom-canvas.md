<!-- kind: how-to; audience: component-author -->

# 编写边界清楚的自绘控件

## 目标

用 `CanvasWidget` 绘制内容，并且只消费确实属于画布的指针事件。完成后画布内点击会移动标记，画布外事件仍能到达其他控件。约需 20 分钟。

## 适用场景

图表、波形、画板、时间轴和小游戏需要直接调用渲染器时使用。标准按钮、列表和输入框已有焦点、语义与键盘行为，不应为了换颜色就全部自绘。

## 准备工作

画出控件的矩形边界，列出按下、移动、松开各自何时消费，并决定拖出边界后的策略。将要跨帧保存的数据放进模型或 `State`，绘制回调只读取快照。若自绘控件需要键盘可达，还要另行设计焦点 id、按键语义和可观察焦点样式。

## 操作步骤

### 1. 用同一个矩形绘制和命中

绘制回调和事件回调都会收到 `frame`。绘制坐标以它为边界，命中也调用 `frame.contains(x, y)`；不要复制另一套常量，否则窗口缩放后“看见的位置”和“点中的位置”会分离。

### 2. 把跨帧数据放进 State

`CanvasWidget` 实例随声明式构建重建。标记位置、选中对象和笔迹属于模型状态，不能存在控件实例字段里。

### 3. 运行可点击画布

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("自绘画布", 640, 420))
    app.run {
        let markerX = rememberState<Float32>("marker-x") {120.0}
        let markerY = rememberState<Float32>("marker-y") {100.0}
        VStack(spacing: 10.vp) {
            Label("点击画布移动标记").bold()
            CanvasWidget(
                {
                    renderer, frame =>
                        renderer.strokeLine(frame.x + 10.0, frame.y + 10.0, frame.right() - 10.0, frame.bottom() - 10.0,
                            Pen(width: 2.0, color: Color.rgb(33, 114, 229)))
                        renderer.fillCircle(markerX.value, markerY.value, 7.0, Color.rgb(246, 112, 52))
                },
                onEvent: {
                    event, frame =>
                        match (event) {
                            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                                if (frame.contains(x, y)) {
                                    markerX.value = x
                                    markerY.value = y
                                    return true
                                }
                            case _ => ()
                        }
                        false
                }
            ).flex()
            Button("画布外按钮", {=> ()})
        }.padding(16.vp)
    }
}
```

### 4. 完整处理拖动生命周期

按下必须在画布内才起笔；拖动期间可以选择裁剪到边界；处理 MouseUp 时先记录 `wasDrawing = model.endStroke()`。即使松开发生在画布外，也要结束已经开始的手势。只有 `wasDrawing` 或松开点位于画布内时才返回 `true`；普通外部松开应返回 `false`，否则画布可能吞掉工具栏按钮的松开阶段。

## 确认结果

点击画布不同位置，橙色标记应移动到指针；点击底部按钮时画布不应改变状态。缩放窗口后，对角线仍落在新矩形内，点击与绘制位置一致。为事件回调写测试时，至少覆盖画布内按下、画布外按下、拖出后松开和普通外部松开。

把画布放进带内边距、滚动或分栏的容器再重放一次，避免只在左上角原点碰巧正确。事件测试同时断言返回值：属于画布的按下为 `true`，普通外部事件为 `false`。这条断言能提前发现画布吞掉邻近按钮的回归。

## 常见错误

- 任何鼠标事件都返回 `true`：相邻控件无法点击。
- 拖出后不结束手势：指针回来时会凭空续线。
- 在绘制回调里修改模型：每帧触发重建，形成无意义循环。
- 直接把窗口坐标当局部坐标：嵌套布局或滚动后绘制错位。

## 相关 API

[CanvasWidget](../../api/cui/media/CanvasWidget.md)、[Widget](../../api/cui/core/Widget.md)；事件类型由 CUI 包入口重导出。

## 下一步

先理解[动画状态与帧预算](../concepts/animation-and-frame-budget.md)，再用[逐帧动画](animate-with-frames.md)让绘制内容平滑变化。
