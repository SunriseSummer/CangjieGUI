/*
 * 画板视图层：根布局与工具栏。
 *
 *  - “清空”按钮依赖框架自动分配的构建期唯一标识，无需手写 id
 *  - “画笔 N px”“N 条笔迹”直接读取 PaintModel 中的派生文本
 *  - 尺寸一律使用 vp 单位表达
 */
package cui_paint

import cui.{ButtonRole, CanvasWidget, FontSizes, HStack, Icon, IconButton, IconName, Label, LengthUnits, Panel, Slider,
    Spacer, VStack}

func paintView(model: PaintModel): Unit {
    VStack {
        toolbar(model)
        CanvasWidget({r, frame => drawCanvas(r, frame, model)})
            .onEvent({event, frame => paintEvent(event, frame, model)})
    }.padding(14.vp)
}

func toolbar(model: PaintModel): Unit {
    Panel {
        HStack {
            IconButton(IconName.Trash) {
                => model.clearStrokes()
            }.label("清空").role(ButtonRole.Danger)
            // 画笔图标实时染成当前颜色，兼作“正在用哪支笔”的预览。
            Icon(IconName.Brush).foregroundColor(model.color.value)
            Slider(model.brushSize).range(BRUSH_MIN, BRUSH_MAX)
            Label(model.brushText.value).muted().fontSize(FontSizes.CAPTION)
            Label(model.strokeCountText.value).muted().fontSize(FontSizes.CAPTION)
            Spacer()
            for (swatch in PALETTE) {
                ColorSwatch(swatch, model.color)
            }
        }
    }.contentPadding(10.vp).hug()
}
