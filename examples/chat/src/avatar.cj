/*
 * Avatar：圆形头像，底色按人取色、白色首字居中。
 * 应用层自定义 Widget（同 paint 示例的 ColorSwatch）：实现 measure/layout/draw/handle 并 emit(this)，
 * 即可像内置控件一样参与声明式布局。
 */
package cui_chat

import cui.{Color, FontSizes, Rect, Size, UiContext, UiEvent, Widget, emit}

/** 头像直径（逻辑像素）。 */
let AVATAR_SIZE: Float32 = 36.0

class Avatar <: Widget {
    private let initial: String
    private let fill: Color
    private var frame = Rect.zero()

    /** 以 `name` 的首字为标识、`fill` 为底色。 */
    init(name: String, fill: Color) {
        let runes = name.toRuneArray()
        this.initial = if (runes.size > 0) {
            "${runes[0]}"
        } else {
            "?"
        }
        this.fill = fill
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(AVATAR_SIZE, AVATAR_SIZE)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        // 布局给的高度可能大于直径（行随内容拉伸），圆固定画在顶部，与首行气泡对齐。
        let box = Rect(frame.x, frame.y, AVATAR_SIZE, AVATAR_SIZE)
        ctx.renderer.fillCircle(box.centerX(), box.centerY(), AVATAR_SIZE / 2.0, fill)
        ctx.renderer.textCenter(initial, box, Color.rgb(255, 255, 255), pointSize: FontSizes.CONTROL)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
