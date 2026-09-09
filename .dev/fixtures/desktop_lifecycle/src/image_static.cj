package cui_desktop_lifecycle_test

import std.fs.{Directory, File, exists, remove}
import cui.{Color, ImageFit, ImageSource, ImageStatus, ImageView, LengthUnits, Rect, SdlWindow, Surface, Theme, 
    UiContext, WindowSpec, clearImageCache, imageVersion}

// Runs with an empty working directory in the release gate. All assets are generated here;
// no repository paths, optional codecs or cjpm-provided library search paths are needed.
func verifyStaticImages(): Bool {
    let directory = Directory.createTemp(".").toString()
    let png = directory + "/sample.png"
    let jpg = directory + "/sample.jpg"
    let screenshot = directory + "/pixels.bmp"
    clearImageCache()
    try {
        if (imageVersion() < 3004006) {
            return false
        }
        try (surface = Surface.create(32, 24)) {
            surface.clear(Color.rgb(40, 120, 200))
            surface.savePng(png)
            surface.saveJpeg(jpg)
        }
        try (window = SdlWindow(WindowSpec("Static image release gate", 160, 60, supersample: 1), hidden: true)) {
            let ctx = UiContext(window.renderer, Theme.light())
            let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='32' height='24'><path fill='#2878c8' d='M0 0h32v24H0z'/></svg>"
            let sources = [ImageSource(png), ImageSource.memory(File.readFrom(jpg)), ImageSource.memory(svg.toArray())]
            try {
                window.renderer.beginScene(160.0, 60.0, Color.rgb(255, 255, 255))
                for (index in 0..sources.size) {
                    let view = ImageView(sources[index])
                        .size(32.vp, 24.vp)
                        .decodeSize(64, 48)
                        .fit(ImageFit.Cover)
                        .cornerRadius(6.vp)
                        .imageOpacity(0.5)
                    view.layout(ctx, Rect(10.0 + Float32(index) * 45.0, 10.0, 32.0, 24.0))
                    view.draw(ctx)
                    if (!match (view.status()) {
                        case ImageStatus.Ready => true;
                        case _ => false
                    }) {
                        return false
                    }
                }
                window.renderer.captureBmp(screenshot)
                window.renderer.endScene()
                try (pixels = Surface.load(screenshot)) {
                    let scale = pixels.size().w / 160.0
                    for (index in 0..sources.size) {
                        let color = pixels.readPixel(Int32((26.0 + Float32(index) * 45.0) * scale), Int32(22.0 * scale))
                        if (color.g < UInt8(182) || color.g > UInt8(192)) {
                            return false
                        }
                    }
                }
            } finally {
                clearImageCache()
            }
        }
    } finally {
        for (path in [png, jpg, screenshot]) {
            if (exists(path)) {
                remove(path)
            }
        }
        remove(directory)
    }
    true
}
