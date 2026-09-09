package cui_images

import cui.*
import std.fs.File

let FORMATS = ["JPEG", "PNG", "SVG", "GIF", "QOI", "BMP", "TGA", "内存"]
let EXTENSIONS = ["jpg", "png", "svg", "gif", "qoi", "bmp", "tga"]
let FITS = [ImageFit.Contain, ImageFit.Cover, ImageFit.Stretch, ImageFit.ScaleDown, ImageFit.Original]

class ImagesModel {
    let format = State<Int64>(0)
    let fit = State<Int64>(1)
    let opacity = State<Float32>(1.0)
    let rounded = State<Bool>(true)
    let mirrored = State<Bool>(false)
    let memory = ImageSource.memory(File.readFrom("assets/alpine.png"))

    func source(): ImageSource {
        if (format.value == 7) {
            memory
        } else {
            ImageSource("assets/alpine.${EXTENSIONS[format.value]}")
        }
    }
}
