// 随附字体：一个字体族、多份静态字重文件，使用 fontWeight 选择。
package cui_wenkai

import cui.{FontWeight, FontSource, FontFamily, FontFaceDefinition}
import std.collection.ArrayList

// 一个字重：数值、界面标签、文件名。
struct Weight {
    let value: FontWeight
    let label: String
    let file: String

    init(value: FontWeight, label: String, file: String) {
        this.value = value
        this.label = label
        this.file = file
    }
}

// 比例字重（正文样张切换用），按由细到粗排列。
let WEIGHTS: Array<Weight> = [
    Weight(FontWeight.light, "Light 细", "LXGWWenKai-Light.ttf"),
    Weight(FontWeight.normal, "Regular 常规", "LXGWWenKai-Regular.ttf"),
    Weight(FontWeight.medium, "Medium 中", "LXGWWenKai-Medium.ttf")
]

// 等宽变体（代码样张用）。
let MONO: Weight = Weight(FontWeight.normal, "Mono 等宽", "LXGWWenKaiMono-Regular.ttf")

// 字体目录的候选相对路径（示例的工作目录是 examples/wenkai，也兼容从仓库根运行）。
let WENKAI_FAMILY = "wenkai"
let WENKAI_MONO = "wenkai-mono"
let FONT_DIR_CANDIDATES: Array<String> = ["assets/fonts", "../../.todo/testfonts", ".todo/testfonts",
    "../.todo/testfonts"]

// 样张文案：苏轼《定风波》上阕（公版），另配拉丁与数字行验证混排。
let SPECIMEN_TITLE: String = "霞鹜文楷"
let SPECIMEN_POEM: String = "莫听穿林打叶声，何妨吟啸且徐行。竹杖芒鞋轻胜马，谁怕？一蓑烟雨任平生。"
let SPECIMEN_LATIN: String = "The quick brown fox jumps over the lazy dog — 0123456789"
let MONO_LINES: Array<String> = [
    "Label(\"仓颉\").fontFamily(\"wenkai\")",
    "    .fontWeight(FontWeight.medium)",
    "0O 1lI 2Z 5S 8B —— 等宽字形区分度一览"
]

// 只有包含 Regular 文件的目录才可用；空 assets 目录不能遮住后续候选。
func resolveFontsDir(candidates: Array<String>, exists: (String) -> Bool): ?String {
    for (dir in candidates) {
        if (exists(dir + "/" + WEIGHTS[1].file)) {
            return Some(dir)
        }
    }
    None
}

// 一个比例字体族关联全部可用静态字重；只登记确实存在的文件。
func registerWeights(dir: ?String, exists: (String) -> Bool, register: (String, FontFamily) -> Unit): Int64 {
    let base = match (dir) {
        case Some(value) => value;
        case None => return 0
    }
    let regular = base + "/" + WEIGHTS[1].file
    if (!exists(regular)) {
        return 0
    }
    let faces = ArrayList<FontFaceDefinition>()
    for (i in [0, 2]) {
        let weight = WEIGHTS[i]
        let path = base + "/" + weight.file
        if (exists(path)) {
            faces.add(FontFaceDefinition(FontSource(path), weight: weight.value))
        }
    }
    register(WENKAI_FAMILY, FontFamily(FontSource(regular), faces: faces.toArray()))
    var count = faces.size + 1
    let mono = base + "/" + MONO.file
    if (exists(mono)) {
        register(WENKAI_MONO, FontFamily(FontSource(mono)));
        count += 1
    }
    count
}
