# 文本编辑、样式、Emoji 与输入法

TextField 和 TextArea 共享编辑规则。常规界面绑定 `State<String>` 即可；工具栏使用控件的公开命令，避免自行拼接文本、维护选区或复制一套撤销代码。

## 工具栏操作原选区

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("文本编辑", 720, 480))
    app.run {
        let text = rememberState<String>("body") {"组合字符 e\u{0301}，emoji 👩🏽‍💻，中文选区。"}
        let status = rememberState<String>("status") {"就绪"}
        VStack {
            let editor = TextArea(text, key: "document")
            HStack {
                Button("全选", {=> editor.selectAll()})
                Button("复制", {=>
                    status.value = if (editor.copy()) { "已复制" } else { "没有选区或剪贴板不可用" }
                })
                Button("替换", {=>
                    if (editor.replaceSelection("仓颉")) { status.value = "已替换，可撤销" }
                })
                Button("撤销", {=> editor.undo()}).enabled(editor.canUndo())
                Button("重做", {=> editor.redo()}).enabled(editor.canRedo())
            }.spacing(8.vp).hug()
            Label(status.value).muted()
        }.spacing(8.vp).padding(16.vp)
    }
}
```

按钮取得焦点后，选区仍保留并显示淡色高亮。`copy()` 返回写入是否成功；`cut()`、`paste()`、`replaceSelection()` 返回正文是否变化。空剪贴板、平台失败及 NUL 输入不会破坏原选区；`replaceSelection("")` 可删除选区。

完整可运行界面见 [editor 示例](../../../examples/editor/README.md)。

## 字节偏移与字素

公开 `cursor`、`anchor`、`selectRange` 使用 UTF-8 字节偏移，操作时吸附到扩展字素边界。排版与编辑共用 Unicode 17.0.0 规则，覆盖组合附加符、emoji 肤色／ZWJ／旗帜、韩文、Indic 连写和 CRLF。[规则来源：UAX #29](https://www.unicode.org/reports/tr29/tr29-47.html)。

两端相同表示普通光标。`selectRange(anchor, cursor)` 保留方向；越界钳制，字素内部向前吸附。Backspace 和 Delete 均删除完整字素，这是一致的平台策略，不逐个剥离组合附加符。

直接持有 `TextEditState` 时，垂直移动按字素列计数；TextArea 按实际字体的水平像素位置导航，经过短行后仍记住原列。按词操作使用字母／数字／下划线、空白、符号分组，不等同于中文／泰文词典分词。

## 键盘与只读

| 操作 | 按键或手势 |
| --- | --- |
| 选择 | 拖拽、Shift 点击、Shift + 导航键；双击选词段，三击选整行 |
| 全选／复制／剪切／粘贴 | Ctrl/⌘ + A/C/X/V |
| 撤销／重做 | Ctrl/⌘ + Z、Ctrl/⌘ + Shift + Z 或 Y |
| 按词移动／删除 | Ctrl + 左右键／Backspace／Delete；macOS 也支持 Option |
| 行首／行尾 | Home／End |
| 文档首／尾 | TextArea 中 Ctrl/⌘ + Home／End |

`editable: false` 允许选择、复制及键盘导航，不参加 Tab 遍历、不自动抢焦点；剪切、粘贴、替换和撤销／重做均不修改正文。TextArea 默认提供文本值、聚焦和可编辑时的 SetValue 语义。

只读约束属于控件；应用代码仍可以直接替换绑定值，例如切换文档。

长行会横向跟随光标，文字、选区、光标和点击命中使用同一偏移。TextArea 默认按硬行移动；调用 `.wrap()` 后按可视行移动，Home／End 和 PageUp／PageDown 也使用同一套可视行。换行不会修改文档。

## 文本更新与撤销边界

普通连续输入在 500 ms 内合并；选区替换开始新组，剪切、粘贴、应用 `replaceSelection` 和 IME 提交各自独立。IME 预编辑不写入正文，提交前的退格／导航不删除已提交文本，未聚焦控件也不会清除其它控件的预编辑状态。

历史按两个栈合计限制为 300 步、约 8 MiB 快照预算；超额淘汰最旧快照。该预算包含快照文本与条目估算开销，不是整个进程的内存上限；当前正文、字素索引等仍占用内存。

应用直接修改绑定文本被视为外部替换，会在下次编辑命令中清除旧历史，避免撤销重新载入上一份文档。需要可撤销的应用编辑请使用 `replaceSelection`。加载文件后，通过 `selectRange(newText.size, newText.size)` 或同时设置外部 `cursor`／`anchor` 折叠选区。

TextField 的输入、粘贴和编辑命令将 CRLF、CR、LF 变为一个空格；TextArea 统一为 LF。应用直接绑定给 TextField 的值应保持单行。控件拒绝纯文本编辑命令中的 NUL，上游系统剪贴板写入也会在调用 SDL 前拒绝 NUL，避免截断后误剪切。

## 宿主与验证边界

通过 [`TextClipboard`](../../api/cui/text/TextClipboard.md) 注入读写函数，可在不改动系统剪贴板的情况下测试成功、失败和重入路径。默认后端使用 SDL 系统剪贴板；系统剪贴板与 IME 行为须在目标平台验收。

拖选超过内视口后，即使指针静止也会持续滚动并扩展选区；TextField 支持横向，TextArea 支持纵向及未换行时的横向。速度随越界距离增加并有上限；松开、失焦或到达边界后停止调度，只读控件也支持此操作。

当前尚不提供完整双向文本编辑、默认右键编辑菜单和可见水平滚动条；需要菜单时使用[编辑与菜单组合](text-editing-and-menus.md)。

## 行高、样式与软换行

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("文本与 Emoji", 720, 480))
    app.run {
        let draft = rememberState<String>("draft") {"中文与 Emoji 🎉 👩🏽‍💻 可以直接输入。"}
        let title = rememberState<String>("title") {""}
        let status = rememberState<String>("status") {"就绪"}
        VStack {
            TextField(title, key: "title")
                .placeholder("输入标题，Enter 提交")
                .style(TextInputStyle(lineHeight: 30.fp, padding: LengthInsets(12.vp)))
                .onSubmit({text => status.value = "已提交：${text}"})
            TextArea(draft, key: "body").wrap()
                .placeholder("开始输入正文 🎉")
                .style(TextInputStyle(lineHeight: 34.fp, padding: LengthInsets(14.vp),
                    selectionColor: Color.rgb(55, 85, 165), selectedTextColor: Color.rgb(255, 255, 255),
                    selectionWidth: TextSelectionWidth.Content, cursorHeight: 24.fp,
                    cursorBlinkIntervalMs: UInt64(530)))
            Label(status.value).muted()
        }.spacing(10.vp).padding(16.vp).textStyle(TextStyle(fontSize: 18.fp))
    }
}
```

`lineHeight` 是包含留白的最小行高，不是额外行距；小于字体自然高度时自动提高，避免大字号重叠。显式行高将文字置于行框中；光标按参考墨迹中心对齐，选区覆盖完整行高。`fp` 跟随字体缩放，`vp` 固定逻辑长度。内边距也用于点击和滚动几何；强制固定高度小于自然测量时内容会裁剪，应让 TextField 按内容测量。

`TextInputStyle.alignment` 支持每行前端、居中和末端对齐。可分别设置正文、占位提示、聚焦／失焦选区、选中文字、光标颜色，以及普通／聚焦 `SurfaceStyle`；未设置的值使用主题。占位文字只提供视觉提示，不是控件值，也不能代替无障碍标签。

## 选区、光标与空闲刷新

默认选区只覆盖被选中的内容宽度，不填充硬换行后不存在文字的行尾空白；实际空格仍计入宽度，空行或单独选中的换行符保留窄条。需要行尾铺满效果时设置 `selectionWidth: TextSelectionWidth.Viewport`。

光标高度与行高独立：`cursorHeight: 24.fp` 可以限制光标高度，未设置时使用自然行高；光标围绕当前字体的稳定参考墨迹中心对称放置，不随单个字符上下跳动。`cursorBlinkIntervalMs: UInt64(0)` 使光标常亮。非空正文选区不显示插入光标，IME 预编辑保持常亮，失焦或被裁剪的光标不请求闪烁帧。

DesktopApp 在只有光标到期、没有输入或状态变化、其他定时器、帧订阅或浮层时，复用已有组件树与布局。在支持保留场景目标的后端上，只重绘光标周围区域并复用文本几何；不增加光标专用纹理或读回缓存。后端无法保留场景目标时安全退回完整绘制。最终窗口合成与呈现仍由 SDL／驱动完成，不表示每次闪烁完全没有 GPU 工作。

## Emoji 与字体后备

无需为普通输入框显式配置 Emoji 字体。首次遇到 Emoji 候选字符时，CangjieSDL 定向查询 Windows 的 Segoe UI Emoji、Linux 的 Noto Color Emoji 等，或 macOS 的 Apple Color Emoji，将其加入缺字后备链；普通文字不触发此查询，更不会全量扫描系统字体。选择结果、字体配置和查询文本都有容量限制；`Fonts.reload()` 后重新按需查找。

按完整 Emoji 字素选择能够处理该序列的字体，应用主字体及显式后备优先，系统 Emoji 最后补缺。显式 VS16 请求 Emoji 外观时，优先尝试可用的彩色字体；VS15 不触发这项替换。彩色字形保留字体调色板，正文颜色和选中文字颜色只改变单色字形；透明度仍对整段生效。自动 Emoji 后备不继承合成粗体、斜体和变量轴。

可以通过 `fontFamily: FontRole.emoji`（字符串 `"emoji"`）显式选择平台 Emoji 角色，或用 `FontFamily(..., fallbacks: [...])` 提供自己随应用分发的字体。`👩🏽‍💻` 是 15 个 UTF-8 字节、4 个码点组成的一个字素，应显示为一个程序员，并整体选择、复制和删除；`👩🏽 💻` 则是两个独立表情加一个空格。连续粘贴不会拆分或改写序列。

后备、编辑和换行共用 CangjieSDL 的 Unicode 17 字素规则。相邻同字体片段合并整形，测量、光标和绘制使用同一片段结果，避免逐个表情累加宽度的舍入误差。**完整编辑不等于字体支持所有图形**：旗帜和最新序列仍受实际字体覆盖及组合能力限制；没有合适字体时不能凭空生成合字。需要固定视觉结果的产品应提供并验收指定字体。

Emoji 与同行文字按实际排版基线对齐，包括原生字体为较高字形预留的顶部空间；应用无需额外设置 Emoji 的垂直偏移。不同表情的轮廓留白仍取决于字体设计。

普通文本不会提前加载 Emoji 字体；首次输入 Emoji 才承担该字体的原生加载成本。同一 Renderer 内同实际字号的自动 Emoji 后备共享，重复输入复用布局／字形和校准结果。保持少量常用字号、避免每次输入都注册字体或清缓存。资源约束见[字体与排版](fonts-and-typography.md)。

## 输入法预编辑

预编辑在视觉上替换当前选区，并将后方正文向后排，不写入绑定文本。原生预编辑选区的码点位置转换成 UTF-8 字节位置，用于内部高亮、光标和候选窗口锚点；提交一次形成独立撤销步骤。只读编辑框允许选择和复制，但不会发布输入法锚点或保留预编辑。

注入预编辑／提交事件的测试可验证控件处理逻辑；实际候选窗、系统快捷键和输入法切换仍须在目标系统验证。
