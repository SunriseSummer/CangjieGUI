package bench_micro

import cui.{ImageView, Rect, clearImageCache}
import bench_harness.{report, timeit}

private class FreshImageViewBench {
    let context = headlessContext()

    func drawOnce(): Int64 {
        let image = ImageView("__cui_missing_media_cache_benchmark__.bmp")
        image.layout(context, Rect(0.0, 0.0, 96.0, 96.0))
        image.draw(context)
        image.close()
        1
    }
}

/*
 * Measures the per-frame hot path after a failed image load has been cached. A deliberately
 * missing path keeps the benchmark headless and deterministic while still exercising
 * ImageView.draw -> sharedTexture -> cache lookup on every iteration.
 */
func runMediaCacheBench(): Unit {
    clearImageCache()
    let context = headlessContext()
    let image = ImageView("__cui_missing_media_cache_benchmark__.bmp")
    image.layout(context, Rect(0.0, 0.0, 96.0, 96.0))
    image.draw(context)

    report(
        "micro",
        "Media cache",
        timeit(
            "cached failure draw",
            1000000,
            {
                =>
                    image.draw(context)
                    1
            }
        )
    )

    let fresh = FreshImageViewBench()
    report(
        "micro",
        "Media cache",
        timeit("fresh view cached failure draw", 100000, {=> fresh.drawOnce()})
    )

    image.close()
    clearImageCache()
}
