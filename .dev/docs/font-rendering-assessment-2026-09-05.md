**字体配置与文本渲染专项评测 · 2026-09-05**

本次已复现斜体重叠，并将主因定位到当前 SDL_ttf 3.2.2 的 Renderer Text Engine：合成斜体的字形位图被绘制到过宽的目标矩形，而字形推进距离保持原值，因而发生横向拉伸和字间重叠。同一字体、字号和字符串通过整段 Surface 栅格化正常；直接绕过 CUI 和 CangjieSDL 调用原生 API，问题仍然成立。

此外，已复现 fallback 配置互相影响、DPI 变化后段落缓存错误复用、字体加载失败后不能恢复、富文本拆段改变字距和大字号控件高度不足。解决方案需要同时覆盖 CangjieSDL 的字体资源与度量契约，以及 CUI 的缓存、排版和样式继承。

本次完成分析、独立探针和方案验证，未修改两个仓库的生产代码。下述新接口均是设计建议，不是现有可调用 API。

**证据范围**

- CUI `0.9.5`，提交 `a926908c265ad6b965561df3266dfa9e8ffcf20b`；沿用工作树中的本地 SDL 路径依赖。
- CangjieSDL `0.6.6`，提交 `38ebd1d729f38db8610aea925b2252c17aece138`。
- Windows x86_64、Cangjie 1.0.5；动态库实测版本 SDL `3.4.12`、SDL_ttf `3.2.2`。
- CangjieSDL 本轮 `cjpm build` 和 `cjpm test --no-progress` 通过，144/144 测试，无跳过。
- 原生探针直接调用实际 DLL，比较 Surface 与软件 Renderer Text Engine，检查字形拷贝命令和图集位图尺寸；覆盖微软雅黑、Segoe UI、Georgia 的常规、合成斜体及真实 Italic 字体文件。
- 仓颉探针通过当前 CUI/CangjieSDL 公开接口验证配置、缓存、排版和字体缩放，并在 Direct3D11、supersample=1 下确认斜体问题及整段纹理规避路径。
- 原始程序、日志、JSON 和 DLL/字体 SHA-256 位于本机 `target/dev/font-assessment/`。未测 Linux/macOS、全部字体、所有 DPI/超采样组合或完整性能套件。

**问题与优先级**

| 优先级 | 问题 | 证据状态 | 主要归属 |
|---|---|---|---|
| P1 | 合成斜体被横向拉伸，文字重叠 | 原生与 Direct3D11 实测 | SDL_ttf 原因；CangjieSDL 负责规避与依赖治理 |
| P1 | 同一主字体的不同 fallback 链共享可变原生字体 | 会话结果与调用顺序反例 | CangjieSDL，涉及 SDL_ttf 内部缓存 |
| P1 | DPI 改变后段落缓存复用旧换行 | 相同上下文与新上下文对照 | CUI，需上游提供准确度量环境标识 |
| P2 | 文件恢复并重新注册后仍永久回退 | 缺文件→补文件→重新注册反例 | CangjieSDL |
| P2 | 无系统族名解析、真实样式匹配及 TTC 面选择 | 源码与按名/按路径对照 | CangjieSDL；CUI 提供统一入口 |
| P2 | 字体设置缺少应用/子树继承，控件字号适配不一致 | 源码及按钮 200% 字号反例 | CUI |
| P2 | 宽高、推进距离、墨迹边界和基线没有独立契约 | 源码；混合字号基线可见偏移 | 两层共同调整 |
| P2 | RichText 按 span 独立 shaping，拆段改变排版 | `AV` 整段/拆段宽度对照 | CUI，依赖上游布局能力 |
| P2 | 字体/字号缓存缺少整体预算与可观测性 | 源码确认容量边界；未测长时内存上界 | CangjieSDL |
| P2 | 测试只证明“可测可画”，缺少字体结果判定 | 既有测试通过而专项反例失败 | 两仓库测试与文档 |

**1. 斜体重叠：已定位的主因**

现有链路为 `Label/RichText → Renderer.text → NativeFont.drawText → TTF_DrawRendererText`。字体样式经 `TTF_SetFontStyle` 设置；CangjieSDL 只寻找真实 Bold 伴生文件，没有对应的 Italic/BoldItalic 字体选择，见上游 [native_text.cj](../../../CangjieSDL/src/text/native_text.cj) 的 `FontFace.openStyled`。

32 像素字号的原生探针得到以下具体数据。下面的目标宽度来自 TTF_Text 的实际拷贝命令，位图宽度来自同一字形的原生图像，advance 来自原生字形度量。

| 字体与字形 | 实际位图宽 | 目标矩形宽 | advance | 结果 |
|---|---:|---:|---:|---|
| 微软雅黑 Regular，`A` | 23 | 23 | 23 | 正常 |
| 微软雅黑合成斜体，`A` | 23 | 32 | 23 | 位图横向放大约 39% |
| Segoe UI Regular，`A` | 21 | 21 | 21 | 正常 |
| Segoe UI 合成斜体，`A` | 21 | 30 | 21 | 位图横向放大约 43% |
| Segoe UI 真 Italic，`A` | 21 | 21 | 20 | 位图按原尺寸绘制 |

真实斜体的墨迹宽可以大于 advance，这是字体设计允许的字形外伸，不应当被统一消除。本次异常的关键是“同一位图被错误拉宽”，不是任何字形外伸都算缺陷。

同一段英文在相同画布上比较原生 Surface 与 Renderer Engine，按单通道差异大于 8 计数：微软雅黑常规为 0 像素，合成斜体为 5,838；Segoe UI 常规为 0，合成斜体为 4,942，真实 Italic 为 1；Georgia 合成斜体为 4,586，真实 Italic 为 0。三种合成斜体样本各有 31/31 条字形拷贝命令的目标尺寸与位图尺寸不一致。

![同字体同字号的原生 Surface 与 Renderer Engine 对照](assets/font-assessment/native-comparison.png)

源码链条与观测一致：[SDL_ttf 3.2.2](https://github.com/libsdl-org/SDL_ttf/blob/release-3.2.2/src/SDL_ttf.c)为合成斜体扩大估算字形宽度，再将该宽度用于拷贝目标；[Renderer Text Engine](https://github.com/libsdl-org/SDL_ttf/blob/release-3.2.2/src/SDL_renderer_textengine.c)使用实际位图建立图集，却将完整图集 UV 映射到该目标矩形。两者的宽度契约不一致。

下面是当前 CangjieSDL 的 Direct3D11 实测。第一行为现有直绘路径；第二行使用现有整段纹理路径、旋转角度为 0；第三行显式注册真实 Segoe UI Italic 文件。第三行中文走常规 fallback，不能据此声称中文已经有真实斜体字形。

![当前 CangjieSDL 的斜体、整段纹理规避和真实 Italic 对照](assets/font-assessment/cangjie-font-paths.png)

**建议修复路径。**

1. **先在 CangjieSDL 内提供受控规避。** 对已确认有问题的运行库和斜体路径，将整段文字栅格化为纹理并缓存；复用现有 `renderSurface` / 旋转文字纹理机制，但抽取按左上角绘制的内部入口，保留坐标、颜色、透明度、clip、资源 epoch 和命令重放语义。调用方仍使用 `Label.italic()` 或 `Renderer.text`。
2. **不要让应用逐个换成 `textRotated(..., 0)`。** 本次调用只证明规避路径可行。生产实现需按实际纹理尺寸定位；不能普遍用 `textHeight("国Ag")` 代替任意字符串的栅格高度，也不能沿用旋转标题场景的小容量清空策略而不测大量正文。
3. **补充真实 Italic/BoldItalic 选择。** 优先选择真实字形；没有真实样式时再按明确策略合成或回退。判断不能只看主字体：fallback 字体也可能需要合成斜体。
4. **长期修正原生尺寸契约。** 若维护 SDL_ttf 补丁，应在生成字形绘制命令时使用实际栅格的 bearing、宽高及有效源矩形，并让图集 UV 与裁剪后的源区域一致；保留 shaping 的 advance。修复需覆盖负 bearing、outline、SDF、fallback 和裁剪，不能只将所有 `dst.w` 强制替换为位图宽。

不建议通过统一增大 letter spacing、给 Label 加 padding、关闭 kerning 或逐字符绘制来修复：它们无法恢复被拉宽的字形，还会改变换行、连字、组合字符及点击位置。升级 SDL_ttf 后也必须重新执行这个反例，不能仅凭版本号判断问题已解决。本次没有构建或验收原生补丁。

**2. fallback 链共享：字体配置会受调用顺序影响**

CangjieSDL 的 `faces` 按路径缓存，`FontFace.fonts` 按字号/样式复用 NativeFont；`fontForFamily` 随后调用 `configureFallbacks`，在共享 TTF_Font 上清除并安装当前族的 fallback 链。不同注册名即使有不同的 metrics cache key，底下仍可能共享同一个可变字体句柄。

反例设置相同 Georgia 主字体，A 的 fallback 为 Segoe UI，B 的 fallback 为 Arial，文本为 `مرحبا بالعالم`，字号 32：

| 操作 | 宽度 |
|---|---:|
| 创建 A 测量会话并测量 | 162 |
| 使用 B 测量同一字符串 | 162，错误沿用先前结果 |
| 用 B 测量 16 个不同字符串，再用原 A 会话测量 | 129，原会话结果改变 |
| 全新 Renderer 中直接使用 B | 129 |

这里既有共享句柄改写，也有底层 shaping 缓存的历史效应。源码中 SDL_ttf 的 fallback 更新会通知 TTF_Text，但其字符串位置缓存的复用还受缓存命中情况影响。无论底层缓存如何实现，CangjieSDL 都不应把相互独立的 family 配置表达为同一可变句柄的反复改写。

**方案：** 将“主 face + 有序 fallback face 链 + 样式/字号 + 版本”作为原生字体实例或不可变解析结果的身份；安装 fallback 后保持不可变。测量会话和已成形文本持有其对应实例，不能因另一个 family 的使用而改变。变更注册时创建新版本，旧会话在允许的生命周期内继续引用旧版本，统一回收时先解除 fallback 引用再关闭字体。

**验收：** A/B 交错测量与绘制、正反调用顺序、位置缓存命中/淘汰、字体重注册、共享 fallback、多会话同时存活都应得到稳定结果；补充 fallback 环路拒绝与 renderer 关闭后的资源检查。

**3. DPI 缓存：外层环境失效没有传递到段落结果**

[ParagraphCacheKey](../../src/core/paragraph_layout_cache.cj)包含文本、逻辑宽度、字号、样式、字体注册名/版本和行数限制，但不包含影响原生 hinting 度量的渲染比例。`advanceUiEnvironment` 会改变 Label 的局部缓存判断，却没有同时使 UiContext 内的段落缓存过期。

探针对字符串 `AVAVAV office iiiWWWmmm 0123456789` 使用 13 fp，逻辑宽度固定为 258.5：

| 状态 | 全串度量宽 | Label 测量结果 |
|---|---:|---|
| 1×，首次布局 | 260 | 176×44，分成两行 |
| 改为 2×，复用同一 UiContext | 257 | 176×43，仍沿用两行 |
| 2×，新建 UiContext | 257 | 257×28，一行 |

复用上下文的段落缓存计数为 hit=1、miss=1，确认不是缺少一次外层重建，而是段落内部命中了过期结果。该问题会影响跨 DPI 显示器移动、渲染比例变化后的折行和尺寸。

**方案：** 短期将完整的度量环境代数加入段落键，或在相关环境变化时清空段落缓存。代数应来自实际字体度量使用的比例、字体解析版本和渲染器资源状态；只加入 UI 的 displayScale、遗漏真实 raster scale 仍不充分。长期明确逻辑 advance 与实际栅格度量的边界，决定 DPI 变化是否应改变换行，并使测量、绘制、点击采用同一约定。

**验收：** 同一上下文在 1×、1.25×、1.5×、2× 间往返，结果与每次新建上下文一致；同时覆盖 Auto/固定超采样、普通/斜体、ellipsis、RichText 和增量/全量绘制。

**4. 字体失败后缺少明确的恢复机制**

当前“注册”只记录名字与路径，文件加载失败时回退是已有公开契约；问题在于负缓存缺少可操作的恢复途径。`NativeTextRenderer.failedPaths` 一次记录后长期保留，而 `Renderer.synchronizeFontRegistry` 只清理度量和文字纹理缓存，没有重置该负缓存或更新已打开的同路径 face。

反例：先注册尚不存在的 Georgia 路径，测量宽度为默认字体的 313；创建该字体文件并对同名同路径再次注册，仍为 313；有效 Georgia 对照为 294。这不是要求 register 立即加载文件，而是需要显式规定何时重新解析/重试。

**方案：** 为字体资源增加版本与明确的失效/重试操作；重注册按约定推进资源版本，负缓存按版本保存。对同路径替换文件也要有明确语义，不能只清理一层 metrics。解析结果应能报告请求族、实际 face、TTC index、实际样式、fallback 原因、缺字或加载失败；保留宽容回退，同时允许应用严格校验必需字体。

**5. 字体配置：当前“字体族”实际只是路径别名**

实测本机已安装 Georgia，但直接传 `font: "Georgia"` 得到与默认字体相同的宽度 313；经 `Fonts.register` 显式绑定文件后为 294。[font_registry.cj](../../../CangjieSDL/src/font_registry.cj)已经支持有序 fallback 路径，但没有系统族名解析或安装字体枚举。调用 `isRegistered` 也只能证明存在注册项，不能证明文件已经加载。

当前模型还存在以下限制：

- 默认 UI 字体由硬编码文件路径候选决定，无法通过统一应用配置选择默认族。
- 真实 Bold 通过文件名猜测伴生文件；没有 Italic/BoldItalic 的成组 face 注册和匹配。
- 打开字体使用 `TTF_OpenFont`，公开注册不支持 TTC 的非零面号。SDL_ttf 本身已有 face-number 属性，见 [TTF_OpenFontWithProperties](https://wiki.libsdl.org/SDL3_ttf/TTF_OpenFontWithProperties)。
- FontStyle 只有粗体/斜体布尔值及装饰线，没有连续字重、stretch、合成许可或可变字体轴的表达能力。
- Label 与 RichSpan 可以选字体，Button 只开放字号，TextField/TextArea 及多个控件仍直接使用默认字体和固定 FontSizes；不能靠在容器上设置一次字体覆盖整页。

**建议建立分层字体配置，而不是继续增加字符串别名约定。**

| 层 | 应负责的内容 |
|---|---|
| CangjieSDL 的字体请求 | 族列表、weight/slant/stretch、face index、合成策略；高级 feature/language/variation 按后端能力扩展 |
| 字体解析结果 | 实际文件/face、样式来源、fallback 链、资源版本、诊断信息 |
| 系统解析服务 | Windows DirectWrite、macOS Core Text、Linux fontconfig 等平台匹配；应用随附字体作为显式优先配置 |
| CUI 文本样式环境 | 应用默认 → 子树覆盖 → 控件覆盖 → RichSpan 覆盖；统一字体、字号、颜色、行距、装饰和缩放 |

旧 `.todo/font.md` 倾向“目录扫描 + 自研 SFNT name 表”。它适合明确追求少依赖的字体索引，但不能自然等价于系统匹配策略。当前目标包含本地化族名、真实样式、TTC 和系统 fallback，建议先定义解析接口，再按平台选择实现；自研扫描可作为明确边界的备用方案，不直接取代系统策略。[DirectWrite 字体枚举](https://learn.microsoft.com/en-us/windows/win32/directwrite/font-enumeration)和 [fontconfig 配置](https://fontconfig.pages.freedesktop.org/fontconfig/fontconfig-user.html)可作为平台实现依据。

常用路径应保持简单：选择系统族、注册随附字体族、设定应用默认样式。数值字重与高级特性可以逐步开放；新增能力不意味着旧 `Fonts.register(name, path)` 和 `.bold()` 必须废弃。

**6. 字号适配：文字会放大，控件高度未必跟随**

本次 Button 在 fontScale=1 和 2 时测量高度均为 38；2× 下所用 30 像素文字的行高为 40，已超过控件高度，尚未计上下内边距。源码位于 [basic_widgets.cj](../../src/core/basic_widgets.cj)第 100 行附近：宽度使用缩放后的字体度量，高度仍为固定控制高度。

TextField/TextArea 的光标、选区、命中和文字绘制多处直接使用 `FontSizes.BODY`，其它选择控件也存在类似常量。因此解决方案不能只给文字增加 `.fontSize` 方法。

**方案：** 所有文本控件读取统一的有效 TextStyle；高度由字体 ascent/descent/lineGap、内容与 padding 推导，现有固定高度转为最小高度或密度令牌。输入控件的 caret、选区、IME anchor 和点击命中必须读取同一文本布局；UI 层承担 fp 到逻辑字号的解析，SDL 层承担逻辑尺寸到栅格尺寸的转换。

**验收：** 125%/150%/200% 字号时按钮、字段、菜单、列表、表格内容和焦点框均可达且无裁切；切换字体族与 fallback 后同样成立。应用与子树的字体设置要实际生效，而不只是修改设置页摘要。

**7. 排版度量：需要区分 advance、墨迹边界与基线**

现有 NativeTextMetrics 只包含 width/height，`Renderer.textHeight` 通过固定 `"国Ag"` 样本获取标准高度；这不能完整表达任意 run 的基线、外伸、装饰线和 fallback 字体几何。绘制命令边界也使用 `textWidth(text)` 加标准 `textHeight()`，没有独立的实际 ink bounds 契约。本次没有为所有字体构造出边界遗漏反例，应将这一点视为结构性能力缺口，而不是声称所有文字 damage 都错误。

RichText 的混合字号按行内垂直居中实现，见 [rich_text_layout.cj](../../src/controls/rich_text_layout.cj)第 405 行。它适合部分数字看板，但不是排版意义上的基线对齐；对照图底部的大号 `AV` 与小号文字能看到基线错位。也不宜继续在注释或说明中把垂直居中称作共享基线。

**建议的度量契约：**

- 字体度量：ascent、descent、lineGap、装饰线位置/厚度。
- run 布局：逻辑 advance、字形/cluster 位置、baseline、实际 ink bounds、源文本 byte offset 映射。
- line 布局：各 run 的共同 baseline、行框、实际绘制边界；允许显式选择居中作为另一种对齐方式。
- 绘制使用 ink bounds 管理裁剪和 damage；光标/选区使用 cluster 位置；相邻 run 使用逻辑推进关系。旧的 width/height API 保持含义，通过新增度量入口逐步迁移。

SDL_ttf 已提供 [ascent 查询](https://wiki.libsdl.org/SDL3_ttf/TTF_GetFontAscent)等基础接口，但仅补几个 FFI 不足以完成整段混合字体布局，需要把结果接入 CUI 的行构造、布局与输入映射。

**8. RichText：视觉拆段不应任意改变 shaping**

Georgia、40 fp 下，`RichText(["AV"])` 的宽度为 56，将同样样式的文字拆为 `["A", "V"]` 后为 58。原因是每个 span 分别测量/成形，然后把各自宽度直接相加；跨 span 的 kerning 和连字上下文丢失。颜色、高亮或链接边界不应天然成为字体 shaping 边界。

现有字素簇处理也以每个 span 的字符串为单位，不能保护一个 cluster 被调用方拆到两个 span 的情况。复杂脚本连接、双向文本和换行策略因此需要段落级处理，不能靠继续给单个 span 增加字段完成。

**方案：** 区分“影响 shaping 的样式”和“只影响绘制/交互的样式”；段落整体处理方向与断行，在连续、同字体/字号/语言/特性区间内 shaping，并将颜色、高亮、链接映射回 cluster 范围。若底层暂不支持跨 span 统一布局，先合并兼容的相邻 span、拒绝或规范化跨 cluster 的视觉边界，并明确限制。保留源文本到片段/链接的映射，避免优化后点击区域错误。

**验收：** 同一文本仅增加颜色、高亮或链接分段后，允许范围内的 glyph 位置和换行不变；覆盖 `AV`、`fi/ffi`、组合字符跨段、Arabic、混合字号/字体、中文标点与硬换行。不要只验证片段数或总宽度为正。

**9. 字体缓存：单桶有界不等于整体有界**

NativeFont 的 shaped-text cache 对每个实例有容量限制，但 `FontFace.fonts` 持续添加字号/样式实例；字体 face 表、metrics 的 `bySize` 桶也没有整体预算。字号连续动画、缩放预览、大量字体切换会扩大这些集合，并让字体查找的线性扫描成本增长。

另外，metrics/文字纹理用 1/256 字号键，NativeFont 使用 0.01 近似匹配，字号规范化不统一。当前没有实测其最坏内存增长，不能将它直接描述为已确认泄漏；但现有局部容量上限不能证明长期稳定。

**方案：** 统一字号与有效 raster scale 的规范化规则；按解析结果建立有整体预算的资源缓存，区分 CPU 布局、字体句柄、字形图集和整段纹理。会话或显示列表持有的资源不能被提前关闭；淘汰应尊重引用和 renderer 生命周期。新增句柄数、字号桶数、图集/纹理字节、fallback 切换、命中/淘汰和失败重试诊断。

**验收：** 以持续缩放、字体选择器、长文本滚动和频繁注册/失效进行压力测试，检查预热后的资源平台期与关闭后释放；斜体纹理规避路径单独比较冷启动、热重放、P95 与内存，避免以正确性修复引入整段纹理暴涨。

**10. 建议的实施顺序与职责划分**

| 顺序 | CangjieSDL | CUI | 验收重点 |
|---|---|---|---|
| 第一批：确定性修复 | 斜体受控规避；隔离 family/fallback 原生实例 | 段落缓存纳入完整度量环境 | 三个 P1 反例消失；正常文字不退化；真实字体与 fallback 行为稳定 |
| 第二批：资源与配置 | face 描述、样式映射、TTC、失效/重试、解析诊断 | 应用/子树 TextStyle；控件字体与字号统一 | 系统/随附字体可预测选择；字体恢复有效；200% 字号完整可用 |
| 第三批：排版契约 | 基线、advance、ink bounds、cluster 映射及整体缓存预算 | 基线行布局、RichText 跨视觉 span shaping、输入几何复用 | 文字、选择、高亮、点击和 damage 使用一致几何；长期资源有界 |
| 平台与高级能力 | 系统字体解析、字重/轴/特性/语言后端 | locale/RTL 和对应交互 | 各平台独立验证；只声明已实现并验收的能力 |

共同回归矩阵应覆盖常规/粗体/斜体/粗斜体、真实/合成样式、中文/Latin/复杂脚本/组合字符、字体缺失与恢复、fallback 配置交错、混合字号、DPI/超采样变化，以及直绘/整段纹理/命令重放。原生像素对照必须使用独立参考路径；只有增量与全量结果相同，仍可能同时保留同一个文字错误。

现有字体测试中，斜体主要断言宽度大于零，因此无法发现本次字形拉伸。建议将 typography/fonts/wenkai 等示例扩展为可切换字体、真实/合成样式和缩放的诊断样张，显示实际解析结果和基线/墨迹边界，并修正文档中“所有斜体合成均能干净渲染”等过强表述。

本次优先建议是：先修复斜体绘制和字体配置隔离，再统一度量缓存；随后建设完整字体配置与排版契约。无需为这些问题整体替换 CUI 增量内核或 SDL 图形后端。
