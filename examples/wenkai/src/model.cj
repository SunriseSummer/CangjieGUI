// 随附字体：一个字体族、多份静态字重文件，使用 fontWeight 选择。
package cui_wenkai

import cui.{State, FontWeight}

class WenkaiModel {
    // 已登记的字体数（0 表示目录缺失，全部回退系统字体）。
    let registered: Int64
    let selected = State<Int64>(1) // 默认 Regular

    init(registered: Int64) {
        this.registered = registered
    }

    func available(): Bool {
        registered > 0
    }

    // 字族保持不变，使用 FontWeight 表达不同的静态字体面。
    func family(): String {
        WENKAI_FAMILY
    }

    func weight(): FontWeight {
        let index = selected.value
        if (index < 0 || index >= WEIGHTS.size) {
            return FontWeight.normal
        }
        WEIGHTS[index].value
    }

    // 状态条文案。
    func statusText(): String {
        if (available()) {
            return "已配置 ${registered} 个字体文件 · 同一 FontFamily，当前请求 ${weight().value} · LXGW WenKai / SIL OFL"
        }
        "未找到 Regular 文件，正文回退系统字体；请准备 assets/fonts，获取与配置方式见 README"
    }
}

// 字重标签数组（切换器用）。
func weightLabels(): Array<String> {
    Array<String>(WEIGHTS.size) {
        i => WEIGHTS[i].label
    }
}
