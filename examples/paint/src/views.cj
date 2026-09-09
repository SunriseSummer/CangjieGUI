package cui_paint

import cui.{Button, CanvasWidget, CrossAxisAlignment, Divider, FlowRow, FontWeight, HStack, Icon}
import cui.{IconSource, Label, LengthUnits, Panel, Slider, Spacer, TextStyle, VStack}

func paintView(model: PaintModel): Unit {
    VStack {
        HStack {
            Icon(IconSource("assets/icons/brush.svg")).iconSize(PAINT_ICON).foregroundColor(model.color.value)
            VStack {
                Label("自由画板").fontSize(PAINT_TITLE).fontWeight(FontWeight.semiBold)
                Label("一点颜色，一点想象").muted().fontSize(PAINT_COMMAND)
            }.spacing(3.vp).hug()
            Spacer()
            Button("清空画布", {=> model.clearStrokes()})
                .key("paint-clear")
                .fontSize(PAINT_COMMAND)
                .enabled(model.hasStrokes())
        }.spacing(PAINT_GAP).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        Panel {
            VStack {
                toolbar(model)
                Divider()
                CanvasWidget({r, frame => drawCanvas(r, frame, model)}).onEvent(
                    {event, frame => paintEvent(event, frame, model)})
            }.spacing(PAINT_GAP)
        }.contentPadding(16.vp).style(paintCard()).flex()
        HStack {
            Label("按住鼠标绘制 · Tab 选择颜色").muted().fontSize(PAINT_CAPTION)
            Spacer()
            Label(model.strokeCountText.value).muted().fontSize(PAINT_CAPTION)
        }.hug()
    }.spacing(14.vp).padding(20.vp)
}

func toolbar(model: PaintModel): Unit {
    FlowRow {
        HStack {
            Label("画笔").muted()
            Slider(model.brushSize).range(BRUSH_MIN, BRUSH_MAX).width(PAINT_SLIDER_WIDTH)
            Label(model.brushText.value).width(PAINT_SIZE_WIDTH)
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        HStack {
            for (entry in PALETTE) {
                colorSwatch(entry, model.color)
            }
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.spacing(20.vp).textStyle(TextStyle(fontSize: PAINT_COMMAND))
}
