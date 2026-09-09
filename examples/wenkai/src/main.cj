// 随附字体：一个字体族、多份静态字重文件，使用 fontWeight 选择。
package cui_wenkai

import cui.{ApplicationPaths, DesktopApp, FileSystem, Fonts, WindowSpec}
import std.collection.ArrayList

main(): Int64 {
    let candidates = ArrayList<String>()
    if (let Some(base) <- ApplicationPaths.basePath()) {
        candidates.add(base + "assets/fonts")
    }
    for (dir in FONT_DIR_CANDIDATES) {
        candidates.add(dir)
    }
    let dir = resolveFontsDir(candidates.toArray(), {p => FileSystem.exists(p)})
    let registered = registerWeights(dir, {path => FileSystem.exists(path)},
        {name, family => Fonts.registerFamily(name, family)})
    let model = WenkaiModel(registered)
    let app = DesktopApp(WindowSpec("CUI 本地字体样本册", 640, 640, scale: 1.0), theme: wenkaiTheme())
    app.setMinimumSize(520, 480)
    app.run {
        wenkaiView(model)
    }
    return 0
}
