package cui.core

import std.collection.ArrayList
import sdl.{Color, FrameInfo, Insets, Rect, Renderer, SurfaceStyle, UiEvent}

// A second press within this window and distance of the previous one continues a multi-click.
private let MULTI_CLICK_MS: UInt64 = 400
private let MULTI_CLICK_DIST: Float32 = 4.0

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
    // Whether the focused control should paint a ring: true when focus last moved by keyboard
    // (Tab traversal or autofocus), false when a pointer press claimed it — the :focus-visible
    // convention. Behaviour (activation, caret, arrow nav) uses `focusId`; only the ring gates on this.
    public var focusRingVisible: Bool = false
    public var hoverId: String = ""
    public var dragId: String = ""
    public var pressedId: String = ""
    // Single-slot overlay: a hovered `Tooltip` registers here during draw and the shell
    // paints it above everything after the tree. Empty text means no tooltip this frame.
    public var tooltipText: String = ""
    public var tooltipAnchor: Rect = Rect.zero()
    public var mouseX: Float32 = 0.0
    public var mouseY: Float32 = 0.0
    public var leftMouseDown: Bool = false
    public var shouldClose: Bool = false
    public var frame: FrameInfo = FrameInfo(UInt64(0), UInt64(0))
    /** Logical size of the drawing surface; overlays clamp their popups to it. */
    public var viewportWidth: Float32 = 0.0
    public var viewportHeight: Float32 = 0.0
    // Interactive overlays open this frame, bottom to top. Registration order is z-order:
    // the tree draws first (a Modal registers its dialog), then the overlay render pass
    // draws each layer's content, so a popup opened inside a dialog registers — and
    // paints — above it. Events walk the stack top-down (see `dispatchOverlay`).
    private let overlays = ArrayList<Overlay>()
    /** Physical pixels per virtual pixel; set from the window content scale. */
    public var displayScale: Float32 = 1.0
    /** User font scale applied to `fp` lengths; `1.0` keeps `fp` equal to `vp`. */
    public var fontScale: Float32 = 1.0

    public init(renderer: Renderer, theme: Theme) {
        this.renderer = renderer
        this.theme = theme
    }

    /** Converts a unit-carrying length into logical (virtual) pixels. */
    public func resolve(length: Length): Float32 {
        match (length.unit) {
            case LengthUnit.Vp => length.value
            case LengthUnit.Px => length.value / max(0.001, displayScale)
            case LengthUnit.Fp => length.value * fontScale
        }
    }

    /** Converts unit-carrying edge insets into logical-pixel insets. */
    public func resolve(insets: LengthInsets): Insets {
        Insets(
            max(0.0, resolve(insets.top)),
            max(0.0, resolve(insets.right)),
            max(0.0, resolve(insets.bottom)),
            max(0.0, resolve(insets.left))
        )
    }

    private var focusClaimedInPress = false
    private var focusOrder: Array<String> = []
    /** How many rapid presses ended at the current one: 1 single, 2 double, 3 triple. */
    public var clickCount: Int64 = 1
    private var lastPressMs: UInt64 = 0
    private var lastPressX: Float32 = 0.0
    private var lastPressY: Float32 = 0.0
    private var hasLastPress = false

    public func requestClose(): Unit {
        shouldClose = true
    }

    // Set by a widget during handle or draw when it needs the next frame rendered even without any
    // input event or state change — a blinking caret, a tooltip counting down its reveal delay, a
    // per-frame FrameHandler. The desktop loop reads and clears it each rendered frame (takeFrameRequest)
    // so these animations stay alive while the loop otherwise skips idle frames (档 0).
    private var continuousFrameRequested = false

    /**
     * Requests that the next frame be rendered even if no input arrived and no state changed. Call this
     * from a widget that animates on the frame clock (a caret, a spinner, a countdown); without it the
     * desktop loop may skip rendering while the screen is otherwise idle.
     */
    public func requestFrame(): Unit {
        continuousFrameRequested = true
    }

    /** Reads and clears the continuous-frame request. The desktop loop calls this once per rendered frame. */
    protected func takeFrameRequest(): Bool {
        let requested = continuousFrameRequested
        continuousFrameRequested = false
        requested
    }

    /*
     * Adopts the focus ring gathered by the latest build. The shell calls this once per
     * frame after building the tree, so keyboard traversal always reflects the controls
     * currently on screen and in their declared order.
     */
    protected func adoptFocusRing(ids: Array<String>): Unit {
        focusOrder = ids
    }

    /** Moves keyboard focus to the next focusable control, wrapping at the end. */
    public func focusNext(): Unit {
        moveFocus(1)
    }

    /** Moves keyboard focus to the previous focusable control, wrapping at the start. */
    public func focusPrevious(): Unit {
        moveFocus(-1)
    }

    /*
     * Advances focus by `step` positions through the ring. From no focus, a forward step
     * lands on the first control and a backward step on the last, matching how Tab and
     * Shift+Tab enter a window. A focus id no longer present (the tree changed shape) is
     * treated as "outside the ring" and re-enters from the corresponding end.
     */
    private func moveFocus(step: Int64): Unit {
        let count = focusOrder.size
        if (count == 0) {
            return
        }
        var current = -1
        for (i in 0..count) {
            if (focusOrder[i] == focusId) {
                current = i
                break
            }
        }
        let next = if (current < 0) {
            if (step > 0) { 0 } else { count - 1 }
        } else {
            (((current + step) % count) + count) % count
        }
        focusId = focusOrder[next]
        focusRingVisible = true // Tab traversal is keyboard, so the ring shows
    }

    public func hasFocus(id: String): Bool {
        focusId == id
    }

    /*
     * Whether `id` should paint a focus ring: it must have focus AND focus must have last moved
     * by keyboard. A pointer press focuses without a ring, matching the desktop `:focus-visible`
     * convention that a click should not leave a keyboard-style outline.
     */
    public func showFocusRing(id: String): Bool {
        focusId == id && focusRingVisible
    }

    // `viaKeyboard` marks focus the user reached by keyboard (Tab, autofocus) versus a pointer
    // press; it drives whether a ring shows, not focus itself.
    public func focus(id: String, viaKeyboard!: Bool = false): Unit {
        focusId = id
        focusClaimedInPress = true
        focusRingVisible = viaKeyboard
    }

    /** Removes keyboard focus from every control. */
    public func clearFocus(): Unit {
        focusId = ""
        focusRingVisible = false
    }

    /*
     * Desktop-standard blur: a primary press either moves focus to the control that
     * claims it, or clears focus entirely. The shell brackets each MouseDown dispatch
     * with these two calls; any `focus()` during dispatch counts as a claim.
     */
    /*
     * Classifies a primary press as single/double/triple by how closely it follows the
     * previous one in time and space. The shell calls this on each left MouseDown before
     * dispatch, so controls can read `clickCount` while handling the press. Kept as a
     * general primitive: any widget can act on double-clicks, not just text.
     */
    protected func recordPress(x: Float32, y: Float32): Unit {
        let now = frame.elapsedMs
        let dx = x - lastPressX
        let dy = y - lastPressY
        let near = dx * dx + dy * dy <= MULTI_CLICK_DIST * MULTI_CLICK_DIST
        let quick = hasLastPress && now >= lastPressMs && now - lastPressMs <= MULTI_CLICK_MS && near
        if (quick) {
            clickCount = if (clickCount >= 3) {
                1
            } else {
                clickCount + 1
            }
        } else {
            clickCount = 1
        }
        lastPressMs = now
        lastPressX = x
        lastPressY = y
        hasLastPress = true
    }

    protected func beginPointerPress(): Unit {
        focusClaimedInPress = false
    }

    protected func settleFocusAfterPress(): Unit {
        if (!focusClaimedInPress) {
            clearFocus()
        }
    }

    private var hoverClaimed = false
    private var pendingHoverId: String = ""
    private var pendingHoverShape = CursorShape.Default
    private var settledHoverShape = CursorShape.Default

    /*
     * Hover is resolved once per pointer move, mirroring the focus press-settle protocol.
     * The shell brackets a MouseMove dispatch with begin/settle; each control the pointer
     * is inside calls `claimHover`. Dispatch visits top-most first, and only the first
     * claim of a move wins, so overlapping layers resolve to the visually top control.
     */
    protected func beginHoverTest(): Unit {
        hoverClaimed = false
        pendingHoverId = ""
        pendingHoverShape = CursorShape.Default
    }

    /** Claims hover for `id` with the desired pointer shape; the first claim per move wins. */
    public func claimHover(id: String, shape: CursorShape): Unit {
        if (!hoverClaimed) {
            hoverClaimed = true
            pendingHoverId = id
            pendingHoverShape = shape
        }
    }

    protected func settleHover(): Unit {
        hoverId = pendingHoverId
        settledHoverShape = pendingHoverShape
    }

    /** Returns whether `id` is the control currently under the pointer. */
    public func isHovered(id: String): Bool {
        hoverId == id
    }

    /** Registers a tooltip to paint above the tree this frame, anchored to `rect`. */
    public func showTooltip(text: String, rect: Rect): Unit {
        tooltipText = text
        tooltipAnchor = rect
    }

    /** Clears any pending tooltip; the shell calls this before drawing each frame. */
    public func clearTooltip(): Unit {
        tooltipText = ""
    }

    // Where the focused text control wants the IME composition UI anchored, in logical
    // pixels: the caret rectangle it reported during draw (blink phase or not). The shell
    // forwards changes to the window, so the candidate window follows the caret instead
    // of sitting in a screen corner.
    private var textInputAnchor: ?Rect = None

    /** Reports the focused caret rectangle this frame, anchoring the IME candidate window. */
    public func setTextInputAnchor(rect: Rect): Unit {
        textInputAnchor = Some(rect)
    }

    /** Clears the reported caret anchor; the shell calls this before drawing each frame. */
    public func clearTextInputAnchor(): Unit {
        textInputAnchor = None
    }

    /** The caret rectangle reported during this frame's draw, if a text control has focus. */
    public func textInputAnchorRect(): ?Rect {
        textInputAnchor
    }

    /**
     * Registers an interactive overlay (a dropdown/menu popup, a dialog) for this frame,
     * above those already open. Re-registering under an already-present `owner` replaces
     * that entry in place, keeping its z position.
     */
    public func setOverlay(overlay: Overlay): Unit {
        if (!overlay.owner.isEmpty()) {
            for (i in 0..overlays.size) {
                if (overlays[i].owner == overlay.owner) {
                    overlays[i] = overlay
                    return
                }
            }
        }
        overlays.add(overlay)
    }

    /**
     * Removes the overlay registered under `owner`, leaving the rest of the stack open —
     * a closing popup removes exactly its own registration, never a dialog beneath it.
     */
    public func removeOverlay(owner: String): Unit {
        if (owner.isEmpty()) {
            return
        }
        var i = overlays.size - 1
        while (i >= 0) {
            if (overlays[i].owner == owner) {
                overlays.remove(at: i)
            }
            i -= 1
        }
    }

    /** Removes every open overlay — the shell calls this each frame before the tree re-registers. */
    public func clearActiveOverlay(): Unit {
        overlays.clear()
    }

    /** Whether any interactive overlay is currently open. */
    public func hasOverlay(): Bool {
        !overlays.isEmpty()
    }

    /** How many interactive overlays are currently open (a dialog plus its popup counts two). */
    public func overlayCount(): Int64 {
        overlays.size
    }

    /**
     * Offers `event` to the open overlays, top-most first; returns whether one consumed it.
     * A layer that does not consume lets the event fall to the layer beneath — a Modal
     * consumes everything, so events never pass a dialog into the backdrop tree. Public so
     * a custom shell (not just `DesktopApp`) can route events through the overlays.
     */
    public func dispatchOverlay(event: UiEvent): Bool {
        // Walk a snapshot: a handler may close (remove) overlays mid-dispatch. An entry
        // removed by a layer above it is skipped rather than offered a stale event.
        let snapshot = overlays.toArray()
        var i = snapshot.size - 1
        while (i >= 0) {
            let overlay = snapshot[i]
            if (isRegistered(overlay) && overlay.dispatch(this, event)) {
                return true
            }
            i -= 1
        }
        false
    }

    private func isRegistered(overlay: Overlay): Bool {
        for (candidate in overlays) {
            if (refEq(candidate, overlay)) {
                return true
            }
        }
        false
    }

    /**
     * Paints the open overlays bottom to top, after the tree; a custom shell calls this
     * once per frame. Rendering a layer may register further overlays (a dropdown open
     * inside a dialog registers while the dialog's body draws) — the loop picks them up
     * and paints them above, within the same frame.
     */
    public func drawActiveOverlay(): Unit {
        var i = 0
        while (i < overlays.size) {
            overlays[i].render(this)
            i += 1
        }
    }

    /** The pointer shape requested by the hovered control, or `Default` when none. */
    protected func desiredCursor(): CursorShape {
        settledHoverShape
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

    /** Marks a control as pressed until the primary pointer is released. */
    public func press(id: String): Unit {
        pressedId = id
    }

    /** Returns whether `id` owns the active primary-pointer press. */
    public func isPressed(id: String): Bool {
        pressedId == id
    }

    /** Clears the active primary-pointer press. */
    public func clearPress(): Unit {
        pressedId = ""
    }
}
