/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.{SdlDateTime, SdlPathInfo}

foreign {
    func SDL_CopyFile(oldpath: CString, newpath: CString): Bool

    func SDL_CreateDirectory(path: CString): Bool

    func SDL_DateTimeToTime(dt: CPointer<SdlDateTime>, ticks: CPointer<Int64>): Bool

    func SDL_DelayNS(ns: UInt64): Unit

    func SDL_DelayPrecise(ns: UInt64): Unit

    func SDL_free(mem: CPointer<UInt8>): Unit

    func SDL_GetAppMetadataProperty(name: CString): CString

    func SDL_GetBasePath(): CString

    func SDL_GetCPUCacheLineSize(): Int32

    func SDL_GetCurrentDirectory(): CString

    func SDL_GetCurrentTime(ticks: CPointer<Int64>): Bool

    func SDL_GetDateTimeLocalePreferences(dateFormat: CPointer<Int32>, timeFormat: CPointer<Int32>): Bool

    func SDL_GetDayOfWeek(year: Int32, month: Int32, day: Int32): Int32

    func SDL_GetDayOfYear(year: Int32, month: Int32, day: Int32): Int32

    func SDL_GetDaysInMonth(year: Int32, month: Int32): Int32

    func SDL_GetHint(name: CString): CString

    func SDL_GetHintBoolean(name: CString, defaultValue: Bool): Bool

    func SDL_GetNumLogicalCPUCores(): Int32

    func SDL_GetPathInfo(path: CString, info: CPointer<SdlPathInfo>): Bool

    func SDL_GetPerformanceCounter(): UInt64

    func SDL_GetPerformanceFrequency(): UInt64

    func SDL_GetPlatform(): CString

    func SDL_GetPowerInfo(seconds: CPointer<Int32>, percent: CPointer<Int32>): Int32

    func SDL_GetPrefPath(org: CString, app: CString): CString

    func SDL_GetSystemPageSize(): Int32

    func SDL_GetSystemRAM(): Int32

    func SDL_GetTicks(): UInt64

    func SDL_GetTicksNS(): UInt64

    func SDL_GetUserFolder(folder: Int32): CString

    func SDL_GlobDirectory(
        path: CString,
        pattern: CString,
        flags: UInt32,
        count: CPointer<Int32>
    ): CPointer<CPointer<UInt8>>

    func SDL_HasAltiVec(): Bool

    func SDL_HasARMSIMD(): Bool

    func SDL_HasAVX(): Bool

    func SDL_HasAVX2(): Bool

    func SDL_HasAVX512F(): Bool

    func SDL_HasLASX(): Bool

    func SDL_HasLSX(): Bool

    func SDL_HasMMX(): Bool

    func SDL_HasNEON(): Bool

    func SDL_HasSSE(): Bool

    func SDL_HasSSE2(): Bool

    func SDL_HasSSE3(): Bool

    func SDL_HasSSE41(): Bool

    func SDL_HasSSE42(): Bool

    func SDL_OpenURL(url: CString): Bool

    func SDL_RemovePath(path: CString): Bool

    func SDL_RenamePath(oldpath: CString, newpath: CString): Bool

    func SDL_ResetHint(name: CString): Bool

    func SDL_ResetHints(): Unit

    func SDL_SetAppMetadata(appname: CString, appversion: CString, appidentifier: CString): Bool

    func SDL_SetAppMetadataProperty(name: CString, value: CString): Bool

    func SDL_SetHintWithPriority(name: CString, value: CString, priority: Int32): Bool

    func SDL_TimeFromWindows(dwLowDateTime: UInt32, dwHighDateTime: UInt32): Int64

    func SDL_TimeToDateTime(ticks: Int64, dt: CPointer<SdlDateTime>, localTime: Bool): Bool

    func SDL_TimeToWindows(
        ticks: Int64,
        dwLowDateTime: CPointer<UInt32>,
        dwHighDateTime: CPointer<UInt32>
    ): Unit
}
