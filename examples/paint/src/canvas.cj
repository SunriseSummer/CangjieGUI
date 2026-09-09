/*
 * 画布：笔迹渲染与鼠标手势的事件策略。
 *
 * 手势规则：画布内按下起笔，拖动期间逐段连线，松开收笔。
 * 事件按绘制层级自顶向下分发（后绘制者先收到事件），画布在工具栏之后声明，
 * 因此总是先于工具栏拿到鼠标事件——决定“消费还是放行”时必须克制。
 */
package cui_paint

import cui.{FontSizes, MouseButton, Pen, Rect, Renderer, UiEvent}

/** 空画布提示文字相对画布左上角的偏移。 */
private let HINT_INSET: Float32 = 12.0

func drawCanvas(r: Renderer, frame: Rect, model: PaintModel): Unit {
    if (model.strokes.isEmpty()) {
        r.text("在画布内拖动鼠标开始绘画", frame.x + HINT_INSET, frame.y + HINT_INSET, CANVAS_HINT_COLOR,
            pointSize: FontSizes.BODY)
    }
    for (stroke in model.strokes) {
        r.strokeLine(frame.x + stroke.x1, frame.y + stroke.y1, frame.x + stroke.x2, frame.y + stroke.y2,
            Pen(width: stroke.size, color: stroke.color))
    }
}

func paintEvent(event: UiEvent, frame: Rect, model: PaintModel): Bool {
    match (event) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            if (frame.contains(x, y)) {
                model.beginStroke(x - frame.x, y - frame.y)
                return true
            }
        case UiEvent.MouseMove(x, y) =>
            if (model.isDrawing() && frame.contains(x, y)) {
                model.extendStroke(x - frame.x, y - frame.y)
                return true
            }
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            // 收笔不看坐标：笔迹拖出画布外再松开也要结束本次绘制，
            // 否则指针回到画布时会凭空续上一条长线。
            let wasDrawing = model.endStroke()
            // 但消费与否必须判界：画布先于工具栏收到 MouseUp，若无条件返回 true，
            // 工具栏“清空”按钮（按下+松开两段手势）的松开半程会被吞掉，永远无法触发。
            // 只有属于本次绘制的松开、或落在画布内的松开才归画布，其余放行。
            if (wasDrawing || frame.contains(x, y)) {
                return true
            }
        case _ => ()
    }
    false
}
