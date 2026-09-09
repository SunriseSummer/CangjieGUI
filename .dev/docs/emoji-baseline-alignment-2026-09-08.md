# Emoji 混排基线修复（2026-09-08）

## 原因

editor 中 Emoji 低于同行文字，来自合并字体片段时漏算排版原点，并非需要为某一种表情固定上移几个像素。

SDL_ttf 会为超过字体 ascent 的字形预留顶部空间。以本机 Segoe UI Emoji、40.5 像素字号的 `🎉` 为例：字体 ascent 为 30，字形 maxY 为 35，原生文字簇的矩形 y 为 5。渲染表面上的基线因此是 `5 + 30`，而不是 `30`。此前整簇后备只按主字体与后备字体的 ascent 差合并片段，保留了多余的 5 像素补位，导致 Emoji 偏低。

该行为同时由本机原版 SDL_ttf 的公开布局／字形度量验证，以及 [SDL_ttf 3.2.2 的 TTF_Size_Internal 源码](https://github.com/libsdl-org/SDL_ttf/blob/release-3.2.2/src/SDL_ttf.c#L3550)确认。字体 ascent 的含义见 [TTF_GetFontAscent](https://wiki.libsdl.org/SDL3_ttf/TTF_GetFontAscent)。

## 修正

合并片段时，使用“原生簇行原点＋字体 ascent”计算实际基线，扣除片段自身的顶部补位。横向 advance、字素边界、选择／剪贴板数据保持不变；原生 Emoji 字体单独作为主字体绘制时仍保留自己的完整排版结果。

修正针对共享文字布局，适用于 Label、TextArea、TextField 及其它使用相同渲染器的控件。不同表情自身的轮廓和留白仍由字体设计决定；不会把不同形状都拉伸成同一高度，也不按中文／拉丁字符的局部图像边界逐字居中。

实现只读取已经复制到布局中的行原点，未新增字体加载、字体目录查询、位图扫描或缓存；没有修改 SDL_ttf，也没有增加 `native/`。CangjieSDL 生产改动限于 `text_engine_layout.cj` 和 `emoji_run_layout.cj`，公开 API 不变。

## 验证

修复前先添加独立回归，复现定位误差；修复后同一回归通过。原生参照直接读取 SDL_ttf 的公开簇矩形与 copy operation，不调用待测的片段合并逻辑。

- 三种正文字体：Microsoft YaHei、Segoe UI、Consolas。
- 四个原生字号：20、40.5、48、81 像素，包含分数字号及高 DPI 对应字号。
- `🎉`、`👩🏽‍💻`、VS16 心形的单行／多行混排，共 72 组，核对 Emoji 与前后普通字形的基线。
- 保留此前组合字形、范围度量、鼠标命中、连续粘贴和 30 组独立像素回归。
- 原生窗口新增 `emoji-alignment` 场景，验证 TextArea／TextField 的中英文 Emoji 混排；原有 `emoji-paste` 参照同步按原生行原点定位。

最终验收：两仓库完整构建／测试通过，严格 L2 相对本轮基线新增 0；15 个桌面场景各运行 3 轮，共 45 次全部通过，增量／完整绘制差异为 0。editor 测试及真实截图通过；GUI 开发工具 93 项测试通过；GUI／SDL 的 252／154 个 Markdown 文件检查通过。全仓格式／命名告警仍保留在完整门禁日志中，未将其描述为全部清零。

控件像素对照使用完整混排行的一次直接渲染，验证行高和内边距定位，所有像素必须一致；分别绘制多个字体片段会在分数 DPI 下各自吸附像素网格，不能作为完整行的严格逐像素参照。底层 72 组回归另与原生 SDL 数据比较基线绝对坐标，Emoji 粘贴场景仍保留独立主字体图像参照。

更新后的实际效果见 [editor 截图](../../examples/.images/editor.png)。

本次在 Windows 上验证；没有据此声称其它平台、所有字体版本或不同 Windows 控件的栅格像素完全一致。

复现命令：

```text
# CangjieSDL
cjpm test src/text --filter "*emoji*"
cjpm test

# CangjieGUI
python .dev/cli.py test desktop --repeat 3 --build-timeout 600
python .dev/cli.py test examples editor --action test --snapshot
```

本地源码快照、原生坐标、失败／通过日志及验收结果保存在 `target/dev/emoji-alignment-2026-09-08/`；桌面截图保存在 `target/dev/fixtures/desktop_lifecycle/`。此前的组合表情修复和资源测量见[整簇后备验收](emoji-cluster-fix-2026-09-08.md)。
