package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.{FrameInfo, Rect, Renderer, UiEvent, UiEventMetadata}

/*
 * Per-frame services shared by every widget: rendering/theme, pointer and frame state, focus, hover,
 * press, drag, tooltip, IME, semantics and overlays. One instance lives for the whole application;
 * the shell brackets dispatch/drawing and widgets use its public claim/query surface. `resolve`
 * converts vp/px/fp lengths; `requestFrame()` keeps animation alive while dirty-frame skipping is idle.
 */
public class UiContext {
    public let renderer: Renderer
    public let theme: Theme
    internal var focusIdValue: String = ""
    // Whether the focused control should paint a ring: true when focus last moved by keyboard
    // (Tab traversal or autofocus), false when a pointer press claimed it — the :focus-visible
    // convention. Behaviour (activation, caret, arrow nav) uses `focusId`; only the ring gates on this.
    internal var focusRingVisibleValue: Bool = false
    internal var hoverIdValue: String = ""
    internal var dragIdValue: String = ""
    internal var pressedIdValue: String = ""
    // Single-slot overlay: a hovered `Tooltip` registers here during draw and the shell
    // paints it above everything after the tree. Empty text means no tooltip this frame.
    internal var tooltipTextValue: String = ""
    internal var tooltipAnchorValue: Rect = Rect.zero()
    internal var mouseXValue: Float32 = 0.0
    internal var mouseYValue: Float32 = 0.0
    internal var leftMouseDownValue: Bool = false
    internal var shouldCloseValue: Bool = false
    internal var frameValue: FrameInfo = FrameInfo(UInt64(0), UInt64(0))
    /** Logical size of the drawing surface; overlays clamp their popups to it. */
    internal var viewportWidthValue: Float32 = 0.0
    internal var viewportHeightValue: Float32 = 0.0
    // Interactive overlays open this frame, bottom to top. Registration order is z-order:
    // the tree draws first (a Modal registers its dialog), then the overlay render pass
    // draws each layer's content, so a popup opened inside a dialog registers — and
    // paints — above it. Events walk the stack top-down (see `dispatchOverlay`).
    private let overlayRegistry = OverlayRegistry()
    // Layout replay must capture registrations, not just growth of the active stack: registering an
    // existing owner replaces in place and leaves the stack size unchanged.
    internal let semanticContributions = ArrayList<SemanticContribution>()
    internal var committedSemantics: ?CommittedSemantics = None
    internal var semanticRevision: UInt64 = UInt64(0)
    internal var semanticProvidersDirty = false
    internal var spatialClip: ?SpatialClip = None
    internal var accessibilityAdapter: ?AccessibilityAdapter = None
    /** Physical pixels per virtual pixel; set from the window content scale. */
    internal var displayScaleValue: Float32 = 1.0
    /** User font scale applied to `fp` lengths; `1.0` keeps `fp` equal to `vp`. */
    internal var fontScaleValue: Float32 = 1.0
    internal var uiEnvironmentGeneration = allocateUiEnvironmentGeneration()
    internal var observedFontRegistryRevision: UInt64 = UInt64(0)
    internal var uiEnvironmentNeedsFontRefresh = true
    let paragraphCache = ParagraphLayoutCache()
    var currentEventMetadata = UiEventMetadata()
    var eventPropagationActive = false
    var eventPropagationHandled = false
    var eventPropagationStopped = false
    var compositionOwner = ""
    var compositionValue: ?ImeComposition = None
    var candidateValue: ?ImeCandidates = None

    /** Public key of the control that currently owns keyboard focus. */
    public mut prop focusId: String {
        get() {
            focusIdValue
        }
        set(value) {
            focusIdValue = value
        }
    }

    /** Whether the focused control should paint keyboard focus-visible feedback. */
    public mut prop focusRingVisible: Bool {
        get() {
            focusRingVisibleValue
        }
        set(value) {
            focusRingVisibleValue = value
        }
    }

    /** Public key of the control that won the latest pointer hover arbitration. */
    public mut prop hoverId: String {
        get() {
            hoverIdValue
        }
        set(value) {
            hoverIdValue = value
        }
    }

    /** Public key of the control that currently owns pointer drag capture. */
    public mut prop dragId: String {
        get() {
            dragIdValue
        }
        set(value) {
            dragIdValue = value
        }
    }

    /** Public key of the control holding the active press protocol. */
    public mut prop pressedId: String {
        get() {
            pressedIdValue
        }
        set(value) {
            pressedIdValue = value
        }
    }

    /** Text registered for the current frame's single tooltip layer. */
    public mut prop tooltipText: String {
        get() {
            tooltipTextValue
        }
        set(value) {
            tooltipTextValue = value
        }
    }

    /** Logical rectangle that anchors the current tooltip. */
    public mut prop tooltipAnchor: Rect {
        get() {
            tooltipAnchorValue
        }
        set(value) {
            tooltipAnchorValue = value
        }
    }

    /** Latest pointer x coordinate in logical pixels. */
    public mut prop mouseX: Float32 {
        get() {
            mouseXValue
        }
        set(value) {
            mouseXValue = value
        }
    }

    /** Latest pointer y coordinate in logical pixels. */
    public mut prop mouseY: Float32 {
        get() {
            mouseYValue
        }
        set(value) {
            mouseYValue = value
        }
    }

    /** Whether the primary mouse button is currently held. */
    public mut prop leftMouseDown: Bool {
        get() {
            leftMouseDownValue
        }
        set(value) {
            leftMouseDownValue = value
        }
    }

    /** Whether the application shell should leave its event loop. */
    public mut prop shouldClose: Bool {
        get() {
            shouldCloseValue
        }
        set(value) {
            shouldCloseValue = value
        }
    }

    /** Timing snapshot for the frame currently being processed. */
    public mut prop frame: FrameInfo {
        get() {
            frameValue
        }
        set(value) {
            frameValue = value
            uiEnvironmentNeedsFontRefresh = true
        }
    }

    /** Non-negative logical width available to overlays and layout. */
    public mut prop viewportWidth: Float32 {
        get() {
            viewportWidthValue
        }
        set(value) {
            viewportWidthValue = max(0.0, value)
        }
    }

    /** Non-negative logical height available to overlays and layout. */
    public mut prop viewportHeight: Float32 {
        get() {
            viewportHeightValue
        }
        set(value) {
            viewportHeightValue = max(0.0, value)
        }
    }

    /** Normalized primary-press count in the inclusive range 1 through 3. */
    public mut prop clickCount: Int64 {
        get() {
            clickCountValue
        }
        set(value) {
            clickCountValue = min(Int64(3), max(Int64(1), value))
        }
    }

    public init(renderer: Renderer, theme: Theme) {
        this.renderer = renderer
        this.theme = theme
    }

    internal var focusClaimedInPress = false
    internal var focusOrder: Array<FocusTarget> = []
    internal let focusTargetByKey = HashMap<String, FocusTarget>()
    internal let focusIndexByKey = HashMap<String, Int64>()
    internal var committedFocusSnapshot: ?FocusSnapshot = None
    internal var focusGraphRevision: UInt64 = UInt64(0)
    internal var focusedTarget: ?FocusTarget = None
    /** How many rapid presses ended at the current one: 1 single, 2 double, 3 triple. */
    internal var clickCountValue: Int64 = 1
    internal var lastPressMs: UInt64 = 0
    internal var lastPressX: Float32 = 0.0
    internal var lastPressY: Float32 = 0.0
    internal var hasLastPress = false

    // Immediate animation work and the earliest timer deadline requested in this frame. Keeping the
    // deadline lets the desktop loop sleep until a caret/tooltip actually changes instead of burning
    // all intervening refreshes.
    internal var immediateFrameRequested = false
    internal var frameDeadlineMs: ?UInt64 = None
    // One entry per nested retained-paint recording. Dynamic frame/interaction reads mark every
    // active ancestor so no parent display list can accidentally freeze a live child protocol.
    internal let retainedPaintDynamicReasons = ArrayList<?String>()
    internal var retainedDamage: ?Rect = None

    internal func markRetainedPaintDynamic(reason: String): Unit {
        for (index in 0..retainedPaintDynamicReasons.size) {
            if (retainedPaintDynamicReasons[index].isNone()) {
                retainedPaintDynamicReasons[index] = Some(reason)
            }
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
        markRetainedPaintDynamic("hover read during paint")
        hoverId == id
    }

    /** Registers a tooltip to paint above the tree this frame, anchored to `rect`. */
    public func showTooltip(text: String, rect: Rect): Unit {
        markRetainedPaintDynamic("tooltip registered during paint")
        tooltipText = text
        tooltipAnchor = rect
    }

    // Where the focused text control wants the IME composition UI anchored, in logical
    // pixels: the caret rectangle it reported during draw (blink phase or not). The shell
    // forwards changes to the window, so the candidate window follows the caret instead
    // of sitting in a screen corner.
    private var textInputAnchor: ?Rect = None

    /** Reports the focused caret rectangle this frame, anchoring the IME candidate window. */
    public func setTextInputAnchor(rect: Rect): Unit {
        markRetainedPaintDynamic("IME anchor registered during paint")
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
        markRetainedPaintDynamic("overlay registered during paint")
        overlayRegistry.register(overlay)
    }

    /**
     * Removes the overlay registered under `owner`, leaving the rest of the stack open —
     * a closing popup removes exactly its own registration, never a dialog beneath it.
     */
    public func removeOverlay(owner: String): Unit {
        overlayRegistry.remove(owner)
    }

    /** Removes every open overlay — the shell calls this each frame before the tree re-registers. */
    public func clearActiveOverlay(): Unit {
        overlayRegistry.clear()
    }

    /** Whether any interactive overlay is currently open. */
    public func hasOverlay(): Bool {
        markRetainedPaintDynamic("overlay state read during paint")
        !overlayRegistry.isEmpty()
    }

    /** How many interactive overlays are currently open (a dialog plus its popup counts two). */
    public func overlayCount(): Int64 {
        overlayRegistry.size
    }

    /** Number of overlay registration calls made in this layout pass. */
    func overlayRegistrationCount(): Int64 {
        overlayRegistry.registrationCount()
    }

    /** Non-empty overlay fragment registered since `start`, used by retained-layout replay. */
    func overlaySnapshotIfAnyFrom(start: Int64): ?OverlaySnapshot {
        overlayRegistry.snapshotIfAnyFrom(start)
    }

    /* Adopts one clean layout fragment in O(1), or composes it with existing declarations. */
    func registerOverlayFragment(snapshot: OverlaySnapshot): Unit {
        overlayRegistry.replay(snapshot)
    }

    func overlayFragmentReplayVisitCount(): UInt64 {
        overlayRegistry.replayVisitCount()
    }

    /**
     * Offers `event` to the open overlays, top-most first; returns whether one consumed it.
     * A layer that does not consume lets the event fall to the layer beneath — a Modal
     * consumes everything, so events never pass a dialog into the backdrop tree. Public so
     * a custom shell (not just `DesktopApp`) can route events through the overlays.
     */
    public func dispatchOverlay(event: UiEvent): Bool {
        overlayRegistry.dispatch(this, event)
    }

    /**
     * Paints the open overlays bottom to top, after the tree; a custom shell calls this
     * once per frame. Rendering a layer may register further overlays (a dropdown open
     * inside a dialog registers while the dialog's body draws) — the loop picks them up
     * and paints them above, within the same frame.
     */
    public func drawActiveOverlay(): Unit {
        markRetainedPaintDynamic("overlay draw requested during retained paint")
        overlayRegistry.draw(this)
    }

    /** The pointer shape requested by the hovered control, or `Default` when none. */
    protected func desiredCursor(): CursorShape {
        settledHoverShape
    }

    // Where inside the dragged part the pointer grabbed it. Lives here, not on the widget:
    // the tree is rebuilt every frame, so a controller instance recording the grab in a field
    // would lose it before the first MouseMove arrives at the next frame's fresh instance.
    private var dragGrabOffset: Float32 = 0.0

    /**
     * Marks `id` as the active drag owner. `grab!` records the pointer's offset within the
     * dragged part (for example pointer y minus thumb top), read back via `dragGrab()` on
     * later frames so the drag stays anchored where it was picked up instead of snapping.
     */
    public func beginDrag(id: String, grab!: Float32 = 0.0): Unit {
        dragId = id
        dragGrabOffset = grab
    }

    /** The grab-point offset recorded by `beginDrag`; meaningful only while that drag is active. */
    public func dragGrab(): Float32 {
        markRetainedPaintDynamic("drag state read during paint")
        dragGrabOffset
    }

    /** Whether `id` owns the active pointer drag started by `beginDrag`. */
    public func isDragging(id: String): Bool {
        markRetainedPaintDynamic("drag state read during paint")
        dragId == id
    }

    /** Ends the active drag, releasing the drag owner and its grab offset. */
    public func clearDrag(): Unit {
        dragId = ""
        dragGrabOffset = 0.0
    }

    /** Marks a control as pressed until the primary pointer is released. */
    public func press(id: String): Unit {
        pressedId = id
    }

    /** Returns whether `id` owns the active primary-pointer press. */
    public func isPressed(id: String): Bool {
        markRetainedPaintDynamic("press state read during paint")
        pressedId == id
    }

    /** Clears the active primary-pointer press. */
    public func clearPress(): Unit {
        pressedId = ""
    }
}
