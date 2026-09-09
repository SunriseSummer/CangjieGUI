package cui_desktop_lifecycle_test

import std.collection.ArrayList
import std.fs.{Directory, File, exists, remove}
import cui.{Label, LengthUnits, Panel, Rect, ScrollView, SdlWindow, State, UiEvent, VStack, WidgetTestHost, WindowSpec}

func verifyNumericRecovery(): Bool {
    let artifactRoot = if (exists("target")) { "target" } else { "." }
    let directory = Directory.createTemp(artifactRoot).toString()
    let paths = ArrayList<String>()
    try {
        for (sampling in [Int32(1), Int32(2)]) {
            try (window = SdlWindow(WindowSpec("Numeric recovery E2E", 320, 180, supersample: sampling), hidden: true)) {
                let host = WidgetTestHost(renderer: window.renderer, displayScale: Float32.NaN, fontScale: Float32.Inf)
                let offset = State<Float32>(Float32.NaN)
                let bounds = Rect(0.0, 0.0, 320.0, 180.0)
                let view: () -> Unit = {=>
                    ScrollView(key: "numeric") {
                        VStack {
                            Label("Recovery AV 仓颉").fontSize(24.fp).height(64.vp)
                            Panel { Label("Tail") }.height(400.vp)
                        }.spacing(8.vp).hug()
                    }.scrollState(offset)
                    ()
                }
                window.renderer.prepareTextLayout(bounds.w, bounds.h)
                try {
                    let _ = host.frame(bounds, body: view)
                    if (host.context.displayScale != 1.0 || host.context.fontScale != 1.0 || offset.value != 0.0) {
                        return false
                    }
                    let repaired = recoverySnapshot(window, directory, paths)
                    host.context.displayScale = 1.0
                    host.context.fontScale = 1.0
                    let _ = host.frame(bounds, body: view)
                    let reference = recoverySnapshot(window, directory, paths)
                    if (!sameRecoveryPixels(repaired, reference)) { return false }
                    offset.value = Float32.Inf
                    let _ = host.frame(bounds, body: view)
                    if (offset.value <= 0.0 || offset.value.isInf() || offset.value.isNaN()) { return false }
                    let bottom = recoverySnapshot(window, directory, paths)
                    let _ = host.frame(bounds, events: [UiEvent.MouseWheel(0.0, -1000.0, 25.0, 25.0)], body: view)
                    let bottomReference = recoverySnapshot(window, directory, paths)
                    if (!sameRecoveryPixels(bottom, bottomReference)) { return false }
                    for (invalid in [Rect(2147483520.0, 0.0, 256.0, 10.0), Rect(0.0, 2147483520.0, 10.0, 256.0)]) {
                        var rejected = false
                        try { window.renderer.pushClip(invalid) }
                        catch (_: IllegalArgumentException) { rejected = true }
                        if (!rejected || window.renderer.currentClip().isSome()) { return false }
                    }
                    let _ = host.frame(bounds, body: view)
                    let afterRejection = recoverySnapshot(window, directory, paths)
                    if (!sameRecoveryPixels(afterRejection, bottomReference)) { return false }
                } finally { host.reset() }
            }
        }
    } finally {
        for (path in paths) { if (exists(path)) { remove(path) } }
        remove(directory)
    }
    true
}

private func sameRecoveryPixels(left: String, right: String): Bool {
    let a = File.readFrom(left)
    let b = File.readFrom(right)
    if (a.size != b.size) { return false }
    for (index in 0..a.size) { if (a[index] != b[index]) { return false } }
    true
}

// Never overwrite an image that a background scanner or file preview may still be reading.
private func recoverySnapshot(window: SdlWindow, directory: String, paths: ArrayList<String>): String {
    let path = "${directory}/frame-${paths.size}.bmp"
    paths.add(path)
    window.renderer.captureBmp(path)
    path
}
