/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui_paint

import std.collection.ArrayList
import cui.ButtonRole
import cui.CanvasWidget
import cui.Color
import cui.Cursor
import cui.DesktopApp
import cui.FontSizes
import cui.HStack
import cui.Icon
import cui.IconButton
import cui.IconName
import cui.Insets
import cui.Label
import cui.MouseButton
import cui.Panel
import cui.Pen
import cui.Rect
import cui.Renderer
import cui.Size
import cui.Slider
import cui.Spacer
import cui.State
import cui.SystemCursor
import cui.Theme
import cui.UiContext
import cui.UiEvent
import cui.VStack
import cui.Widget
import cui.WindowSpec
import cui.emit

let PALETTE = [
    Color.rgb(38, 70, 104),
    Color.rgb(41, 121, 209),
    Color.rgb(34, 160, 100),
    Color.rgb(238, 160, 38),
    Color.rgb(224, 76, 76),
    Color.rgb(146, 84, 201)
]

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
    let strokes = ArrayList<Stroke>()
    let drawing = State<Bool>(false)
    let lastX = State<Float32>(0.0)
    let lastY = State<Float32>(0.0)
    let brushSize = State<Float32>(5.0)
    let color = State<Color>(PALETTE[1])
}

// A small, selectable colour chip. Defining a Widget in the application shows how the app
// layer can grow the catalog: it just implements the four Widget hooks and calls emit(this).
class ColorSwatch <: Widget {
    private static let SIZE: Float32 = 26.0
    private let swatch: Color
    private let selected: State<Color>
    private var frame = Rect.zero()

    init(swatch: Color, selected: State<Color>) {
        this.swatch = swatch
        this.selected = selected
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(ColorSwatch.SIZE, ColorSwatch.SIZE)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let box = Rect(frame.x, frame.centerY() - ColorSwatch.SIZE / 2.0, ColorSwatch.SIZE, ColorSwatch.SIZE)
        if (isSelected()) {
            ctx.renderer.fillRoundedRect(box.inset(-3.0), 11.0, ctx.theme.text)
            ctx.renderer.fillRoundedRect(box.inset(-1.0), 9.0, ctx.theme.panelRaised)
        }
        ctx.renderer.fillRoundedRect(box, 8.0, swatch)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    selected.value = swatch
                    return true
                }
            case _ => ()
        }
        false
    }

    private func isSelected(): Bool {
        let current = selected.value
        current.r == swatch.r && current.g == swatch.g && current.b == swatch.b
    }
}

main(): Int64 {
    let model = PaintModel()
    let app = DesktopApp(WindowSpec("CUI 画板", 900, 600, scale: 1.5), theme: paintTheme())
    let crosshair = Cursor.system(SystemCursor.Crosshair)
    app.manage(crosshair)
    crosshair.setActive()
    app.run {
        paintView(model)
    }
    return 0
}

func paintTheme(): Theme {
    Theme(
        Color.rgb(241, 246, 242),
        Color.rgb(255, 255, 255),
        Color.rgb(202, 218, 203),
        Color.rgb(25, 36, 27),
        Color.rgb(94, 111, 95),
        Color.rgb(28, 132, 84),
        Color.rgb(255, 255, 255),
        Color.rgb(198, 65, 72),
        Color.rgb(251, 253, 250),
        Color.rgb(230, 247, 237),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(212, 242, 225),
        shadow: Color.rgba(18, 54, 31, 26),
        radius: 16.0,
        controlRadius: 12.0
    )
}

func paintView(model: PaintModel): Unit {
    VStack(padding: Insets(14.0)) {
        Panel(padding: Insets(10.0), flexible: false) {
            HStack {
                IconButton(IconName.Trash, label: Some("清空"), role: ButtonRole.Danger) {
                    => model.strokes.clear()
                }
                Icon(IconName.Brush, color: Some(model.color.value))
                Slider("paint.brush", model.brushSize, lower: 1.0, upper: 18.0)
                Label("画笔 ${Int64(model.brushSize.value)} px", muted: true, fontSize: FontSizes.CAPTION)
                Label("${model.strokes.size} 条笔迹", muted: true, fontSize: FontSizes.CAPTION)
                Spacer()
                for (swatch in PALETTE) {
                    ColorSwatch(swatch, model.color)
                }
            }
        }
        CanvasWidget(
            {r, frame => drawCanvas(r, frame, model)},
            onEvent: {event, frame => paintEvent(event, frame, model)}
        )
    }
}

func drawCanvas(r: Renderer, frame: Rect, model: PaintModel): Unit {
    if (model.strokes.isEmpty()) {
        r.text("在画布内拖动鼠标开始绘画", frame.x + 12.0, frame.y + 12.0, Color.rgb(120, 142, 124),
            pointSize: FontSizes.BODY)
    }
    for (stroke in model.strokes) {
        r.strokeLine(stroke.x1, stroke.y1, stroke.x2, stroke.y2, Pen(width: stroke.size, color: stroke.color))
    }
}

func paintEvent(event: UiEvent, frame: Rect, model: PaintModel): Bool {
    match (event) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            if (frame.contains(x, y)) {
                model.drawing.value = true
                model.lastX.value = x
                model.lastY.value = y
                return true
            }
        case UiEvent.MouseMove(x, y) =>
            if (model.drawing.value && frame.contains(x, y)) {
                model
                    .strokes
                    .add(Stroke(model.lastX.value, model.lastY.value, x, y, model.brushSize.value, model.color.value))
                model.lastX.value = x
                model.lastY.value = y
                return true
            }
        case UiEvent.MouseUp(MouseButton.Left, _, _) =>
            model.drawing.value = false
            return true
        case _ => ()
    }
    false
}
