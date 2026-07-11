/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.SDL_NS_PER_MS

public class PerformanceClock {
    public static func ticksMilliseconds(): UInt64 {
        unsafe { SDL_GetTicks() }
    }

    public static func ticksNanoseconds(): UInt64 {
        unsafe { SDL_GetTicksNS() }
    }

    public static func counter(): UInt64 {
        unsafe { SDL_GetPerformanceCounter() }
    }

    public static func frequency(): UInt64 {
        unsafe { SDL_GetPerformanceFrequency() }
    }

    public static func delayNanoseconds(ns: UInt64): Unit {
        unsafe { SDL_DelayNS(ns) }
    }

    public static func delayPrecise(ns: UInt64): Unit {
        unsafe { SDL_DelayPrecise(ns) }
    }

    public static func millisecondsToNanoseconds(ms: UInt64): UInt64 {
        ms * SDL_NS_PER_MS
    }
}
