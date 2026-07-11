/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import sdl.{ensureSdl, normalizedScale}

public struct MouseState {
    public let x: Float32
    public let y: Float32
    public let left: Bool
    public let middle: Bool
    public let right: Bool
    public let buttons: UInt32

    public init(x: Float32, y: Float32, left: Bool, middle: Bool, right: Bool, buttons: UInt32) {
        this.x = x
        this.y = y
        this.left = left
        this.middle = middle
        this.right = right
        this.buttons = buttons
    }
}

public class Mouse {
    public static func state(scale!: Float32 = 1.0): MouseState {
        var x: Float32 = 0.0
        var y: Float32 = 0.0
        let buttons = unsafe { SDL_GetMouseState(inout x, inout y) }
        let safeScale = normalizedScale(scale)
        MouseState(
            x / safeScale,
            y / safeScale,
            hasButton(buttons, UInt32(1)),
            hasButton(buttons, UInt32(2)),
            hasButton(buttons, UInt32(4)),
            buttons
        )
    }

    public static func capture(enabled: Bool): Unit {
        ensureSdl(unsafe { SDL_CaptureMouse(enabled) }, "SDL_CaptureMouse")
    }
}

private func hasButton(buttons: UInt32, mask: UInt32): Bool {
    (buttons & mask) != UInt32(0)
}
