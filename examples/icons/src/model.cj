package cui_icons

import cui.*
import std.fs.File

let INK = Color.rgb(24, 55, 64)
let TEAL = Color.rgb(38, 119, 119)
let PAPER = Color.rgb(248, 247, 242)
let LINE = Color.rgb(220, 226, 221)

class IconsModel {
    let dark = State<Bool>(false)
    let selection = State<String>("design")
    let clicks = State<Int64>(0)
    // The immutable encoded snapshot is created once, outside every rebuilt view body.
    let memory = IconSource.memory(File.readFrom("assets/icons/spark.svg"), typeHint: "SVG")
    let brand = IconSource.variants(
        [
            IconVariant("assets/icons/orbit-24.png", 24),
            IconVariant("assets/icons/orbit-48.png", 48),
            IconVariant("assets/icons/orbit-72.png", 72),
            IconVariant("assets/icons/orbit-96.png", 96),
            IconVariant("assets/icons/orbit-144.png", 144),
            IconVariant("assets/icons/orbit-192.png", 192)
        ],
        renderingMode: IconRenderingMode.Original
    )
}

func asset(name: String): IconSource {
    IconSource("assets/icons/${name}.svg")
}
