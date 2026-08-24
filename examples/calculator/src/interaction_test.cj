package cui_calculator

import cui.{Button, MouseButton, Rect, UiEvent, WidgetTestHost}

private class DisplayBuildTrace {
    var calls: Int64 = 0
    var last = ""

    func record(value: String): Unit {
        calls += 1
        last = value
    }
}

// 回归：普通字段不会推进帧调度代次，曾导致 MouseUp 后仍绘制旧 Label；可视状态必须
// 在同一事件事务内失效，使宿主在 draw 前稳定重建。
@Test
func calculatorClickReflectsDisplayBeforeSameFrameDraw(): Unit {
    let model = CalcModel()
    let trace = DisplayBuildTrace()
    let host = WidgetTestHost()
    let result = host.frame(Rect(0.0, 0.0, 200.0, 80.0), events: [
        UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0),
        UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)
    ]) {
        trace.record(model.display.value)
        Button("7", {=> press(model, CalcKey.Digit("7"))}).key("digit-seven")
    }

    @Expect(model.display.value, "7")
    @Expect(trace.calls, Int64(2))
    @Expect(trace.last, "7")
    @Expect(result.metrics.stabilizationPasses, Int64(2))
}
