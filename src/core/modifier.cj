package cui.core

import sdl.{Color, SurfaceStyle, UiEvent}

private let MODIFIER_BALANCE_THRESHOLD: Int64 = 8

/**
 * A reusable endomorphism over Widget values. `then` composes modifiers in source order and
 * `Modifier()` is the identity, so style bundles form an associative monoid without introducing
 * another component lifecycle.
 */
public class Modifier {
    private let transform: (Widget) -> Widget

    /** Creates the identity modifier. */
    public init() {
        transform = {widget => widget}
    }

    private init(transform: (Widget) -> Widget) {
        this.transform = transform
    }

    /** Applies this reusable pipeline to one Widget. */
    public func applyTo(widget: Widget): Widget {
        transform(widget)
    }

    /** Applies this modifier, then `next`; composition is associative. */
    public func then(next: Modifier): Modifier {
        Modifier({widget => next.applyTo(applyTo(widget))})
    }

    /** Adapts an application-defined Widget transformation into a Modifier. */
    public static func custom(transform: (Widget) -> Widget): Modifier {
        Modifier(transform)
    }

    /** Combines an ordered runtime collection into a balanced modifier product. */
    public static func concat(values: Array<Modifier>): Modifier {
        if (values.size <= MODIFIER_BALANCE_THRESHOLD) {
            return linearModifierProduct(values)
        }
        balancedModifierProduct(values, 0, values.size)
    }

    /** Constrains the wrapped Widget to the requested width. */
    public static func width(value: Length): Modifier {
        Modifier({widget => widget.width(value)})
    }

    /** Constrains the wrapped Widget to the requested height. */
    public static func height(value: Length): Modifier {
        Modifier({widget => widget.height(value)})
    }

    /** Makes the wrapped Widget consume its parent's available width. */
    public static func fillWidth(): Modifier {
        Modifier({widget => widget.fillWidth()})
    }

    /** Makes the wrapped Widget consume its parent's available height. */
    public static func fillHeight(): Modifier {
        Modifier({widget => widget.fillHeight()})
    }

    /** Adds equal padding on every side of the wrapped Widget. */
    public static func padding(value: Length): Modifier {
        Modifier({widget => widget.padding(value)})
    }

    /** Draws the supplied surface style behind the wrapped Widget. */
    public static func surface(value: SurfaceStyle): Modifier {
        Modifier({widget => widget.surface(value)})
    }

    /** Draws a square-cornered solid background behind the wrapped Widget. */
    public static func background(color: Color): Modifier {
        Modifier({widget => widget.background(color)})
    }

    /** Draws a rounded solid background behind the wrapped Widget. */
    public static func background(color: Color, radius: Length): Modifier {
        Modifier({widget => widget.background(color, radius)})
    }

    /** Declares equal custom paint overflow without affecting measurement. */
    public static func paintOutset(value: Float32): Modifier {
        Modifier({widget => widget.paintOutset(value)})
    }

    /** Declares asymmetric custom paint overflow without affecting measurement. */
    public static func paintOutset(value: PaintOutset): Modifier {
        Modifier({widget => widget.paintOutset(value)})
    }

    /** Participates in stack free-space distribution with the supplied weight. */
    public static func flex(weight!: Float32 = 1.0): Modifier {
        Modifier({widget => widget.flex(weight)})
    }

    /** Includes or removes the wrapped subtree from layout and interaction. */
    public static func visible(value: Bool): Modifier {
        Modifier({widget => widget.visible(value)})
    }

    /** Enables or disables interaction while preserving layout. */
    public static func enabled(value: Bool): Modifier {
        Modifier({widget => widget.enabled(value)})
    }

    /** Contributes accessibility semantics with an automatically scoped identity. */
    public static func semantics(properties: Semantics): Modifier {
        Modifier({widget => widget.semantics(properties)})
    }

    /** Contributes accessibility semantics with an explicit stable key. */
    public static func semantics(properties: Semantics, key!: String): Modifier {
        Modifier({widget => widget.semantics(properties, key: key)})
    }

    /** Observes routed input at the requested propagation phase and scope. */
    public static func onEvent(
        phase!: EventPhase = EventPhase.Bubble,
        scope!: EventScope = EventScope.Subtree,
        handler!: (UiContext, UiEvent) -> EventOutcome
    ): Modifier {
        Modifier({widget => widget.onEvent(phase: phase, scope: scope, handler: handler)})
    }
}

private func linearModifierProduct(values: Array<Modifier>): Modifier {
    if (values.isEmpty()) {
        return Modifier()
    }
    var result = values[0]
    for (index in 1..values.size) {
        result = result.then(values[index])
    }
    result
}

private func balancedModifierProduct(values: Array<Modifier>, start: Int64, end: Int64): Modifier {
    let size = end - start
    if (size <= 0) {
        return Modifier()
    }
    if (size == 1) {
        return values[start]
    }
    let middle = start + size / 2
    balancedModifierProduct(values, start, middle).then(balancedModifierProduct(values, middle, end))
}
