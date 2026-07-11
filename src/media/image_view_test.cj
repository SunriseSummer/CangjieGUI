/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.media

import sdl.{Renderer, Size}
import cui.core.{Theme, UiContext}

@Test
func imageViewMeasuresAndClosesWithoutLoadingTexture(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let image = ImageView("missing.bmp", preferredHeight: 96.0)

    let measured = image.measure(ctx, Size(240.0, 40.0))
    image.close()
    image.close()

    @Expect(measured.w, Float32(240.0))
    @Expect(measured.h, Float32(40.0))
    @Expect(image.isClosed())
}
