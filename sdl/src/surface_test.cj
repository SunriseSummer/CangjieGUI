/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

@Test
func imageFormatFromPathSelectsPngCaseInsensitively(): Unit {
    @Expect(isPng(imageFormatFromPath("badge.png")))
    @Expect(isPng(imageFormatFromPath("BADGE.PNG")))
}

@Test
func imageFormatFromPathDefaultsToBmp(): Unit {
    @Expect(isBmp(imageFormatFromPath("badge.bmp")))
    @Expect(isBmp(imageFormatFromPath("badge")))
}

private func isPng(format: ImageFileFormat): Bool {
    match (format) {
        case ImageFileFormat.Png => true
        case ImageFileFormat.Bmp => false
    }
}

private func isBmp(format: ImageFileFormat): Bool {
    match (format) {
        case ImageFileFormat.Bmp => true
        case ImageFileFormat.Png => false
    }
}
