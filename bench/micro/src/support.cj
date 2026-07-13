/*
 * Shared setup for the headless benchmarks. A headless UiContext drives real widget layout and
 * draw without a window: geometry, event handling and string work run for real, while the renderer
 * is a no-op and text is measured by estimate. See bench/README.md for what that does and does not
 * capture.
 */
package bench_micro

import cui.{Renderer, Theme, UiContext}

/** A fresh headless context at the default 1.0 display and font scale. */
func headlessContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}
