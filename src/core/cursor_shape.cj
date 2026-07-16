package cui.core

/**
 * The semantic pointer shape a control asks for while the pointer is over it. The shell
 * maps each shape to a native system cursor, so control code stays independent of the
 * platform cursor set:
 *
 *  - `Default`     the resting shape; the shell shows the window's base cursor
 *  - `Interactive` a clickable affordance (buttons, switches, sliders) — a hand
 *  - `Text`        an editable text region — an I-beam
 *  - `ResizeH`     a horizontal resize affordance (a split-pane divider between columns) — ↔
 *  - `ResizeV`     a vertical resize affordance (a split-pane divider between rows) — ↕
 */
public enum CursorShape <: Equatable<CursorShape> {
    | Default
    | Interactive
    | Text
    | ResizeH
    | ResizeV

    public operator func ==(other: CursorShape): Bool {
        match ((this, other)) {
            case (CursorShape.Default, CursorShape.Default) => true
            case (CursorShape.Interactive, CursorShape.Interactive) => true
            case (CursorShape.Text, CursorShape.Text) => true
            case (CursorShape.ResizeH, CursorShape.ResizeH) => true
            case (CursorShape.ResizeV, CursorShape.ResizeV) => true
            case _ => false
        }
    }

    public operator func !=(other: CursorShape): Bool {
        !(this == other)
    }
}
