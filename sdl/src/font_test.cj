/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

@Test
func systemUiFontMeasuresChineseAndLatinText(): Unit {
    let window = SdlWindow(WindowSpec("Font test", 320, 120))
    try {
        @Expect(window.renderer.textWidth("仓颉 GUI", pointSize: FontSizes.BODY) > 0.0)
        @Expect(window.renderer.textHeight(pointSize: FontSizes.BODY) > 0.0)
    } finally {
        window.close()
    }
}
