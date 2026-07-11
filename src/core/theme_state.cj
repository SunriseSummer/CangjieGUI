/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Color, FrameInfo, Renderer, SurfaceStyle}

public class State<T> {
    public var value: T

    public init(value: T) {
        this.value = value
    }
}

public struct Theme {
    public let bg: Color
    public let panel: Color
    public let panelEdge: Color
    public let text: Color
    public let mutedText: Color
    public let accent: Color
    public let accentText: Color
    public let danger: Color
    public let field: Color
    public let fieldActive: Color
    public let panelRaised: Color
    public let accentSoft: Color
    public let shadow: Color
    public let radius: Float32
    public let smallRadius: Float32
    public let controlRadius: Float32
    public let borderWidth: Float32

    public init(
        bg: Color,
        panel: Color,
        panelEdge: Color,
        text: Color,
        mutedText: Color,
        accent: Color,
        accentText: Color,
        danger: Color,
        field: Color,
        fieldActive: Color,
        panelRaised!: Color = Color.rgb(255, 255, 255),
        accentSoft!: Color = Color.rgb(224, 240, 255),
        shadow!: Color = Color.rgba(16, 24, 40, 34),
        radius!: Float32 = 12.0,
        smallRadius!: Float32 = 7.0,
        controlRadius!: Float32 = 9.0,
        borderWidth!: Float32 = 1.0
    ) {
        this.bg = bg
        this.panel = panel
        this.panelEdge = panelEdge
        this.text = text
        this.mutedText = mutedText
        this.accent = accent
        this.accentText = accentText
        this.danger = danger
        this.field = field
        this.fieldActive = fieldActive
        this.panelRaised = panelRaised
        this.accentSoft = accentSoft
        this.shadow = shadow
        this.radius = radius
        this.smallRadius = smallRadius
        this.controlRadius = controlRadius
        this.borderWidth = borderWidth
    }

    public static func light(): Theme {
        Theme(
            Color.rgb(242, 245, 249),
            Color.rgb(255, 255, 255),
            Color.rgb(210, 217, 226),
            Color.rgb(20, 27, 38),
            Color.rgb(93, 105, 122),
            Color.rgb(33, 114, 229),
            Color.rgb(255, 255, 255),
            Color.rgb(208, 63, 67),
            Color.rgb(248, 250, 253),
            Color.rgb(235, 244, 255),
            panelRaised: Color.rgb(255, 255, 255),
            accentSoft: Color.rgb(226, 239, 255),
            shadow: Color.rgba(15, 23, 42, 28),
            radius: 14.0,
            smallRadius: 8.0,
            controlRadius: 10.0
        )
    }

    public static func dark(): Theme {
        Theme(
            Color.rgb(18, 22, 29),
            Color.rgb(28, 34, 44),
            Color.rgb(65, 75, 91),
            Color.rgb(241, 245, 249),
            Color.rgb(157, 169, 187),
            Color.rgb(87, 166, 255),
            Color.rgb(8, 18, 31),
            Color.rgb(255, 124, 124),
            Color.rgb(36, 43, 55),
            Color.rgb(44, 61, 80),
            panelRaised: Color.rgb(35, 42, 54),
            accentSoft: Color.rgb(34, 62, 96),
            shadow: Color.rgba(0, 0, 0, 72),
            radius: 14.0,
            smallRadius: 8.0,
            controlRadius: 10.0
        )
    }

    public func panelSurface(): SurfaceStyle {
        SurfaceStyle(
            panel,
            border: panelEdge,
            radius: radius,
            borderWidth: borderWidth,
            shadow: shadow,
            shadowOffsetY: 2.0
        )
    }

    public func raisedSurface(): SurfaceStyle {
        SurfaceStyle(
            panelRaised,
            border: panelEdge,
            radius: radius,
            borderWidth: borderWidth,
            shadow: shadow,
            shadowOffsetY: 3.0
        )
    }

    public func fieldSurface(active: Bool): SurfaceStyle {
        SurfaceStyle(
            if (active) {
                fieldActive
            } else {
                field
            },
            border: if (active) {
                accent
            } else {
                panelEdge
            },
            radius: controlRadius,
            borderWidth: borderWidth,
            shadow: if (active) {
                accent.withAlpha(34)
            } else {
                Color.rgba(0, 0, 0, 0)
            },
            shadowOffsetY: 1.0
        )
    }

    public func buttonSurface(role: ButtonRole): SurfaceStyle {
        match (role) {
            case ButtonRole.Primary => SurfaceStyle(
                accent,
                border: accent,
                radius: controlRadius,
                borderWidth: borderWidth,
                shadow: accent.withAlpha(30),
                shadowOffsetY: 2.5
            )
            case ButtonRole.Danger => SurfaceStyle(
                danger,
                border: danger,
                radius: controlRadius,
                borderWidth: borderWidth,
                shadow: danger.withAlpha(24),
                shadowOffsetY: 2.5
            )
            case ButtonRole.Normal => SurfaceStyle(
                panelRaised,
                border: panelEdge,
                radius: controlRadius,
                borderWidth: borderWidth,
                shadow: shadow.withAlpha(20),
                shadowOffsetY: 1.0
            )
        }
    }

    public func selectedSurface(): SurfaceStyle {
        SurfaceStyle(accent, border: accent, radius: controlRadius, borderWidth: borderWidth)
    }
}

public class UiContext {
    public let renderer: Renderer
    public let theme: Theme
    public var focusId: String = ""
    public var dragId: String = ""
    public var mouseX: Float32 = 0.0
    public var mouseY: Float32 = 0.0
    public var leftMouseDown: Bool = false
    public var shouldClose: Bool = false
    public var frame: FrameInfo = FrameInfo(UInt64(0), UInt64(0))

    public init(renderer: Renderer, theme: Theme) {
        this.renderer = renderer
        this.theme = theme
    }

    public func requestClose(): Unit {
        shouldClose = true
    }

    public func hasFocus(id: String): Bool {
        focusId == id
    }

    public func focus(id: String): Unit {
        focusId = id
    }

    public func beginDrag(id: String): Unit {
        dragId = id
    }

    public func isDragging(id: String): Bool {
        dragId == id
    }

    public func clearDrag(): Unit {
        dragId = ""
    }
}
