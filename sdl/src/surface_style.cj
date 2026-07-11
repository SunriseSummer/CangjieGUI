/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

public struct SurfaceStyle {
    public let fill: Color
    public let border: Color
    public let radius: Float32
    public let borderWidth: Float32
    public let shadow: Color
    public let shadowOffsetY: Float32

    public init(
        fill: Color,
        border!: Color = Color.rgba(0, 0, 0, 0),
        radius!: Float32 = 0.0,
        borderWidth!: Float32 = 0.0,
        shadow!: Color = Color.rgba(0, 0, 0, 0),
        shadowOffsetY!: Float32 = 0.0
    ) {
        this.fill = fill
        this.border = border
        this.radius = radius
        this.borderWidth = borderWidth
        this.shadow = shadow
        this.shadowOffsetY = shadowOffsetY
    }

    public func withFill(fill: Color): SurfaceStyle {
        SurfaceStyle(
            fill,
            border: border,
            radius: radius,
            borderWidth: borderWidth,
            shadow: shadow,
            shadowOffsetY: shadowOffsetY
        )
    }

    public func withBorder(border: Color): SurfaceStyle {
        SurfaceStyle(
            fill,
            border: border,
            radius: radius,
            borderWidth: borderWidth,
            shadow: shadow,
            shadowOffsetY: shadowOffsetY
        )
    }
}
