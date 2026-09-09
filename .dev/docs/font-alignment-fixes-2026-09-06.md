# 字体示例反馈修复 · 2026-09-06

> 历史记录：本文保留当时的实现及测量结果。2026-09-07 后续字体迁移已改用官方 SDL_ttf 和仓颉实现，原生扩展及其构建要求已移除；当前使用契约见[字体指南](../../docs/guide/how-to/fonts-and-typography.md)。

针对 examples/fonts 截图中的混排错位、按钮偏下、大字号溢出、文字贴边和字体下拉列表不完整，完成以下修复。

| 问题 | 根因 | 修改 |
| --- | --- | --- |
| 拉丁／汉字／全角标点上下错位 | SDL_ttf 3.2.2 按每个 fallback 字体自己的 ascent 定位字形 | 原生源码补丁让横向文字共用主字体基线，包含默认自动方向；保留原有 shaping 和字形位置缓存 |
| “保存”等按钮视觉偏下 | 整个字体行框的上下留白不对称，按行框居中不等于按文字居中 | 新增 Renderer.textInkBounds，textCenter 改按字形位图和装饰线边界居中；较旧原生库退回保守行框 |
| 字号增大后输入／按钮被压缩 | 预览 VStack 与诊断画布同时参加剩余高度分配，输入 HStack 再被压缩 | 内容型预览和输入行使用 hug()；按钮在被外部强制压小时也不会画出自身边界 |
| 诊断文字贴背景边缘 | Canvas 使用 rect 原点绘字，行尾也缺少内边距 | 两页诊断区增加 10 vp 内边距、匹配内容的高度与内部裁剪；角色页去除输入行固定高度 |
| 下拉框看不到全部字体 | 已传入全部 222 个族名，但当前值被直接作为过滤条件 | ComboBox 展开时浏览完整选项，高亮并滚动到当前值；选中原文本便于直接替换查询，编辑后才过滤 |

复查时也修正了 `wenkai` 的同类留白问题：内容卡片使用 `hug()`，底部字体诊断条增加独立内边距。

字形基线对齐和按钮视觉居中分别处理：混排保留字体自身的形状、字面大小和相对基线；独立按钮标题则按可见字形范围居中。输入框继续采用稳定行度量，使文字、光标和选区共用同一坐标体系。

## 原生扩展与 API

CangjieSDL 的 `native/fonts/build.py` 对固定 SDL_ttf 3.2.2 源码施加有上下文校验的基线补丁；新增 ABI 1 可选导出 `CSDL_GetTextInkBounds`。117 个原有 TTF 导出保留，CSDL 导出由 6 个增至 7 个。字体边界共享既有度量缓存，条目预算同步计入新增字段。

`textInkBounds` 返回相对 text 原点的字形位图／装饰线矩形，排除行框留白；位图边缘可能保留透明／抗锯齿余量，本轮验证单边至多 1 像素。它不提供字符推进或 cluster 布局。API、ComboBox 交互文档和 [fonts 教学说明](../../examples/fonts/README.md)已更新，增加 `--demo large` 复现入口。

配套 Windows DLL SHA-256：`0b4d74ff25dad6bc50db09ce39624a897f51a16b8b1bf5492326f98d84f822d8`。`.sdl3/SDL3_ttf.dll` 和 `.sdl3/libSDL3_ttf.dll` 来自同一构建；运行新示例时需要重新构建并重新启动进程。

## 验证

- 修改前 CUI 876 项通过；SDL 170 项中 169 项通过，已有 `windowWakeInterruptsTimedEventWait` 触发 60 秒逐例超时，失败证据保留。它与本轮字体修改无关。
- 独立原生验证使用 fallback 字形图像及 bearing 推导共同基线：修复前 12 组全部出现下移，40 fp 时约 5 像素；修复后 Cascadia Code、其 Italic 文件和 Consolas 共 36 组基线对照通过。
- 同三种字体共 48 组字形边界／Surface 像素对照通过；矩形包围实际像素，单边余量至多 1 像素。
- ComboBox 8 项测试通过，包含新增的“已有值展开仍可选择其它族”和“展开后输入替换并过滤”。fonts 新增 12／24／40／20 fp 与 1／1.5 倍字体缩放下的输入行自然高度回归，4 项示例测试通过。
- 真实 40 fp 冷启动与从小字号动态切到 40 fp 的快照逐像素一致；已检查正常体、斜体、字体角色页和完整下拉框窗口画面。参见 [40 fp 修复效果](assets/fonts-large-fixed.png)、[全部字体展开效果](assets/fonts-browse-fixed.png)。
- fonts／typography／wenkai／richtext 共 20 项示例测试通过，四次测试与四次截图共 8 道检查通过，示例索引配图同步更新。
- `wenkai` 追加留白调整后，单独重跑 5 项测试与截图，两道检查通过，并核对更新后的样张和诊断条。
- 两库严格 L2 基线均新增 0；CUI 保持 26 INFO、SDL 保持 14 INFO，均 0 ERROR／WARN，未扩大检查豁免。
- 最终两库 `--full --strict` 均通过构建与全量测试，CUI 878 项、SDL 171 项；全量模式另报告既有 cjlint／cjfmt 风格警告（CUI 1903、SDL 1286），不是零警告验收。CUI 串行复验用时 687.8 秒，SDL 为 147.2 秒。
- 文档覆盖检查通过（CUI 232 份、SDL 151 份），221 个文档程序实际编译通过（CUI 135、SDL 86）。
- 桌面真实窗口的 retained-damage／automatic-partial／automatic-fallback／lifecycle／font-layout 五个场景全部通过，增量与全量重绘逐像素差异为 0。
- 早期 CUI 全量检查在并行构建负载下触及 420 秒总时限，失败记录保留，之后单独运行通过。

截图与日志保存在本机 `target/dev/font-alignment/`；原生验证脚本 `native/fonts/validate_alignment.py` 已纳入源码，可用 `--ttf` 指向旧 DLL 复现。Linux/macOS 本轮未实机验证，跨样式 shaping、精确 cluster 几何与平台缺字服务仍按原待办推进。
