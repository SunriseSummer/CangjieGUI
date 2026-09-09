# 字体改进实施与验证记录

本轮同时修改 CUI 与本地上游 `../CangjieSDL`，完成斜体渲染、字体资源隔离、样式选择、继承与缩放方面的修复。原始问题与证据见[字体专项评测](font-rendering-assessment-2026-09-05.md)；使用方式见[字体配置、继承与渲染](../../docs/guide/how-to/fonts-and-typography.md)。

## 已实现

| 领域 | 处理方式与结果 |
| --- | --- |
| 斜体拉伸、重叠 | CangjieSDL 将斜体请求转为整段 Surface 栅格化与纹理绘制，复用已有坐标、裁剪、透明度及命令重放语义；未修改原生 DLL。 |
| 长文本纹理上限 | 整段 shaping 后按 GPU 尺寸上限分块上传；共享整段旋转中心，采样边缘保留邻接像素，修复超过单张纹理上限时绘制失败。 |
| 字体相互污染 | 每个字体配置独立拥有主字体与有序 fallback 图；测量会话持有租约，缓存淘汰或重新注册只退役旧配置，最后一个会话关闭后才释放。 |
| 字体选择 | 新增 FontSource／FontFamily，支持真实 Regular／Bold／Italic／BoldItalic、TTC faceIndex、显式合成策略和系统目录字体元数据发现；避免把普通字体误认作真实斜体。 |
| 恢复与诊断 | 新增实际字体面、合成样式与加载告警查询；reload 清除正负缓存，重新注册可恢复缺文件，renderer.reloadFonts 可立即释放当前渲染器的缓存文件句柄。 |
| 样式继承 | 新增 TextStyle 与 Widget.textStyle；应用默认族名、子树默认值、控件和 RichSpan 显式值依次解析，浮层保留注册时样式。 |
| 缩放与控件几何 | 段落缓存包含实际栅格比例、字体版本及继承环境；输入框、列表、表格、菜单和日期／时间选择器使用有效字体推导行高及命中几何。 |
| 富文本 | 混合字号按主字体基线对齐；相邻同视觉样式普通 span 合并 shaping，保留源片段身份与换行契约。 |
| 资源上限 | 字号统一到 1/256 像素；每个 Renderer 缓存最多 64 个字体配置、256 项／16 MiB 整段纹理，超预算单项临时绘制；度量和原生文本布局也有限额。 |

上述缓存统计按实际 GPU 块计数并包括采样边缘，不包含存活会话固定的退役字体、原生字形图集或驱动显存的完整成本；单次 CPU Surface 栅格化峰值仍随文本长度增长。字体目录发现是缓存的文件元数据扫描，并非 DirectWrite／CoreText／fontconfig 的完整匹配服务。

## API 与迁移

- 原有 `Fonts.register`、路径版 `registerFamily`、`.fontFamily()`、`.bold()`、`.italic()` 继续可用；CUI 根包重新导出新增字体类型。
- 应用默认字体使用 `Fonts.setDefault`；子树统一设置使用 `.textStyle(TextStyle(fontFamily: ..., fontSize: ..., fontStyle: ...))`。
- Label、Button、RichText 的构造参数 `fontSize` 改为 `?Length = None`，省略时继承；原有显式 Length 调用可继续编译。需要精确匹配旧构造签名的代码应同步调整。
- 自定义控件使用 `ctx.textSize/textWidth/textHeight/text/textMeasureSession`；显式 pointSize 是逻辑像素，不应重复乘 fontScale。
- `fontMetrics` 是主字体的垂直度量；`textBounds` 是具体字符串的保守栅格框，均不能当作精确 advance／ink／cluster 布局。
- 非有限或过大的原生字号会明确报错；FontSource 面号须在非负 32 位范围内。真实字体面、fallback 和样式的微小度量差异可能改变换行，属于本轮纠正后的行为。
- 替换已打开的字体文件前，先关闭相关测量会话并释放所有使用它的渲染器缓存；仍存活的会话有意保留旧文件。

## 实测对照

Windows、Cangjie 1.0.5、SDL 3.4.12、SDL_ttf 3.2.2，实际驱动 direct3d11。下表来自与原评测相同的本地探针，宽高均为逻辑像素。

| 场景 | 修复后的结果 |
| --- | --- |
| 直接使用系统族名 Georgia | 未注册族名与显式文件注册均为 294，系统默认为 313。 |
| 缺字体文件补齐后重新注册 | 从回退宽度 313 恢复为目标字体宽度 294。 |
| 原上下文切换比例 | 原上下文和新建上下文均为 257 × 28，缓存记录两次 miss。 |
| 同样式 `A`、`V` 拆 span | 整段与拆段均宽 56，修复原拆段宽 58。 |
| Button 200% 字号 | 高度由 38 增至 52，容纳 40 的文字高度和 12 的内边距。 |
| 交错使用不同 Arabic fallback | A 会话前后始终为 162；B 与新建窗口参考均为 129。 |

![修复后的斜体路径与混合字号基线](assets/font-assessment/cangjie-font-paths-after.png)

原始[修复前样张](assets/font-assessment/cangjie-font-paths.png)保持不变。第一行是普通斜体请求，第二行是零角度整段纹理路径；混合字号样例在底部按基线对齐。

## 验证

- CUI 全量 873/873、CangjieSDL 全量 157/157 通过；新增字体回归未删除或放宽原有富文本测试。
- 独立 Surface 对照覆盖 60 组：Auto／1×／2×／4× 超采样，实际比例及 1／1.25／1.5／2 倍栅格比例，斜体／粗斜体／带装饰线斜体；包含裁剪、透明度、重放及重复绘制不再栅格化，BMP 字节差异为零。
- 新增长文本用例先复现 GPU 16384×16384 上限错误，分块后通过；另有 12 组分块／整图对照覆盖 3 种比例与 4 种旋转角度，最大通道差异不超过 1。
- 文档结构检查通过：CUI 230 页、SDL 145 页；可执行文档示例分别编译通过 134 和 87 个。
- 严格 L2 与修改前基线比较，两仓库新增问题均为零。完整 cjcheck 已执行；其外部 cjlint／cjfmt 仍有告警，不代表全仓库零告警。
- 9 个示例测试及截图／增量与完整绘制对照通过，共 27 项最终结果；fonts 首轮回调语法错误已修复并单独重跑。桌面生命周期连续 2 轮、共 8 个场景通过，重绘差异为零；125%／150%／200% 字号高度断言通过。
- 分块实现完成后，再次构建 fonts／typography／richtext，并复测截图与重放，共 9/9 项通过；最终全量测试包含分块实现。

全量 SDL 测试曾两次停在现有 `windowWakeInterruptsTimedEventWait`，无逐例超时的完整 cjcheck 运行因此被终止。随后 `cjpm test --no-progress --timeout-each=30s` 全量 155/155 通过，之前单独复测该例也通过。该稳定性问题尚未定位，本轮未修改窗口事件实现或删除测试，已列入待办。

运行日志位于忽略目录 `target/dev/font-assessment/`：`gui-verified-test.log`、`sdl-verified-test.log`、两仓库 `*-final-l2.log`／`*-final-full-check.log`／`*-final-snippets.log`、`probe-after.log`。长行首次失败见 `sdl-long-before.log`，接缝对照见 `sdl-tile-pixels.log`。原始失败记录保留，不能只依据检查器进程退出码推断完整门禁成功。

## 后续边界

剩余工作已拆分到[待办](../../.todo/todo.md)：共享 cluster 布局、跨颜色／链接／高亮 shaping、完整 bidi、fallback 基线、平台字体匹配、原生图集与显存预算，以及 Linux／macOS 实机和长时性能验证。当前已覆盖 Windows 功能与像素回归，尚未建立跨平台性能基线。
