[CUI 指南](../index.md) › 字体与排版

# 配置字体、样式与排版

本页讲字体选择与样式继承。编辑、选区和输入法见[文本编辑](text-editing.md)；底层字体解析、测量与资源边界见 [CangjieSDL 字体指南](../../../../CangjieSDL/docs/guide/how-to/text-and-fonts.md)。

## 从应用默认到局部覆盖

字体族按控件／富文本片段的显式设置、子树 `TextStyle`、`Fonts.setDefault`、平台 UI 字体依次选择。未知名称和无法打开的字体文件会进入后备流程；最终结果用 `Renderer.resolveFont` 查询。

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    Fonts.setDefault(FontRole.systemUI)
    let app = DesktopApp(WindowSpec("字体与样式", 640, 420))
    app.run {
        let text = rememberState<String>("text") {"AV office 仓颉"}
        VStack(spacing: 12.vp) {
            Label("字体与输入").bold().fontSize(26.fp)
            TextField(text)
            Label("继承半粗体与斜体")
            Label("只取消斜体").italic(value: false)
            RichText([RichSpan.text("正文 "), RichSpan.text("强调").bold()])
        }.textStyle(TextStyle(fontSize: 18.fp, fontWeight: FontWeight.semiBold, italic: true))
            .padding(24.vp)
    }
}
```

字号、字重、倾斜和装饰独立继承。`.fontWeight(...)` 只覆盖字重，`.italic(value: false)` 只取消倾斜；`.fontStyle(FontStyle.regular)` 替换整组字体样式。`TextStyle` 同时包含 `fontStyle` 与独立字段时，先应用整组样式，再应用独立字段。

使用 `fp` 让字号随用户字体缩放。输入框、按钮和数据行会依据有效字体度量计算自然高度；避免用过小的固定高度裁切文字。内容型行可用 `.hug()`，把剩余空间留给编辑区或画布。

## 选择系统字体

| 目标 | 接口 |
|---|---|
| 使用系统 UI、无衬线、衬线、等宽或 Emoji 字体角色 | `FontRole.systemUI`、`sansSerif`、`serif`、`monospace`、`emoji` |
| 选择指定族名 | `.fontFamily("Cascadia Code")` |
| 查询一个族的字体面与设计轴 | `Fonts.familyFaces(name)` |
| 构建完整字体选择器 | `Fonts.systemFamilyNames()`、`Fonts.systemFonts()` |
| 增加应用字体目录 | `Fonts.setSearchDirectories(...)` |
| 安装字体后刷新 | `Fonts.refreshSystemFonts()` |

普通族名和角色查询采用定向匹配；完整目录由显式枚举加载。字体选择器应在明确的加载动作中查询目录，避免在每次构建中扫描。系统角色分别使用 Windows 字体设置与 DirectWrite、Linux fontconfig、macOS CoreText；实际覆盖由目标系统字体决定。

## 随应用分发字体

将字体文件放入应用资产目录，并在首次绘制前注册。下面只展示注册过程；路径应替换为实际随应用交付的文件。

```cangjie verify role=complete
package docexample

import cui.*

main(): Unit {
    Fonts.registerFamily("Body", FontFamily(
        FontSource("assets/Body-Regular.ttf"),
        bold: FontSource("assets/Body-Bold.ttf"),
        italic: FontSource("assets/Body-Italic.ttf"),
        boldItalic: FontSource("assets/Body-BoldItalic.ttf"),
        fallbacks: [FontSource("assets/CJK.ttc", faceIndex: 1)]))
    Fonts.setDefault("Body")
}
```

注册本身不读文件，成功返回不能证明字体存在或可加载。`faceIndex` 指定集合中的字体面；真实粗体／斜体面优先，没有合适字体面时按策略合成。额外静态字重可通过 `FontFamily.faces` 和 `FontFaceDefinition` 注册。需要统一的缺字链与随附保底字体时使用 `Fonts.setFallbacks`。

## 数值字重与变量字体

`FontWeight` 接受 1～1000；`normal` 为 400，`medium` 为 500，`semiBold` 为 600，`bold` 为 700。`.bold()` 请求 700，`.bold(value: false)` 请求 400。静态字体没有精确字重时选择近似面，解析诊断会报告实际结果。

变量字体只能使用文件实际提供的设计轴。先通过 `Fonts.familyFaces` 查询轴范围，再设置 `FontVariations`；常见标签包括 `wght`、`wdth`、`ital`、`slnt` 和 `opsz`。框架不自动按字号调整 `opsz`。

- 普通 `fontWeight` 超出变量字体范围时钳制并报告诊断。
- 显式重复轴、非有限坐标，以及解析时不存在或越界的轴会报错。
- 显式 `variations` 中的 `wght` 优先；之后调用 `fontWeight`／`bold` 会清除先前显式 `wght`。
- `FontSource.instanceIndex` 或源级 `variations` 固定字体实例，不被普通字重请求重置。需要动态字重时注册基础字体文件。

实例编号须来自该字体的枚举结果；不能把另一字体的实例编号当作通用 Bold 编号。变量字体接口见 [FontVariations](../../../../CangjieSDL/docs/api/sdl/FontVariations.md) 和 [FontSource](../../../../CangjieSDL/docs/api/sdl/FontSource.md)。

## 自定义组件与富文本

自定义 Widget 使用 `ctx.textSize`、`textWidth`、`textHeight`、`text` 和 `textMeasureSession`，使度量、绘制与继承样式一致。显式 `pointSize` 已是逻辑像素，不要再次乘字体缩放。直接调用 Renderer 不会自动应用 CUI 的全部字体环境。

`RichText` 按基线对齐不同字号，合并相邻同视觉样式的普通文本。硬换行保留连续和末尾空行，CRLF 跨片段也只换一行；布局与链接命中共享结果。跨颜色、链接或高亮边界的整形与完整段落双向排版仍有局限，不能把它当作完整排版引擎。

普通输入框无需显式添加 Emoji 字体；框架按需使用平台后备。字素完整性与字体覆盖是两回事，最新表情或旗帜仍可能缺字。固定视觉效果需要随应用提供并验收字体。

## 诊断与更新

`renderer.resolveFont(...)` 返回实际字体面、字重、合成样式和警告；`fontCacheStats()` 反映缓存配置与资源成本。少量稳定字号和字重便于复用，连续改变设计轴仍会生成新轮廓。

缺失文件补齐后，重新注册或调用 `Fonts.reload()` 允许重试。替换正在使用的字体文件前，先关闭测量会话，再用 `renderer.reloadFonts()` 释放缓存，替换文件后调用 `Fonts.reload()`。仍存活的测量会话固定旧字体图与比例，必须在 Renderer 所属线程使用和关闭。

持久元数据缓存通过 `Fonts.setMetadataCache(path)` 显式启用，应用负责准备父目录；文件变化会使记录失效，必要时用 `refreshSystemFonts(force: true)` 重建。缓存预算及诊断含义统一见 [SDL 字体缓存](../../../../CangjieSDL/docs/guide/concepts/text-font-cache.md)。

按 [typography → fonts → wenkai → richtext](../../../examples/README.md#字体学习路线) 运行示例，再在目标平台检查中文、拉丁字母、粗斜体、Emoji、字体放大及缺失文件回退。
