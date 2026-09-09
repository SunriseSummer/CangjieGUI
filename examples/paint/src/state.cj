/*
 * 画板状态：笔迹数据与绘制手势的单一数据源。
 *
 *  - 笔迹本体存 ArrayList，绘制时高频追加不必整体替换；条数单独立为 State，
 *    工具栏的“N 条笔迹”文本由它派生，永不与画布脱节
 *  - 起笔/采样/收笔的状态迁移收拢在模型方法里，事件层只负责“消费还是放行”
 */
package cui_paint

import std.collection.ArrayList
import cui.{Color, DerivedState, State}

/** 画笔粗细的可调范围与初始值（逻辑像素），工具栏滑杆与新笔迹共用。 */
let BRUSH_MIN: Float32 = 1.0
let BRUSH_MAX: Float32 = 18.0
let BRUSH_DEFAULT: Float32 = 5.0

/** 一段笔迹：一次拖动中相邻两个采样点连成的线段，连同落笔时的画笔快照。 */
class Stroke {
    let x1: Float32
    let y1: Float32
    let x2: Float32
    let y2: Float32
    let size: Float32
    let color: Color

    init(x1: Float32, y1: Float32, x2: Float32, y2: Float32, size: Float32, color: Color) {
        this.x1 = x1
        this.y1 = y1
        this.x2 = x2
        this.y2 = y2
        this.size = size
        this.color = color
    }
}

class PaintModel {
    /** 全部已落笔线段，画布每帧按序重绘。 */
    let strokes = ArrayList<Stroke>()
    /** 笔迹条数。ArrayList 的增删不可观察，所以计数单独入 State 供派生文本使用。 */
    private let strokeCount = State<Int64>(0)
    /** 画笔粗细与颜色由工具栏控件双向绑定，必须是 State。 */
    let brushSize = State<Float32>(BRUSH_DEFAULT)
    let color = State<Color>(DEFAULT_BRUSH_COLOR)
    /** 工具栏的两段说明文字：改状态，文字自动跟上，视图里不再拼字符串。 */
    let brushText: DerivedState<String>
    let strokeCountText: DerivedState<String>
    /** 手势状态机内部记录：是否正在绘制、上一个采样点。无控件绑定，普通字段即可。 */
    private var drawing = false
    private var lastX: Float32 = 0.0
    private var lastY: Float32 = 0.0

    init() {
        this.brushText = this.brushSize.map<String>({size => "画笔 ${Int64(size)} px"})
        this.strokeCountText = this.strokeCount.map<String>({count => "${count} 条笔迹"})
    }

    /** 是否处于按下未松开的绘制过程中。 */
    func isDrawing(): Bool {
        drawing
    }

    func hasStrokes(): Bool {
        strokeCount.value > 0
    }

    /** 画布内按下：起笔，并把按下点作为首个采样点。 */
    func beginStroke(x: Float32, y: Float32): Unit {
        drawing = true
        lastX = x
        lastY = y
    }

    /** 拖动采样：与上一点连成一段笔迹，再推进采样点。 */
    func extendStroke(x: Float32, y: Float32): Unit {
        if (!drawing) {
            return
        }
        strokes.add(Stroke(lastX, lastY, x, y, brushSize.value, color.value))
        strokeCount.value = strokes.size
        lastX = x
        lastY = y
    }

    /** 收笔。返回收笔前是否在绘制中，供事件层决定这次松开是否属于画布。 */
    func endStroke(): Bool {
        let wasDrawing = drawing
        drawing = false
        wasDrawing
    }

    /** 清空画布并归零计数。 */
    func clearStrokes(): Unit {
        drawing = false
        strokes.clear()
        if (strokeCount.value != 0) {
            strokeCount.value = 0
        }
    }
}
