# 文本编辑器交互与空闲渲染加固（2026-09-08）

本轮针对多行选区拖尾、光标上下不对称和空闲刷新问题，覆盖 TextArea、TextField、DesktopApp 及 CangjieSDL 的裁剪换算。保留现有字素编辑、Emoji 整簇后备、撤销和输入法预编辑机制。

## 设计依据

- Qt 将光标重绘请求限制在光标矩形附近；参见 [QWidgetTextControl 源码](https://github.com/qt/qtbase/blob/dev/src/widgets/widgets/qwidgettextcontrol.cpp) 的 `repaintCursor` 与闪烁定时处理。
- Flutter 提供独立的 [selectionWidthStyle](https://api.flutter.dev/flutter/widgets/EditableText/selectionWidthStyle.html) 和 [cursorHeight](https://api.flutter.dev/flutter/widgets/EditableText/cursorHeight.html)，其 [RenderEditable](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/rendering/editable.dart) 将光标等辅助绘制分开失效。不同框架的行尾高亮策略可以配置，不应将铺满行尾当作唯一正确行为。
- SDL 的 [裁剪 API](https://wiki.libsdl.org/SDL3/SDL_SetRenderClipRect) 使用整数矩形，[绘制缩放](https://wiki.libsdl.org/SDL3/SDL_SetRenderScale) 会改变其物理覆盖范围。CangjieSDL 的文字绘制会临时回到物理像素比例，必须保留同一裁剪区域。

## 根因与修改

| 问题 | 根因 | 本轮处理 |
| --- | --- | --- |
| 多行选区铺满尾部空白 | 选中硬换行后直接使用 `viewport.right()` 作为该行终点 | 默认按内容 advance 绘制，真实尾随空格仍计入；仅选中的换行／空行以窄条标示。通过 `TextSelectionWidth.Viewport` 可选旧行为。 |
| 光标上下不对称 | 自然字体行框包含不对称留白，原光标直接沿行框顶部放置 | 用当前字体稳定参考字形 `国Ag` 的墨迹中心放置光标。新增独立 `cursorHeight`，不会随旁边单个字符跳动，也不会填满宽松行距。 |
| 空闲仍持续刷新 | TextArea 每次绘制都将 `revealPending` 写成 `false`，默认 State 的等值赋值仍会失效；原光标周期也由可观察 State 记录 | 仅在需要时清除状态；光标计时使用普通保留对象。一次性自动聚焦完成后不再保留帧订阅。 |
| 闪烁重做全帧布局 | 所有定时器共用正常帧事务 | 区分光标期限与一般期限。仅光标到期、无输入／状态／字体修订变化、其他定时器、帧订阅、拖拽和浮层时，复用稳定组件树，跳过构建、布局、帧回调和语义重建。 |
| 局部绘制残留一列像素 | 普通图形先取整逻辑裁剪，文字先缩放原分数裁剪；嵌套裁剪改变原点后还可能向外多覆盖一个物理像素 | CangjieSDL 在文字比例切换时遵循 SDL 的裁剪换算；损伤边缘同时对齐逻辑整数和物理像素，无法在有界范围内对齐时回退整帧。CUI 使用后端实际范围重绘。 |
| 指针静止后拖选停止滚动 | 只在 MouseMove 到达时扩展选择 | 越界拖选期间按 32 ms 请求一般帧，速度随距离增加、最高 900 vp/s，单次累计时间最多 64 ms。松开、失焦或到达边界停止；只读控件同样支持。 |

## 资源与行为边界

空闲光标帧复用已绘制编辑器的几何和可见行墨迹范围，只绘制与光标损伤范围相交的行。没有新增光标纹理、窗口读回或整篇文档快照；新增缓存随当前可见行数量增长，正常刷新后被替换。

非空正文选区隐藏插入光标；IME 预编辑常亮；窗口失焦和光标完全离开裁剪区时不安排闪烁。`cursorBlinkIntervalMs` 默认每个阶段 530 ms，设为 `0` 即常亮。输入法候选锚点不依赖光标当前是否亮起。

局部绘制依赖可保留的场景目标。后端无此能力时退回完整绘制；窗口最终的超采样解析、合成和 present 仍由 SDL／驱动完成。本轮不声称每次闪烁完全没有 GPU 工作，也不新增大型缓存换取优化。

## 验证

新增回归覆盖内容宽度选区、尾随空格、CRLF、空行、可选视口高亮、光标尺寸非法值与缩放、稳定绘制无状态写入、选区／预编辑／离屏停止闪烁、期限竞争、静止拖选与只读／失焦／边界停止。真实窗口 `editor-quality` 对比 1×／2× 超采样的选区像素与原生光标几何，并对正文、空文档提示文字验证光标局部帧与完整参考帧一致。

Windows 验收结果：

- CangjieGUI **965/965**、CangjieSDL **239/239**，无跳过或失败。
- 两库完整构建／测试门禁通过；L2 基线均无新增条目，保留原有 GUI 25 项、SDL 13 项 INFO。仓库级 cjlint／cjfmt 风格告警仍存在，本轮没有将其声明为整体清零。
- **16 个真实桌面场景 × 3 轮 = 48 次通过**；覆盖字体布局、编辑、Emoji 粘贴／对齐、滚动、启动、生命周期和失败恢复。
- `editor-quality` 的选区、普通正文和空文本提示，对照完整参考帧要求 **0 个差异像素**，未放宽色差或位置容差。测试曾分别捕捉 10 个缺失像素、7 个重复叠色像素，随后补齐整数／物理边缘对齐。
- 默认 530 ms 周期的光标局部帧：**构建 0、布局 0、文字度量 0、度量计算 0、整形 0、文字绘制 1 行**。仍会遍历必要的绘制节点并完成窗口合成／呈现，不等于整个渲染器停止工作。
- 文档检查通过；GUI **140 段文档示例编译通过**，开发工具 **93 项测试通过**；editor 构建、运行快照与人工图像检查通过，已更新示例截图。
- SDL3_ttf DLL SHA-256 仍为 `9A3DEFA81CFB71A48256333F1A015EE72A9B7D82311891CDC87AFCB9F23EC5A9`，`native/` 不存在；全部修改为仓颉代码。

完整命令、日志、逐像素图片与源文件哈希位于本机 `target/dev/editor-quality-2026-09-08/`；桌面回归报告为 `target/dev/test-package-results/desktop-lifecycle.json`。

## 后续范围

完整段落 bidi 与共享 shaping 命中几何、水平滚动条、原生文本范围无障碍、系统右键编辑菜单、大文档增量编辑以及 Linux／macOS 实机矩阵仍在 [todo](../../.todo/todo.md)。本轮的 Windows 自动化不代表所有平台输入法和字体版本均已验收。

API 与示例参见 [TextInputStyle](../../docs/api/cui/text/TextInputStyle.md)、[文本编辑指南](../../docs/guide/how-to/text-editing.md) 和 [editor](../../examples/editor/README.md)。
