package cui.controls

import cui.core.{LengthUnits, State, TextStyle, Theme, UiContext}
import cui.media.{clearImageCache, imageCacheStats, invalidateIcon}
import cui.symbols.calendar.ICON_CALENDAR
import sdl.{Rect, Renderer, SdlWindow, Size, WindowSpec}

@Test
func temporalPickerMeasuresDisplayedLabelAndReservesAnIconGap(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let date = DatePicker(State<CalendarDate>(CalendarDate(2026, 12, 31)), key: "wide-date")
    let selectedTime = TimeOfDay(23, 59)
    let time = TimePicker(State<TimeOfDay>(selectedTime), hour12: true, key: "wide-time")
    ctx.withTextStyle(TextStyle(fontSize: 32.fp)) {
        @Expect(date.measure(ctx, Size(1200.0, 200.0)).w >= ctx.textWidth("2026 年 12 月 31 日") + 46.0)
        @Expect(time.measure(ctx, Size(1200.0, 200.0)).w >= ctx.textWidth(selectedTime.format12()) + 46.0)
        @Expect(date.measure(ctx, Size(40.0, 200.0)).w, Float32(40))
        @Expect(time.measure(ctx, Size(40.0, 200.0)).w, Float32(40))
    }
}

@Test
func temporalPickerIconsReuseSharedSourcesAcrossReconstruction(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Picker icon resources", 360, 80), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let date = State<CalendarDate>(CalendarDate(2026, 9, 9))
        let time = State<TimeOfDay>(TimeOfDay(10, 10))
        window.renderer.beginScene(360.0, 80.0, ctx.theme.bg)
        for (_ in 0..5) {
            let datePicker = DatePicker(date, key: "icon-date")
            let timePicker = TimePicker(time, key: "icon-time")
            datePicker.layout(ctx, Rect(4.0, 4.0, 176.0, 34.0))
            timePicker.layout(ctx, Rect(190.0, 4.0, 132.0, 34.0))
            datePicker.draw(ctx)
            timePicker.draw(ctx)
        }
        @Expect(imageCacheStats().misses, UInt64(2))
        @Expect(imageCacheStats().entries, 2)
        @Expect(imageCacheStats().loadFailures, UInt64(0))
        invalidateIcon(ICON_CALENDAR)
        @Expect(imageCacheStats().entries, 1)
        window.renderer.endScene()
        clearImageCache()
    }
}

@Test
func temporalPickerIconClippingRestoresOuterClipForTinyControls(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Picker icon clipping", 80, 60), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let picker = DatePicker(State<CalendarDate>(CalendarDate(2026, 9, 9)), key: "tiny-date")
        picker.layout(ctx, Rect(12.0, 12.0, 8.0, 8.0))
        let outer = Rect(10.0, 10.0, 30.0, 30.0)
        window.renderer.beginScene(80.0, 60.0, ctx.theme.bg)
        window.renderer.pushClip(outer)
        picker.draw(ctx)
        let remaining = window.renderer.currentClip().getOrThrow()
        @Expect(remaining.x, outer.x)
        @Expect(remaining.y, outer.y)
        @Expect(remaining.w, outer.w)
        @Expect(remaining.h, outer.h)
        window.renderer.popClip()
        @Expect(window.renderer.currentClip().isNone())
        window.renderer.endScene()
        clearImageCache()
    }
}
