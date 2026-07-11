/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

import std.math.clamp

private let MIN_CHANNEL: Int64 = 0
private let MAX_CHANNEL: Int64 = 255

public struct Color {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8
    public let a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        this.r = r
        this.g = g
        this.b = b
        this.a = UInt8(MAX_CHANNEL)
    }

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        this.r = r
        this.g = g
        this.b = b
        this.a = a
    }

    public static func rgb(r: Int64, g: Int64, b: Int64): Color {
        Color(toByte(r), toByte(g), toByte(b))
    }

    public static func rgba(r: Int64, g: Int64, b: Int64, a: Int64): Color {
        Color(toByte(r), toByte(g), toByte(b), toByte(a))
    }

    public func withAlpha(alpha: Int64): Color {
        Color(r, g, b, toByte(alpha))
    }
}

/**
 * A stroke description: how wide a line/outline is drawn and in what colour. Bundling the
 * two keeps the stroke primitives (Renderer.strokeLine / strokeRect / strokeCircle) to a
 * small, readable signature, the same way graphics libraries pair a pen or paint with a path.
 */
public struct Pen {
    public let width: Float32
    public let color: Color

    public init(width!: Float32, color!: Color) {
        this.width = width
        this.color = color
    }
}

public struct Point {
    public let x: Float32
    public let y: Float32

    public init(x: Float32, y: Float32) {
        this.x = x
        this.y = y
    }

    internal func toSdlFPoint(): SdlFPoint {
        var raw = SdlFPoint()
        raw.x = x
        raw.y = y
        raw
    }

    internal func toSdlPoint(): SdlPoint {
        var raw = SdlPoint()
        raw.x = Int32(x)
        raw.y = Int32(y)
        raw
    }
}

public struct Size {
    public let w: Float32
    public let h: Float32

    public init(w: Float32, h: Float32) {
        this.w = w
        this.h = h
    }

    public static func zero(): Size {
        Size(0.0, 0.0)
    }
}

public struct Insets {
    public let top: Float32
    public let right: Float32
    public let bottom: Float32
    public let left: Float32

    public init(all: Float32) {
        this.top = all
        this.right = all
        this.bottom = all
        this.left = all
    }

    public init(top: Float32, right: Float32, bottom: Float32, left: Float32) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public func horizontal(): Float32 {
        left + right
    }

    public func vertical(): Float32 {
        top + bottom
    }
}

public struct Rect {
    public var x: Float32
    public var y: Float32
    public var w: Float32
    public var h: Float32

    public init(x: Float32, y: Float32, w: Float32, h: Float32) {
        this.x = x
        this.y = y
        this.w = w
        this.h = h
    }

    public static func zero(): Rect {
        Rect(0.0, 0.0, 0.0, 0.0)
    }

    public func right(): Float32 {
        x + w
    }

    public func bottom(): Float32 {
        y + h
    }

    public func centerX(): Float32 {
        x + w / 2.0
    }

    public func centerY(): Float32 {
        y + h / 2.0
    }

    public func inset(value: Float32): Rect {
        Rect(x + value, y + value, max(0.0, w - value * 2.0), max(0.0, h - value * 2.0))
    }

    public func inset(edges: Insets): Rect {
        Rect(x + edges.left, y + edges.top, max(0.0, w - edges.horizontal()), max(0.0, h - edges.vertical()))
    }

    public func shift(dx: Float32, dy: Float32): Rect {
        Rect(x + dx, y + dy, w, h)
    }

    public func contains(px: Float32, py: Float32): Bool {
        px >= x && px <= right() && py >= y && py <= bottom()
    }

    internal func toSdlFRect(): SdlFRect {
        var raw = SdlFRect()
        raw.x = x
        raw.y = y
        raw.w = w
        raw.h = h
        raw
    }

    internal func toSdlRect(): SdlRect {
        var raw = SdlRect()
        raw.x = Int32(x)
        raw.y = Int32(y)
        raw.w = Int32(w)
        raw.h = Int32(h)
        raw
    }
}

public func clampF32(value: Float32, low: Float32, high: Float32): Float32 {
    Float32(clamp(Float64(value), Float64(low), Float64(high)))
}

private func toByte(value: Int64): UInt8 {
    if (value < MIN_CHANNEL) {
        UInt8(MIN_CHANNEL)
    } else if (value > MAX_CHANNEL) {
        UInt8(MAX_CHANNEL)
    } else {
        UInt8(value)
    }
}
