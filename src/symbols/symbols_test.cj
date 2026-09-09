package cui.symbols

import cui.core.{Theme, UiContext}
import cui.media.{Icon, IconSource, IconRenderingMode, clearImageCache, imageCacheStats}
import cui.media.{invalidateIcon, preloadIcon}
import sdl.{Color, Rect, SdlWindow, Surface, WindowSpec}
import sdl.system.FileSystem
import cui.symbols.calendar.ICON_CALENDAR
import cui.symbols.clock.ICON_CLOCK
import cui.symbols.search.ICON_SEARCH
import cui.symbols.home.ICON_HOME
import cui.symbols.menu.ICON_MENU
import cui.symbols.more.ICON_MORE
import cui.symbols.plus.ICON_PLUS
import cui.symbols.minus.ICON_MINUS
import cui.symbols.check.ICON_CHECK
import cui.symbols.close.ICON_CLOSE
import cui.symbols.chevron_left.ICON_CHEVRON_LEFT
import cui.symbols.chevron_right.ICON_CHEVRON_RIGHT
import cui.symbols.chevron_up.ICON_CHEVRON_UP
import cui.symbols.chevron_down.ICON_CHEVRON_DOWN
import cui.symbols.arrow_left.ICON_ARROW_LEFT
import cui.symbols.arrow_right.ICON_ARROW_RIGHT
import cui.symbols.arrow_up.ICON_ARROW_UP
import cui.symbols.arrow_down.ICON_ARROW_DOWN
import cui.symbols.external_link.ICON_EXTERNAL_LINK
import cui.symbols.refresh.ICON_REFRESH
import cui.symbols.download.ICON_DOWNLOAD
import cui.symbols.upload.ICON_UPLOAD
import cui.symbols.document.ICON_DOCUMENT
import cui.symbols.folder.ICON_FOLDER
import cui.symbols.save.ICON_SAVE
import cui.symbols.copy.ICON_COPY
import cui.symbols.paste.ICON_PASTE
import cui.symbols.edit.ICON_EDIT
import cui.symbols.trash.ICON_TRASH
import cui.symbols.settings.ICON_SETTINGS
import cui.symbols.info.ICON_INFO
import cui.symbols.warning.ICON_WARNING
import cui.symbols.help.ICON_HELP
import cui.symbols.lock.ICON_LOCK
import cui.symbols.eye.ICON_EYE
import cui.symbols.user.ICON_USER
import cui.symbols.heart.ICON_HEART
import cui.symbols.star.ICON_STAR
import cui.symbols.bell.ICON_BELL
import cui.symbols.image.ICON_IMAGE

private func sources(): Array<IconSource> {
    [
        ICON_CALENDAR,
        ICON_CLOCK,
        ICON_SEARCH,
        ICON_HOME,
        ICON_MENU,
        ICON_MORE,
        ICON_PLUS,
        ICON_MINUS,
        ICON_CHECK,
        ICON_CLOSE,
        ICON_CHEVRON_LEFT,
        ICON_CHEVRON_RIGHT,
        ICON_CHEVRON_UP,
        ICON_CHEVRON_DOWN,
        ICON_ARROW_LEFT,
        ICON_ARROW_RIGHT,
        ICON_ARROW_UP,
        ICON_ARROW_DOWN,
        ICON_EXTERNAL_LINK,
        ICON_REFRESH,
        ICON_DOWNLOAD,
        ICON_UPLOAD,
        ICON_DOCUMENT,
        ICON_FOLDER,
        ICON_SAVE,
        ICON_COPY,
        ICON_PASTE,
        ICON_EDIT,
        ICON_TRASH,
        ICON_SETTINGS,
        ICON_INFO,
        ICON_WARNING,
        ICON_HELP,
        ICON_LOCK,
        ICON_EYE,
        ICON_USER,
        ICON_HEART,
        ICON_STAR,
        ICON_BELL,
        ICON_IMAGE
    ]
}

@Test
func everySymbolDecodesAtUiAndHighDensitySizes(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Symbol sizes", 80, 60), hidden: true)) {
        for (source in sources()) {
            for (pixels in [16, 20, 24, 32, 48, 96]) {
                @Expect(preloadIcon(window.renderer, source, pixels: Int32(pixels)))
            }
            @Expect(preloadIcon(window.renderer, source.withRenderingMode(IconRenderingMode.Original), pixels: 24))
        }
        @Expect(imageCacheStats().loadFailures, UInt64(0))
        clearImageCache()
    }
}

@Test
func constantsReuseIdentitiesAndInvalidationOnlyEvictsSelectedSymbol(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Symbol identity", 80, 60), hidden: true)) {
        let values = sources()
        for (source in sources()) { @Expect(preloadIcon(window.renderer, source, pixels: 24)) }
        let misses = imageCacheStats().misses
        @Expect(misses, UInt64(values.size))
        for (_ in 0..10) {
            for (source in sources()) { @Expect(preloadIcon(window.renderer, source, pixels: 24)) }
        }
        @Expect(imageCacheStats().misses, misses)
        invalidateIcon(ICON_CALENDAR)
        @Expect(imageCacheStats().entries, values.size - 1)
        @Expect(preloadIcon(window.renderer, ICON_CLOCK, pixels: 24))
        @Expect(imageCacheStats().misses, misses)
        @Expect(preloadIcon(window.renderer, ICON_CALENDAR, pixels: 24))
        @Expect(imageCacheStats().misses, misses + UInt64(1))
        clearImageCache()
    }
}

@Test
func everySymbolRendersVisibleTintedArtworkInsideItsBounds(): Unit {
    clearImageCache()
    let path = "__symbol-pixel-contract.bmp"
    try {
        try (window = SdlWindow(WindowSpec("Symbol pixels", 512, 320, supersample: 1), hidden: true)) {
            let ctx = UiContext(window.renderer, Theme.light())
            let values = sources()
            window.renderer.beginScene(512.0, 320.0, Color.rgb(255, 255, 255))
            for (index in 0..values.size) {
                let view = Icon(values[index]).iconSize(32.0).foregroundColor(Color.rgb(20, 100, 180))
                view.layout(ctx, Rect(Float32(index % 8 * 64 + 16), Float32(index / 8 * 64 + 16), 32.0, 32.0))
                view.draw(ctx)
            }
            window.renderer.endScene()
            window.renderer.captureBmp(path)
            try (pixels = Surface.loadBmp(path)) {
                for (index in 0..values.size) {
                    var ink = 0
                    for (y in 0..64) {
                        for (x in 0..64) {
                            let color = pixels.readPixel(
                                Int32(Float32(index % 8 * 64 + x) * pixels.size().w / 512.0),
                                Int32(Float32(index / 8 * 64 + y) * pixels.size().h / 320.0))
                            if (color.r < UInt8(240)) {
                                ink += 1
                                @Expect(color.b > color.g && color.g > color.r)
                                @Expect(x >= 16 && x < 48 && y >= 16 && y < 48)
                            }
                        }
                    }
                    @Expect(ink > 15 && ink < 700)
                }
            }
            clearImageCache()
        }
    } finally {
        clearImageCache()
        if (FileSystem.exists(path)) { FileSystem.remove(path) }
    }
}
