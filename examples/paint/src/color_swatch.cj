package cui_paint

import cui.{Button, Color, LengthUnits, Semantics, SemanticsRole, State, SurfaceStyle, Tooltip}

// Reuse Button's press/release, Tab, Space/Enter and accessibility activation protocols.
func colorSwatch(entry: PaintColor, selected: State<Color>): Unit {
    let color = selected.value
    let active = color.r == entry.color.r && color.g == entry.color.g && color.b == entry.color.b && color.a == entry
        .color
        .a
    Tooltip(text: entry.name) {
        Button("", {=> selected.value = entry.color},
            style: SurfaceStyle(entry.color, border: Color.rgb(32, 52, 44), borderWidth: if (active) {
                2.0
            } else {
                0.0
            }, radius: 7.0))
            .key("paint-color-${entry.name}")
            .width(28.vp)
            .height(28.vp)
            .semantics(Semantics(label: entry.name, role: SemanticsRole.Button, selected: active))
    }
}
