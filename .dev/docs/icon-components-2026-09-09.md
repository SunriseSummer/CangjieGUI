# 用户媒体图标改造与验证

本次改造将图标资源完全交给应用：删除 CangjieSDL 的 IconName／drawIcon，不在 GUI 或 SDL 库中打包图案。Icon、IconButton 移至 cui.media，复用既有图像加载与有界纹理缓存；cui 伞包继续导出组件。使用方法与迁移步骤见[图标指南](../../docs/guide/how-to/icons.md)，完整应用见[图标工坊](../../examples/icons/README.md)。

## 设计与实现

- IconSource 定义不可变的文件／内存资源、原色／模板意图和可选位图规格。内存快照与规格表按约定复制，来源可跨组件复用。
- Template 保留 Alpha 并替换 RGB；Original 保留媒体颜色。颜色、透明度、镜像和采样参数不生成各自的纹理副本。
- Surface.alphaMask 使用 SDL_ConvertSurface 转为 RGBA32，处理调色板／色键透明后，按原生行距写入白色 RGB。输入不变，所有正常失败路径关闭转换结果，逐像素循环没有 FFI 调用。
- 图标尺寸按实际渲染栅格比例计算，包含超采样。SVG 按目标尺寸栅格化，位图规格选择最小足够项；最大边长 2048，解码预算 4,194,304 像素。位图缩小发生在解码后，该预算不代表瞬时内存上限。
- Icon 在测量阶段不加载，受父约束时保持正方形占位；绘制居中等比容纳。失败保留占位，可使用应用提供的单层回退，并暴露主来源的 status／loadError。
- IconButton 的图形大小、按钮表面、文字间距和操作名称独立配置。自然点击区域随图形与字体增长；沿用鼠标、键盘、焦点、禁用及无障碍激活协议。
- TreeNode 与 RichSpan 使用同一 IconSource；自绘 Widget 使用 paintIcon，避免在 draw 中构造并 emit 子组件。
- 缓存继续按线程／渲染器隔离，默认限制 256 项与估算 128 MiB。模板变体纳入同一容量管理；显式失效覆盖原色、模板与尺寸变体，唤醒保留绘制；稳定负缓存不因全局容量淘汰而每帧重试。

日期／时间选择器改用结构性展开线条。两者的字段绘制共用一个具有异常安全裁剪的实现，弹层继续通过既有 registerRectOverlayWhen 注册，兼容布局与自定义绘制宿主。

设计参考 [SwiftUI 的颜色模式](https://developer.apple.com/documentation/swiftui/image/renderingmode(_:))、[Flutter ImageIcon 的来源与语义](https://api.flutter.dev/flutter/widgets/ImageIcon-class.html)及 [Qt QIcon 的分辨率选择](https://doc.qt.io/qt-6/qicon.html)。不引入预置素材、网络加载或动画。

## 示例资源

19 个受影响示例已迁移，每个示例在自己的 assets/icons 中持有所需图标。原创矢量生成器保留在 examples/icons/generate_assets.py，资源按仓库 MIT License 提供，不依赖第三方图标集合。

图标工坊展示 16 vp 专用光学校正稿、常规 24 单位 SVG、24／48／72／96／144／192 px 彩色位图规格、最近邻像素画、深色容器中的模板着色、透明度、镜像、内存资源、错误回退、按钮、树节点和行内图标。截图使用真实渲染器生成。

![图标工坊](../../examples/.images/icons.png)

## 兼容性

这是有意的 API 调整：旧 IconName 调用必须改成应用资源；直接导入 cui.core.Icon／IconButton 的代码改用 cui.media。IconButton 的 label 直接接受 String。首轮迁移后应清理应用构建目录，避免旧依赖缓存漏掉 controls → media 的新关系。

不需要复制可选 WebP、TIFF、AVIF DLL。SVG 仍是 SDL3_image 支持的子集；ICO 静态加载不等于保证按目标尺寸选择内嵌子图。严格像素画需同时考虑物理像素整数倍和窗口超采样设置。

## 验证

环境：Windows x86_64，仓颉 1.0.5，SDL 3.4.12，SDL3_image 3.4.6。

| 验证 | 结果 |
|---|---|
| 修改前 GUI／SDL 全量测试 | 978／249 项通过 |
| 修改后 GUI 全量测试 | 988／988，通过 |
| 修改后 SDL 全量测试 | 251／251，通过 |
| 控件及框架集成定向回归 | 291／291，通过 |
| 受影响示例 | 19／19 项目通过测试门禁 |
| icons、calendar、file_explorer、richtext、images | 15／15 构建及截图门禁通过；5 组增量／完整渲染逐像素相同，容差 0 |
| 可执行文档片段 | GUI 142、SDL 87 个程序编译通过 |
| L2 静态检查基线 | 两仓库均无新增结果、无 ERROR／WARN |

新回归覆盖：黑色模板变色、原色与半透明像素、镜像、共享遮罩互不串色、索引透明与色键转换、源表面独立性、关闭后访问、11 种静态解码格式的两种颜色模式、尺寸／规格校验、实际栅格比例、预热、缓存淘汰、显式失效、文件恢复、失败回退、录制资源失效、按钮操作名、焦点与禁用协议。原有图标按钮协议测试迁移到了媒体包，没有删除其行为覆盖。

静态检查还运行了完整 cjfmt／cjlint。项目既有命名、格式与范围建议仍有大量报告，不作为全部修复的声明；新图标中的枚举 PascalCase、Widget 忽略参数 `_`、SVG XML 命名空间字面量、解码策略常量和紧凑测试排版按现有工程约定保留。共享技能文件及全局检查配置未修改，没有新增抑制或关闭检查项。

验证记录位于两仓库的 `target/dev/icon-refactor/`。GUI 的 `delivery-tests.log`、`controls-integration-tests.log`、`examples-report.json`、`visual-final.log`、`baseline-delivery.json` 记录各门禁；SDL 的 `native-retest.log` 和 `node-test.log` 保存完整 251 项运行输出。完整工具编排中出现过仅返回退出码的 SDL 测试失败，原因未确定；之后独立运行、相同 Node 调用以及最后的 build／test 完整编排均通过，最后结果保存在 SDL 的 `full-validation.json`。保留中间日志，不将失败记录改写为成功。

## 性能采样

使用修改前工作区快照和修改后实现分别构建 release 程序。停止其他编译后，交替启动两组进程各 6 次，每个项目得到 54 个批次样本；以下为中位数。场景使用同一窗口大小和超采样设置，网格包含 beginScene／endScene，测量的是 CPU 提交成本，不是 GPU 完成时间或显示帧率。

| 场景 | 修改前 | 修改后 |
|---|---:|---:|
| ImageView 稳定负缓存访问 | 5 ns | 5 ns |
| ImageView 重建并命中负缓存 | 39 ns | 39 ns |
| 100 张 ImageView，Contain | 36.77 μs | 32.25 μs |
| 100 张 ImageView，Cover | 28.70 μs | 27.85 μs |
| 100 个 Save 图标 | 1,165.84 μs | 80.48 μs |

既有图像场景未出现可见退化，图像网格差异与采样波动有重叠，不将其宣称为确定优化。最后一项比较旧内置矢量 Save 与应用提供的 SVG Save，图案与渲染路径不同，不是等像素基准；它说明预热后的媒体图标可显著减少这一场景的重复几何提交。首次文件解码与纹理上传仍有成本，可通过 preloadIcon 预热。

原始数据、MAD／极值、二进制 SHA-256 与运行脚本在 `target/dev/icon-refactor/perf/`，汇总为 `results.json`。

这些结果来自当前 Windows 环境；本轮没有执行 Linux／macOS 原生窗口测试。
