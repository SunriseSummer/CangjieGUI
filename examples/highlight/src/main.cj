/*
 * CUI 示例：搜索高亮。
 *
 * 演示 `RichSpan.highlight`（<mark> 式逐段背景）：在搜索框输入或点预设标签，命中的关键词在知识卡片正文里
 * 就地高亮——不过滤、不跳转。综合演示富文本逐段高亮 + TextField 实时输入 + 纯匹配逻辑的切分。
 */
package cui_highlight

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = SearchModel()
    let app = DesktopApp(WindowSpec("CUI 搜索高亮", 640, 600, scale: 1.0), theme: highlightTheme())
    app.setMinimumSize(520, 480)
    app.run {
        highlightView(model)
    }
    return 0
}
