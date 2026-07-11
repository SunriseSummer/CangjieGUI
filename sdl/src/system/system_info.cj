/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.ensureSdl

public enum PowerState {
    | Error
    | Unknown
    | OnBattery
    | NoBattery
    | Charging
    | Charged
}

public struct PowerInfo {
    public let state: PowerState
    public let seconds: ?Int32
    public let percent: ?Int32

    public init(state: PowerState, seconds: ?Int32, percent: ?Int32) {
        this.state = state
        this.seconds = seconds
        this.percent = percent
    }
}

public struct CpuInfo {
    public var logicalCores: Int32 = 0
    public var cacheLineBytes: Int32 = 0
    public var systemRamMb: Int32 = 0
    public var pageBytes: Int32 = 0
    public var hasAltiVec: Bool = false
    public var hasMmx: Bool = false
    public var hasSse: Bool = false
    public var hasSse2: Bool = false
    public var hasSse3: Bool = false
    public var hasSse41: Bool = false
    public var hasSse42: Bool = false
    public var hasAvx: Bool = false
    public var hasAvx2: Bool = false
    public var hasAvx512F: Bool = false
    public var hasArmSimd: Bool = false
    public var hasNeon: Bool = false
    public var hasLsx: Bool = false
    public var hasLasx: Bool = false
}

public func platformName(): String {
    let platform = unsafe { SDL_GetPlatform() }
    if (platform.isNull()) {
        "Unknown"
    } else {
        platform.toString()
    }
}

public func cpuInfo(): CpuInfo {
    var info = CpuInfo()
    info.logicalCores = unsafe { SDL_GetNumLogicalCPUCores() }
    info.cacheLineBytes = unsafe { SDL_GetCPUCacheLineSize() }
    info.systemRamMb = unsafe { SDL_GetSystemRAM() }
    info.pageBytes = unsafe { SDL_GetSystemPageSize() }
    info.hasAltiVec = unsafe { SDL_HasAltiVec() }
    info.hasMmx = unsafe { SDL_HasMMX() }
    info.hasSse = unsafe { SDL_HasSSE() }
    info.hasSse2 = unsafe { SDL_HasSSE2() }
    info.hasSse3 = unsafe { SDL_HasSSE3() }
    info.hasSse41 = unsafe { SDL_HasSSE41() }
    info.hasSse42 = unsafe { SDL_HasSSE42() }
    info.hasAvx = unsafe { SDL_HasAVX() }
    info.hasAvx2 = unsafe { SDL_HasAVX2() }
    info.hasAvx512F = unsafe { SDL_HasAVX512F() }
    info.hasArmSimd = unsafe { SDL_HasARMSIMD() }
    info.hasNeon = unsafe { SDL_HasNEON() }
    info.hasLsx = unsafe { SDL_HasLSX() }
    info.hasLasx = unsafe { SDL_HasLASX() }
    info
}

public func powerInfo(): PowerInfo {
    var seconds: Int32 = -1
    var percent: Int32 = -1
    let state = unsafe { SDL_GetPowerInfo(inout seconds, inout percent) }
    PowerInfo(powerStateFromCode(state), nonNegative(seconds), nonNegative(percent))
}

/**
 * Throws `CuiException` when SDL cannot ask the operating system to open a URL handler.
 */
public func openUrl(url: String): Unit {
    let cUrl = unsafe { LibC.mallocCString(url) }
    try (urlResource = cUrl.asResource()) {
        ensureSdl(unsafe { SDL_OpenURL(urlResource.value) }, "SDL_OpenURL")
    }
}

internal func powerStateFromCode(code: Int32): PowerState {
    match (code) {
        case -1 => PowerState.Error
        case 1 => PowerState.OnBattery
        case 2 => PowerState.NoBattery
        case 3 => PowerState.Charging
        case 4 => PowerState.Charged
        case _ => PowerState.Unknown
    }
}

private func nonNegative(value: Int32): ?Int32 {
    if (value >= 0) {
        Some(value)
    } else {
        None
    }
}
