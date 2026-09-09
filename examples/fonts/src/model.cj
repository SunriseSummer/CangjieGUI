/*
 * 字体实验室状态：按族名定向解析，只在开发者点击加载/刷新时查询完整目录。
 *
 * 选中字体名是选中下标的纯函数派生；SegmentedControl/Chip 直接绑定 State（State 即 Bindable）。
 */
package cui_fonts

import cui.{State, Fonts, FontWeight, FontStyle, FontVariations, FontVariation, FontAxis, InstalledFontFace}
import std.collection.ArrayList

class FontsModel {
    let familyNames = State<Array<String>>(["system-ui", "sans-serif", "serif", "monospace"])
    let catalogLoaded = State<Bool>(false)
    let installed = State<Array<InstalledFontFace>>([])
    let chosenFamily = State<String>("system-ui")
    let weight = State<Float32>(625.0)
    let size = State<Float32>(24.0)
    let useAxes = State<Bool>(false)
    let widthAxis = State<Float32>(100.0)
    let opticalAxis = State<Float32>(18.0)
    let section = State<Int64>(0)
    let faces: Array<TypeFace> = TYPEFACES
    let selected = State<Int64>(1) // 默认选中衬线，凸显与系统字体的差异
    let bold = State<Bool>(false)
    let italic = State<Bool>(false)
    let text = State<String>("AV office 仓颉")
    private var axesFamily = ""
    private var axesRevision: UInt64 = UInt64.Max
    private var cachedAxes: Array<FontAxis> = []

    init(discover!: Bool = false, preferVariable!: Bool = false) {
        if (discover) {
            reloadCatalog()
        }
        if (preferVariable && !Fonts.familyFaces("Cascadia Code").isEmpty()) {
            chosenFamily.value = "Cascadia Code"
            if (!catalogLoaded.value) { familyNames.value = ["Cascadia Code", "system-ui", "sans-serif", "serif", "monospace"] }
        }
    }

    func reloadCatalog(): Unit {
        familyNames.value = Fonts.systemFamilyNames()
        installed.value = Fonts.systemFonts()
        catalogLoaded.value = true
    }

    func refresh(): Unit {
        Fonts.refreshSystemFonts(force: true)
        reloadCatalog()
    }

    // 展示当前字体声明的轴；实际选中的文件与字重另由 Renderer.resolveFont 报告。
    func axes(): Array<FontAxis> {
        if (axesFamily != chosenFamily.value || axesRevision != Fonts.revision()) {
            axesFamily = chosenFamily.value; axesRevision = Fonts.revision(); cachedAxes = []
            for (face in Fonts.familyFaces(axesFamily)) {
                if (!face.axes().isEmpty()) { cachedAxes = face.axes(); break }
            }
        }
        cachedAxes
    }

    func previewStyle(): FontStyle {
        let coordinates = ArrayList<FontVariation>()
        if (useAxes.value && Fonts.supportsVariations()) {
            for (axis in axes()) {
                if (axis.tag == "wdth" || axis.tag == "opsz") {
                    let value = if (axis.tag == "wdth") {
                        widthAxis.value
                    } else {
                        opticalAxis.value
                    }
                    coordinates.add(FontVariation(axis.tag, max(axis.minimum, min(axis.maximum, value))))
                }
            }
        }
        FontStyle(weight: FontWeight(Int64(weight.value)), italic: italic.value,
            variations: FontVariations(coordinates.toArray()))
    }

    func hasExtraAxes(): Bool {
        for (axis in axes()) {
            if (axis.tag == "wdth" || axis.tag == "opsz") {
                return true
            }
        }
        false
    }

    // 可复现的演示入口；按能力选择本机字体，不绑定操作系统或猜测字体路径。
    func selectDemo(name: String): Unit {
        if (name == "large") {
            size.value = 40.0
            return
        }
        if (name == "roles") {
            section.value = 1
            return
        }
        if (name == "italic") {
            italic.value = true
            return
        }
        let tag = if (name == "width") {
            "wdth"
        } else if (name == "optical") {
            "opsz"
        } else {
            return
        }
        if (!catalogLoaded.value) { reloadCatalog() }
        for (face in installed.value) {
            for (axis in face.axes()) {
                if (axis.tag == tag) {
                    chosenFamily.value = face.familyName
                    useAxes.value = true
                    widthAxis.value = if (tag == "wdth") {
                        axis.minimum
                    } else {
                        100.0
                    }
                    opticalAxis.value = if (tag == "opsz") {
                        axis.maximum
                    } else {
                        18.0
                    }
                    return
                }
            }
        }
    }

    // 样张当前选用的字体注册名（None = 系统默认）。
    func currentFace(): ?String {
        faceName(faces, selected.value)
    }

    // 供 SegmentedControl 使用的字体标签数组。
    func labels(): Array<String> {
        let out = Array<String>(faces.size, {i => faces[i].label})
        out
    }
}
