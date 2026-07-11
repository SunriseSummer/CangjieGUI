/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_DATE_FORMAT_YYYYMMDD: Int32 = 0
internal let SDL_DATE_FORMAT_DDMMYYYY: Int32 = 1
internal let SDL_DATE_FORMAT_MMDDYYYY: Int32 = 2
internal let SDL_TIME_FORMAT_24HR: Int32 = 0
internal let SDL_TIME_FORMAT_12HR: Int32 = 1

@C
internal struct SdlDateTime {
    var year: Int32 = 0
    var month: Int32 = 0
    var day: Int32 = 0
    var hour: Int32 = 0
    var minute: Int32 = 0
    var second: Int32 = 0
    var nanosecond: Int32 = 0
    var dayOfWeek: Int32 = 0
    var utcOffset: Int32 = 0
}

foreign {
    func SDL_GetDateTimeLocalePreferences(dateFormat: CPointer<Int32>, timeFormat: CPointer<Int32>): Bool

    func SDL_GetCurrentTime(ticks: CPointer<Int64>): Bool

    func SDL_TimeToDateTime(ticks: Int64, dt: CPointer<SdlDateTime>, localTime: Bool): Bool

    func SDL_DateTimeToTime(dt: CPointer<SdlDateTime>, ticks: CPointer<Int64>): Bool

    func SDL_TimeToWindows(ticks: Int64, dwLowDateTime: CPointer<UInt32>, dwHighDateTime: CPointer<UInt32>): Unit

    func SDL_TimeFromWindows(dwLowDateTime: UInt32, dwHighDateTime: UInt32): Int64

    func SDL_GetDaysInMonth(year: Int32, month: Int32): Int32

    func SDL_GetDayOfYear(year: Int32, month: Int32, day: Int32): Int32

    func SDL_GetDayOfWeek(year: Int32, month: Int32, day: Int32): Int32
}
