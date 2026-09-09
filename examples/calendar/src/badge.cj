/*
 * 用 Surface 逐像素生成标题栏左侧的日历徽标，并存为 PNG 供 ImageView 加载。
 * 以远高于显示尺寸的分辨率绘制（192×144，约为 40×30 vp 显示尺寸的数倍），ImageView 下采样后边缘更锐利。
 */
package cui_calendar

import cui.{Color, Surface}

let CALENDAR_BADGE = "cui-calendar-badge.png"

struct PixelRect {
    let x: Int32
    let y: Int32
    let w: Int32
    let h: Int32

    init(x: Int32, y: Int32, w: Int32, h: Int32) {
        this.x = x
        this.y = y
        this.w = w
        this.h = h
    }
}

func writeCalendarBadge(): Unit {
    try (surface = Surface.create(192, 144)) {
        surface.clear(Color.rgb(253, 251, 255))
        fillRect(surface, PixelRect(0, 0, 192, 44), CALENDAR_ACCENT)
        fillRect(surface, PixelRect(52, 8, 14, 12), Color.rgb(171, 143, 222))
        fillRect(surface, PixelRect(126, 8, 14, 12), Color.rgb(171, 143, 222))
        fillRect(surface, PixelRect(20, 74, 152, 3), Color.rgb(224, 215, 240))
        fillRect(surface, PixelRect(20, 106, 152, 3), Color.rgb(224, 215, 240))
        let cell = Color.rgb(236, 228, 250)
        drawBadgeCell(surface, 0, 0, cell)
        drawBadgeCell(surface, 1, 0, cell)
        drawBadgeCell(surface, 2, 0, CALENDAR_ACCENT)
        drawBadgeCell(surface, 0, 1, cell)
        drawBadgeCell(surface, 1, 1, cell)
        drawBadgeCell(surface, 2, 1, cell)
        surface.savePng(CALENDAR_BADGE)
    }
}

func drawBadgeCell(surface: Surface, col: Int32, row: Int32, color: Color): Unit {
    fillRect(surface, PixelRect(44 + col * 40, 54 + row * 32, 30, 24), color)
}

func fillRect(surface: Surface, rect: PixelRect, color: Color): Unit {
    var row: Int32 = 0
    while (row < rect.h) {
        var col: Int32 = 0
        while (col < rect.w) {
            surface.writePixel(rect.x + col, rect.y + row, color)
            col += 1
        }
        row += 1
    }
}
