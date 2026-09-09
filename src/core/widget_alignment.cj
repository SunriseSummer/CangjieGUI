package cui.core

/** A layout direction: stacks lay out along one axis; stretch rules are asked per axis. */
public enum Axis {
    | Horizontal
    | Vertical
}

/** A button's visual intent, mapped by the theme to a fill/border set (see `buttonSurface`). */
public enum ButtonRole {
    | Normal
    | Primary
    | Danger
}

/** Horizontal text alignment within a label's frame, in reading direction. */
public enum TextAlign {
    | Leading
    | Center
    | Trailing
}

/** Controls how a stack positions children along its main axis. */
public enum MainAxisAlignment {
    | Start
    | Center
    | End
    | SpaceBetween
    | SpaceAround
    | SpaceEvenly
}

/** Controls how a stack positions children across its main axis. */
public enum CrossAxisAlignment {
    | Start
    | Center
    | End
    | Stretch
}

/** A two-dimensional alignment used by overlay-style containers. */
public enum Alignment {
    | TopLeading
    | Top
    | TopTrailing
    | Leading
    | Center
    | Trailing
    | BottomLeading
    | Bottom
    | BottomTrailing
}
