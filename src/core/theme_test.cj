package cui.core

import sdl.Color

@Test
func normalButtonRespectsTransparentAndSubtleThemeShadows(): Unit {
    let base = Theme.light()
    for (alpha in [Int64(0), Int64(12), Int64(28)]) {
        let theme = Theme(bg: base.bg, panel: base.panel, panelEdge: base.panelEdge, text: base.text,
            mutedText: base.mutedText, accent: base.accent, accentText: base.accentText, danger: base.danger,
            field: base.field, fieldActive: base.fieldActive, shadow: Color.rgba(15, 23, 42, alpha))
        @Expect(Int64(theme.buttonSurface(ButtonRole.Normal).shadow.a), min(alpha, Int64(20)))
    }
}
