# 字体机制演进与验收记录 · 2026-09-06

> 历史记录：本文保留当时的实现及测量结果。2026-09-07 后续字体迁移已改用官方 SDL_ttf 和仓颉实现，原生扩展及其构建要求已移除；当前使用契约见[字体指南](../../docs/guide/how-to/fonts-and-typography.md)。

本轮在[第一轮字体修复](font-improvements-2026-09-05.md)基础上，按默认字体引导、目录元数据、数值字重、变量实例／设计轴、平台发现与缓存的顺序实施，同时完善四个教学示例。改动覆盖 CUI 和相邻 CangjieSDL，保留已有布尔样式与单文件注册接口。

## 已实现

| 范围 | 结果 |
| --- | --- |
| 默认字体 | 可用应用默认文件优先引导，不依赖固定系统路径；提供平台 UI、目录与随附字体后备；完全无可用字体时明确报错 |
| 数值字重 | FontWeight 1～1000；静态面按倾斜、字宽与 CSS 字重搜索顺序选择，bold 兼容映射为 700 |
| 多文件字体族 | FontFaceDefinition 声明静态字重／倾斜／字宽，多份文件共享一个 FontFamily |
| 样式继承 | TextStyle、Label、RichSpan 按字段继承；fontStyle 保留整组替换语义；Button 的字体族同时参与测量与绘制 |
| 可变字体 | 枚举命名实例、区分 TTC 集合面与实例号；不可变 FontVariations 支持规范化轴坐标，先验证再设置；真实变量字重／斜体不重复合成 |
| 系统发现 | Windows 消息字体设置＋DirectWrite、Linux fontconfig、macOS CoreText；提供 UI／sans-serif／serif／monospace 角色、别名、附加目录与文件去重 |
| 缓存与诊断 | 字体、布局、纹理键含数值字重及规范化轴坐标；报告请求与实际字重、合成和后备原因；可选持久元数据缓存按文件大小／修改时间失效，支持强制重建 |
| 原生交付 | SDL_ttf 3.2.2 扩展 ABI 1，固定源码版本、摘要及依赖提交，提供下载校验、构建与 Windows ABI 验收脚本 |

在示例视觉验收中另发现帧前布局使用 1 倍度量、绘制使用实际 DPI／超采样比例的问题：`Title · 20fp` 与正文被分配的宽度比绘制宽度少约 0.78／2.89 逻辑像素，导致本应完整显示的 Label 出现省略号。新增 `Renderer.prepareTextLayout`，DesktopApp 在布局前自动准备本帧栅格比例，并提前确定目标分配失败时的直接绘制后备；不通过放宽省略规则掩盖度量差异。

## 示例与最佳实践

| 示例 | 展示与教学内容 |
| --- | --- |
| [typography](../../examples/typography/README.md) | 样式开关、字号阶梯、独立继承与显式整组重置 |
| [fonts](../../examples/fonts/README.md) | 本机族名选择、字重／字号／斜体、Label／输入框／按钮共享设置、变量轴、实际解析诊断及平台角色 |
| [wenkai](../../examples/wenkai/README.md) | 可执行文件旁资源定位、一个 FontFamily 关联三份静态字重、缺文件降级及 CJK 对照 |
| [richtext](../../examples/richtext/README.md) | 字号混排按基线对齐、主题词数值字重、等宽代码、局部样式与链接命中 |

已更新四份 README、示例总索引、学习路线和实际窗口截图。fonts 另提供 `--demo italic/roles/width/optical` 可复现预设；轴预设根据本机字体能力选择，没有相应轴时保留默认展示。

普通应用推荐：启动时确定默认／随附字体；用 TextStyle 设置子树，局部仅覆盖需要改变的字段；字重使用 fontWeight；仅对已查询到的轴与范围使用 fontVariations；通过 resolveFont 确认实际结果。完整接口与示例代码见[字体指南](../../docs/guide/how-to/fonts-and-typography.md)。

## 验证结果

测试主机为 Windows x64，仓颉 1.0.5，SDL 3.4.12，扩展 SDL_ttf 3.2.2。以下基线指第一轮修复完成、本轮演进开始时的状态。

| 验证 | 结果 |
| --- | --- |
| CangjieSDL 构建／全量测试 | 通过；测试由 157 增至 170 |
| CUI 构建／全量测试 | 通过；测试由 873 增至 876 |
| 严格 L2 新增问题门禁 | 两库均新增 0；CUI 保持 26 INFO，SDL 保持 14 INFO，均 0 ERROR／WARN |
| 全量 cjcheck | 两库构建和测试均通过；仍报告仓库整体的 cjlint／格式风格告警，CUI 1902、SDL 1282，不能视为零告警验收 |
| 原生 ABI | 117 个原有 TTF 导出全部保留，新增 6 个 CSDL 导出；链接／运行 DLL 别名一致；无额外 MSVCP／VCRUNTIME DLL 依赖 |
| 变量字重 | Cascadia Code 200／350／400／600／625／700，正体和斜体，含真实实例、连续插值、越界拒绝、缓存淘汰与存活会话 |
| 独立轮廓参考 | 36 组字体／字号／样式对照，推进宽度一致；通道误差不超过 16/255、总误差不超过参考墨迹的 0.5% |
| 既有栅格回归 | 60 组严格 Surface 像素对照、12 组分块接缝及超过 16384 像素长行继续通过 |
| 其它设计轴 | Bahnschrift 的 wdth、Segoe UI Variable 的 opsz，验证坐标、宽度变化、缓存顺序规范化与会话稳定性 |
| 引导／发现／缓存 | 可用应用默认先于系统发现、无字体错误、角色与别名、目录刷新、固定实例、持久缓存命中／文件变化／损坏恢复 |
| 帧前字体度量 | 72 组字号／样式／比例／采样配置，测量与绘制的比例、宽度和行高一致；会话在 endScene 后仍稳定 |
| 桌面 E2E | 5 个独立场景通过，含新增 font-layout；增量／整帧重绘像素差为 0 |
| 教学示例 | 四项目共 19 个测试通过；4 张默认窗口快照和 4 个 fonts 预设均成功，已逐张检查画面 |
| 文档完整示例 | CUI 135、CangjieSDL 86 个程序编译通过 |
| 开发工具测试 | 90 项通过 |

fontTools 静态实例化会取整 TrueType 设计点，而 FreeType 变量路径保留小数，因此变量轮廓参考采用上述抗锯齿误差界限；不能把它称为逐字节像素一致。原有 60 组严格像素测试保持独立，未放宽。

构建与测试日志、基线、像素参考及原生验证 JSON 保存在本机 `target/dev/font-evolution/`；例行快照报告在 `target/dev/examples/snapshot-report.json`，桌面场景报告在 `target/dev/test-package-results/desktop-lifecycle.json`。这些本机证据和生成字体不随源码分发。

配套 Windows SDL3_ttf.dll SHA-256：`3e1e65ed12993c881f849ad1b1272650383d1d52c817d457bbf979111bab5cc4`。CangjieSDL 的 `native/fonts/sources.json`、`prepare.py`、`build.py`、`validate.py` 保存可复现输入与验收流程；发布时两份 DLL 别名必须来自同一构建。

## 兼容约束与后续工作

- Linux/macOS 平台分支已实现，尚未在对应平台构建和实机验收；不能将本轮 Windows 结果外推为跨平台通过。
- 系统服务只桥接可访问的文件字体；私有内存、远程、多文件字体，以及没有可访问文件的 UI 字体可能回退。
- 普通未扩展 SDL_ttf 保留静态字体兼容路径；显式轴设置需要扩展 ABI。字体没有某轴时不会自动生成该能力，opsz 不自动随字号变化。
- 固定 FontSource 实例或源 wght 坐标保持固定；需要动态字重时注册基础文件。显式样式 wght 优先，后续 withWeight／fontWeight 清除先前显式 wght。
- 持久缓存默认关闭，仍需枚举／stat 文件；同大小同时间替换用 force 刷新。系统字体安装变更通知尚未接入。
- 跨样式统一 shaping、段落 bidi、cluster 级平台缺字匹配、精确 advance／ink／cluster 共享布局仍属后续迭代。
- 原生图集／驱动显存总预算、跨平台长时资源与性能基线仍需补齐。严格检查保留原有、具理由的项目级关闭项，没有扩大豁免。

后续优先级同步于 [.todo/todo.md](../../.todo/todo.md)。
