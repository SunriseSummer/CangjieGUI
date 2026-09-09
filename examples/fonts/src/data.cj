// 通用字体角色及选择映射；不依赖平台文件路径。
package cui_fonts

import cui.FontRole

// 一种字体角色：显示名和族名选择器；None 继承应用默认。
struct TypeFace {
    let label: String
    let family: ?String

    init(label: String, family: ?String) {
        this.label = label
        this.family = family
    }
}

// 通用角色交给平台选择，不依赖具体系统字体或文件路径。
let TYPEFACES: Array<TypeFace> = [
    TypeFace("应用默认", None),
    TypeFace("衬线 Serif", FontRole.serif),
    TypeFace("等宽 Mono", FontRole.monospace)
]

// 样张：拉丁字母 + 数字 + 标点。用拉丁文而非中西混排，因为示例加载的 Georgia/Consolas 等拉丁字体
// 不含 CJK 字形（由 fallback 字体补齐），CJK 覆盖仍由系统字体承担；此处专注对比衬线、等宽与无衬线的字形。
let SPECIMEN = "Hamburgefonstiv — the quick brown fox 0123456789"

// 选中下标对应的字体注册名（越界或系统默认项返回 None，即不套用 fontFamily）。
func faceName(faces: Array<TypeFace>, index: Int64): ?String {
    if (index < 0 || index >= faces.size) {
        return None
    }
    faces[index].family
}
