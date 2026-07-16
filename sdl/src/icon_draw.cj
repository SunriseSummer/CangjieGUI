package sdl

private let ICON_GRID: Float32 = 24.0

public enum IconName {
    | NewDocument
    | OpenFolder
    | Save
    | SaveAs
    | Copy
    | Paste
    | Refresh
    | Trash
    | Brush
    | Calendar
    | Clock
    | Process
    | Calculator
    | ChevronLeft
    | ChevronRight
}

/*
 * Vector icons drawn on a 24-unit grid. Every stroke is a thick, round-capped line or bar
 * (see Renderer.strokeLine / strokeRect / strokeCircle) rather than a 1px hairline, so the
 * glyphs read as deliberate 2px strokes once the supersampled frame is resolved. `weight`
 * is the stroke width in device-independent pixels.
 */
public func drawIcon(r: Renderer, icon: IconName, rect: Rect, color: Color, weight!: Float32 = 1.6): Unit {
    let pen = Pen(width: strokeFor(rect, weight), color: color)
    match (icon) {
        case IconName.NewDocument => drawNewDocumentIcon(r, rect, pen)
        case IconName.OpenFolder => drawOpenFolderIcon(r, rect, pen)
        case IconName.Save => drawSaveIcon(r, rect, pen)
        case IconName.SaveAs => drawSaveAsIcon(r, rect, pen)
        case IconName.Copy => drawCopyIcon(r, rect, pen)
        case IconName.Paste => drawPasteIcon(r, rect, pen)
        case IconName.Refresh => drawRefreshIcon(r, rect, pen)
        case IconName.Trash => drawTrashIcon(r, rect, pen)
        case IconName.Brush => drawBrushIcon(r, rect, pen)
        case IconName.Calendar => drawCalendarIcon(r, rect, pen)
        case IconName.Clock => drawClockIcon(r, rect, pen)
        case IconName.Process => drawProcessIcon(r, rect, pen)
        case IconName.Calculator => drawCalculatorIcon(r, rect, pen)
        case IconName.ChevronLeft => drawChevronIcon(r, rect, pen, 15.0, 9.0)
        case IconName.ChevronRight => drawChevronIcon(r, rect, pen, 9.0, 15.0)
    }
}

private func drawChevronIcon(r: Renderer, rect: Rect, pen: Pen, fromX: Float32, toX: Float32): Unit {
    r.strokeLine(x(rect, fromX), y(rect, 5.0), x(rect, toX), y(rect, 12.0), pen)
    r.strokeLine(x(rect, toX), y(rect, 12.0), x(rect, fromX), y(rect, 19.0), pen)
}

private func drawNewDocumentIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 5.0, 3.0, 11.0, 16.0), pen)
    r.strokeLine(x(rect, 16.0), y(rect, 3.0), x(rect, 19.0), y(rect, 6.0), pen)
    r.strokeLine(x(rect, 19.0), y(rect, 6.0), x(rect, 19.0), y(rect, 21.0), pen)
    r.strokeLine(x(rect, 9.0), y(rect, 12.0), x(rect, 15.0), y(rect, 12.0), pen)
    r.strokeLine(x(rect, 12.0), y(rect, 9.0), x(rect, 12.0), y(rect, 15.0), pen)
}

private func drawOpenFolderIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeLine(x(rect, 3.0), y(rect, 8.0), x(rect, 9.0), y(rect, 8.0), pen)
    r.strokeLine(x(rect, 9.0), y(rect, 8.0), x(rect, 11.0), y(rect, 6.0), pen)
    r.strokeLine(x(rect, 11.0), y(rect, 6.0), x(rect, 15.0), y(rect, 6.0), pen)
    r.strokeLine(x(rect, 15.0), y(rect, 6.0), x(rect, 17.0), y(rect, 8.0), pen)
    r.strokeRect(gridRect(rect, 3.0, 8.0, 18.0, 12.0), pen)
    r.strokeLine(x(rect, 5.0), y(rect, 13.0), x(rect, 19.0), y(rect, 13.0), pen)
}

private func drawSaveIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 4.0, 4.0, 16.0, 16.0), pen)
    r.strokeRect(gridRect(rect, 7.0, 4.0, 9.0, 5.0), pen)
    r.strokeRect(gridRect(rect, 7.0, 14.0, 10.0, 6.0), pen)
}

private func drawSaveAsIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    drawSaveIcon(r, rect, pen)
    r.strokeLine(x(rect, 14.0), y(rect, 14.0), x(rect, 21.0), y(rect, 7.0), pen)
    r.strokeLine(x(rect, 18.0), y(rect, 7.0), x(rect, 21.0), y(rect, 7.0), pen)
    r.strokeLine(x(rect, 21.0), y(rect, 7.0), x(rect, 21.0), y(rect, 10.0), pen)
}

private func drawCopyIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 8.0, 7.0, 11.0, 13.0), pen)
    r.strokeRect(gridRect(rect, 5.0, 4.0, 11.0, 13.0), pen)
}

private func drawPasteIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 6.0, 6.0, 12.0, 14.0), pen)
    r.strokeRect(gridRect(rect, 9.0, 3.0, 6.0, 5.0), pen)
    r.strokeLine(x(rect, 9.0), y(rect, 12.0), x(rect, 15.0), y(rect, 12.0), pen)
    r.strokeLine(x(rect, 9.0), y(rect, 16.0), x(rect, 15.0), y(rect, 16.0), pen)
}

private func drawRefreshIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeCircle(rect.centerX(), rect.centerY(), s(rect, 7.0), pen, segments: 32)
    r.strokeLine(x(rect, 17.0), y(rect, 4.0), x(rect, 20.0), y(rect, 4.0), pen)
    r.strokeLine(x(rect, 20.0), y(rect, 4.0), x(rect, 20.0), y(rect, 7.0), pen)
    r.strokeLine(x(rect, 4.0), y(rect, 17.0), x(rect, 4.0), y(rect, 20.0), pen)
    r.strokeLine(x(rect, 4.0), y(rect, 20.0), x(rect, 7.0), y(rect, 20.0), pen)
}

private func drawTrashIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeLine(x(rect, 6.0), y(rect, 7.0), x(rect, 18.0), y(rect, 7.0), pen)
    r.strokeLine(x(rect, 9.0), y(rect, 4.0), x(rect, 15.0), y(rect, 4.0), pen)
    r.strokeRect(gridRect(rect, 7.0, 8.0, 10.0, 12.0), pen)
    r.strokeLine(x(rect, 10.0), y(rect, 10.0), x(rect, 10.0), y(rect, 18.0), pen)
    r.strokeLine(x(rect, 14.0), y(rect, 10.0), x(rect, 14.0), y(rect, 18.0), pen)
}

private func drawBrushIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeLine(x(rect, 14.0), y(rect, 4.0), x(rect, 20.0), y(rect, 10.0), pen)
    r.strokeLine(x(rect, 20.0), y(rect, 10.0), x(rect, 10.0), y(rect, 20.0), pen)
    r.strokeLine(x(rect, 10.0), y(rect, 20.0), x(rect, 6.0), y(rect, 16.0), pen)
    r.strokeLine(x(rect, 6.0), y(rect, 16.0), x(rect, 16.0), y(rect, 6.0), pen)
    r.strokeLine(x(rect, 5.0), y(rect, 18.0), x(rect, 3.0), y(rect, 21.0), pen)
}

private func drawCalendarIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 4.0, 5.0, 16.0, 15.0), pen)
    r.strokeLine(x(rect, 4.0), y(rect, 10.0), x(rect, 20.0), y(rect, 10.0), pen)
    r.strokeLine(x(rect, 8.0), y(rect, 3.0), x(rect, 8.0), y(rect, 7.0), pen)
    r.strokeLine(x(rect, 16.0), y(rect, 3.0), x(rect, 16.0), y(rect, 7.0), pen)
    r.fillCircle(x(rect, 9.0), y(rect, 15.0), s(rect, 1.3), pen.color)
    r.fillCircle(x(rect, 14.0), y(rect, 15.0), s(rect, 1.3), pen.color)
}

// A round clock face with a long minute hand pointing up and a short hour hand pointing right (~3 o'clock).
private func drawClockIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeCircle(x(rect, 12.0), y(rect, 12.0), s(rect, 8.5), pen, segments: 32)
    r.strokeLine(x(rect, 12.0), y(rect, 12.0), x(rect, 12.0), y(rect, 7.0), pen)
    r.strokeLine(x(rect, 12.0), y(rect, 12.0), x(rect, 15.5), y(rect, 13.5), pen)
}

private func drawProcessIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 5.0, 5.0, 14.0, 14.0), pen)
    r.strokeRect(gridRect(rect, 9.0, 9.0, 6.0, 6.0), pen)
    r.strokeLine(x(rect, 2.0), y(rect, 9.0), x(rect, 5.0), y(rect, 9.0), pen)
    r.strokeLine(x(rect, 2.0), y(rect, 15.0), x(rect, 5.0), y(rect, 15.0), pen)
    r.strokeLine(x(rect, 19.0), y(rect, 9.0), x(rect, 22.0), y(rect, 9.0), pen)
    r.strokeLine(x(rect, 19.0), y(rect, 15.0), x(rect, 22.0), y(rect, 15.0), pen)
}

private func drawCalculatorIcon(r: Renderer, rect: Rect, pen: Pen): Unit {
    r.strokeRect(gridRect(rect, 6.0, 3.0, 12.0, 18.0), pen)
    r.strokeRect(gridRect(rect, 8.0, 6.0, 8.0, 4.0), pen)
    r.fillCircle(x(rect, 9.0), y(rect, 14.0), s(rect, 1.3), pen.color)
    r.fillCircle(x(rect, 13.0), y(rect, 14.0), s(rect, 1.3), pen.color)
    r.fillCircle(x(rect, 9.0), y(rect, 18.0), s(rect, 1.3), pen.color)
    r.fillCircle(x(rect, 13.0), y(rect, 18.0), s(rect, 1.3), pen.color)
}

// Builds a rectangle whose corner and size are given in 24-grid units.
private func gridRect(rect: Rect, gx: Float32, gy: Float32, gw: Float32, gh: Float32): Rect {
    Rect(x(rect, gx), y(rect, gy), s(rect, gw), s(rect, gh))
}

// Keeps the stroke proportional to the icon so large icons are not hairlines and tiny ones
// do not turn into blobs.
private func strokeFor(rect: Rect, weight: Float32): Float32 {
    let scaled = min(rect.w, rect.h) / ICON_GRID * 2.2
    if (scaled > weight) {
        scaled
    } else {
        weight
    }
}

private func x(rect: Rect, value: Float32): Float32 {
    rect.x + rect.w * value / ICON_GRID
}

private func y(rect: Rect, value: Float32): Float32 {
    rect.y + rect.h * value / ICON_GRID
}

private func s(rect: Rect, value: Float32): Float32 {
    min(rect.w, rect.h) * value / ICON_GRID
}
