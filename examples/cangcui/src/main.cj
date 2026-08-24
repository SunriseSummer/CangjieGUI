/*
 * 苍翠画卷入口：约 3:1 的横卷窗口（1200 × 400 逻辑尺寸）。
 */
package cui_cangcui

import cui.{DesktopApp, Fonts, WindowSpec}

// 题字与印文所用的系统安装字体（个人字体目录的霞鹜文楷）；文件缺失时自动回退平台 UI 字体，
// 画面结构不受影响。
let WENKAI = "wenkai"
let WENKAI_PATH = "<path/to>/LXGWWenKai-Regular.ttf"

main(): Unit {
    Fonts.register(WENKAI, WENKAI_PATH)
    let app = DesktopApp(WindowSpec("苍翠 · 千里江山", 1200, 400, scale: 1.0), theme: cangcuiTheme())
    app.run {
        cangcuiView()
    }
}
