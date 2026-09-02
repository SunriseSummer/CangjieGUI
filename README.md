# CUI/苍翠：仓颉桌面 GUI 框架

用[仓颉编程语言](https://cangjie-lang.cn/)实现的跨平台/自渲染/声明式桌面 GUI 框架，提供声明式界面构建、状态管理、常用组件、文本渲染、矢量绘制以及系统能力集成等。底层依赖[仓颉 SDL 图形库](https://github.com/SunriseSummer/CangjieSDL)。

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## 文档与示例

- [示例应用](examples/)
- [入门指南](docs/guide/index.md)
- [API 文档](docs/api/index.md)
- [技术博客：从声明式语法到增量 Element 内核](docs/cui-architecture-deep-dive.md)
- [核心技术博客：状态管理与增量渲染内核](docs/cui-state-incremental-rendering-deep-dive.md)
- [实战博客：从组合视图到完整自定义控件](docs/cui-custom-widget-practical-guide.md)

## 开发环境

- Cangjie SDK 1.0.5
- API 与条件编译目标为 Windows/macOS/Linux；当前完整自动/真实窗口验收证据来自 Windows，另外两个平台的
  未完成验证项见[完成度审计](docs/next-generation-completion-audit.md)
- 三平台构建、真实窗口、干净交付与性能证据由
  [cross-platform qualification](.github/workflows/cross-platform-qualification.yml) 统一编排；平台 runner 和动态库
  前置契约见[开发工具说明](.dev/README.md)
- Linux x64/macOS arm64 另有全新 GitHub 托管机 portability lane：从带大小/SHA-256 的固定官方 SDK 与 SDL 源码
  开始，验证安全 bootstrap、源码链接、无头包测试和全部示例编译；真实桌面与性能结论仍只来自 qualification
- 参阅 [`CangjieSDL`](https://github.com/SunriseSummer/CangjieSDL) 项目文档，根据目标平台规格配置 SDL 和 SDL_ttf 动态库

> [!IMPORTANT]
>
> 发布和部署基于 CUI 的桌面软件时，请确保 SDL 和 SDL_ttf 动态库位于仓颉可执行文件目录，或在目标平台的动态库搜索路径中，即可以作为私有资产打包或在目标平台作为公共运行时安装。Windows 构建还应携带与框架同版的 `cui_uia.dll`，以启用内建 UI Automation provider。

## 快速开始

新建仓颉项目，在 `cjpm.toml` 配置 CUI 依赖：

```toml
[dependencies]
cui = { path = "<path/to/CangjieGUI>" }
```

在 `src/main.cj` 中编写代码创建一个简单窗口：

```cangjie
import cui.*

main() {
    let message = State<String>("你好，CUI")
    let app = DesktopApp(WindowSpec("CUI 示例", 640, 420))

    app.run {
        VStack {
            Panel {
                Label(message.value)
            }.flexible(false)
            Button("更新文本", {=> message.value = "状态已更新"})
                .role(ButtonRole.Primary)
                .width(160.vp)
        }.spacing(12.vp).padding(20.vp)
    }
}
```

执行 `cjpm run` 即可运行查看效果。

## 核心能力

- 基于 SDL3 实现自渲染 GUI 引擎。
- 基于仓颉尾随 lambda、extend、prop 等特性构建声明式 UI 编码范式。
- 提供 `VStack`、`HStack`、`ZStack`、`Grid`、`Panel`、`FlowRow`、`ScrollView`、`SplitView`、`Accordion`、动画折叠
  容器 `Reveal` 等布局容器，以及数据驱动、只渲染视口附近的懒加载容器 `LazyColumn`、`LazyRow`、`LazyList` 与 `LazyGrid`。
- 提供按钮、文本框、开关、复选框、单选框、选择器、步进器、滑块、进度条、环形进度、评分、状态徽标、过滤标签、
  步骤条、分页导航、面包屑、列表、数据表格、树视图、日期选择器、时间选择器、拖动重排列表、分段控件、标签页、下拉和组合框等控件。
- 提供下拉/右键菜单、应用菜单栏、选择器、提示、通知与模态对话框等浮层，浮层按栈管理、可嵌套，对话框内可继续打开下拉、组合框与右键菜单。
- 使用有顺序语义的链式修饰器配置尺寸、约束、内边距、表面、圆角、边框、阴影、渐变背景、弹性、可见性和可用性，支持 `.px`，`.vp`，`.fp` 尺寸单位表达；运行时 Modifier 集合可用自适应 `concat` 保序平衡，普通 `then` 热路径不承担额外表示成本。
- 阴影、焦点环与自定义 Canvas 通过可组合 `PaintOutset` 声明真实越界绘制域；Scroll/Lazy/Reveal、ScenePatch
  和 damage 共用同一契约，普通节点不再无条件支付固定 16px clip 余量。
- 以 `Observable`/`Bindable` 实现事务式、无毛刺状态管理：可写 `State<T>` 采用有序、可重入且无数组复制的通知窗口；事务在观察者失败后仍排空其他 State/Derived 依赖再报告首错；可选等价策略同时抑制单次空写和事务首尾等价的净零路径；带缓存的派生只读
  `DerivedState`（`derive`/`deriveStates`/`map`）用 State 写入 epoch 作 O(1) 否定证书、融合宽源初始快照，并在增量图中作为不提前求值的一等依赖节点；全 State 数组自动或显式进入静态专用采样路径。State 读取通过 `Mount + Phase` 封闭和路由到唯一动态作用域，普通 builder 与持久执行阶段的稳定读取轨迹直接作为已提交依赖集合的顺序证书，首个差异才退回通用集合正规化。状态等价策略可沿纯投影 pullback，并能显式包装成零默认开销的命中/失败/耗时诊断。`Lens`/`Binding`（`project`）可组合且可验证三定律，端态变换在组合 Lens 中逐层一次提升；`Bindable.update` 把任意深度字段变换归约为一次根模型 read-modify-write。`cui.testing` 把 Lens/Prism 往返律与策略等价律变成逐项可执行反例。控件按读写需要接受对应抽象。
- 较大特征可用强类型 `Reducer<Model, Action>` 与只读 `ModelStore<Model, Action>` 建立单向数据流；`dispatchAll` 把有序 Action 列表在一个模型快照上折叠并只提交一次，selector 直接复用 `DerivedState`，并可用显式结果等价策略阻断无关 Action 的重建扩散；`ScopedStore` 让子视图只认识本特征类型且仍共享唯一根事实，普通 scope 与末端 selector 融合为一个派生节点，`FeaturePath` 再把状态 `Lens` 与 Action `Prism` 固化为 reducer/store 共用的可组合边界。可选/重复子特征由 child-first `ifPresent`/`forEach` 组合，`IdentifiedArray` 维护稳定显示顺序，并由 `forEachBatch`/`identifiedBatchReducer` 把显式 child Action 批次归约为一个集合版本；关系模型使用 `EntityTable` 正规化为 ID 键控持久表，以 `forEntity` 复用单实体 child-first 语义，以 `forEntities`/`entityBatchReducer` 批量归约，也可用 `EntityUpdate`/`updatingAll` 直接应用多实体变换。action-driven Binding 让控件写入仍经过 reducer，策略重载可只观察字段等价类而不吞 Action/Effect；局部交互继续使用 `rememberState`。
- 需要文件、网络或计时器的特征可升级为 `EffectReducer` / `EffectStore`：纯 reducer 返回 `Transition<Model, Effect>`，不可变 `EffectBatch` 以 O(1) 拼接效果描述；测试直接取得批次，生产组合根可 `connect` 一次显式解释器后向全部子视图传普通 `ScopedStore`，不再重复 handler 或泄漏根 Effect 类型。Store 不内建线程池、网络栈、取消策略或隐式同步反馈，后台结果仍通过 `DesktopApp.post` 作为新 Action 回到 UI 线程。
- 固定声明可用 `remember { ... }` 保留控制器、派生图等任意稳定对象，用 `rememberState { ... }` 保留可写状态，并可直接注入结构或领域等价策略抑制无效写入；二者共享带形状守卫的位置槽。条件、循环和重排内容用显式键、`Keyed`、`ForEach` 表达业务身份。remembered `DerivedState` 自动成为单一惰性依赖节点，开发者不必为性能把它手工移出 build。普通 builder 自动跟踪 State 读取、裁剪脏路径、把顶层零/一/多子项正规化后的逻辑根整体缓存、选择性晋升复杂渲染边界，并自动管理 measure/layout 缓存、透明显示列表和局部 damage。静态 effect 与无显式 revision 的 retained 声明也可随干净祖先一起跳过；`RetainedSubtree` 仅保留为显式高级/兼容边界。
- 持久 Element 将几何、UI 环境、overlay、semantics fragment 与事件路由拓扑放进同一个原子布局提交；phase 依赖前沿与最后成功结果同寿命，Widget 对象替换只令结果 stale，成功重收集才原子换边，布局异常或阶段内 State 自写继续保留上次成功版本，开发者无需协调多套缓存或手工回滚输入索引。
- 内建控件自动生成平台无关 `SemanticsNode`，自定义组件可声明角色、值与动作；语义子树以 retained fragment
  组合，在稳定布局事务后归一化为带 revision、O(1) id/action 索引的增量 patch，并可通过
  `AccessibilityAdapter` 原子推送给平台桥。Windows 桌面后端自动暴露真正的 UI Automation fragment provider，
  支持常数时间父子/兄弟/焦点导航、空间命中、Invoke/Value/Toggle pattern 和结构/属性事件。原生桥、应用观察器
  与故障回调按 revision 独立推进：单个分支失败只熔断自身，并保留结构化诊断，不会终止其它分支或帧循环。
- 用 `mountEffect` / `lifecycleEffect` 在成功提交后挂载可清理 Resource；固定结构可直接使用 keyless 重载，动态结构继续使用显式键与 `Keyed`/`ForEach`。它们与 `remember` 共用带声明种类的形状守卫，避免 builder 的执行或跳过次数泄漏为副作用语义；前者是可持久复用的静态声明，后者的 revision 保留对普通外部值的逐帧可见性。显式 Frame 订阅以不可变有序片段跨干净帧 O(1) 采用，只为实际订阅者派发。`retainedDiagnostics()` 可导出 scope、dirty 原因、依赖和 effect 状态。
- Overlay 保持声明顺序与原位 owner 替换语义，同时用 owner→index 映射消除注册/路由的二次扫描；干净 Element 布局提交可 O(1) 采用不可变 overlay 片段，动态追加和派发中关闭仍按写时物化保持安全。
- `EventListener { body }` 与紧随声明的 fluent `.onEvent` 都携带 owner generation + 内部声明身份，内外同名 key 不会误路由；稳定声明区间通过 tombstone 保留 `.key`/disabled 修改后的精确 facet。
- 支持主轴/交叉轴排列、权重布局、内容自适应、流式换行、裁剪滚动和可复用组件组合。
- 使用 GPU 几何图元和物理密度感知的 Auto 超采样渲染圆角、描边、图标、阴影及抗锯齿图形；高 DPI 后备缓冲不会再被默认重复放大。
- 提供动画原语：物理弹簧 `Spring`、时长驱动可选缓动曲线与延迟的补间 `Animator`，以及永不静止的重复时间线 `Pulse`，
  由渲染循环充当动画时钟，脏帧下自动续帧；动画折叠容器 `Reveal` 以缓动高度做展开/收起过渡。
- 提供设计令牌尺度：间距 `Spacing`、圆角 `Radii`、动效 `Motion`，与颜色 `Theme`、字号 `FontSizes`、
  高度 `Shadow.elevation` 一起构成一致的设计系统。
- 提供文件对话框、消息框、剪贴板、光标、显示器、文件系统、时间、系统信息等平台能力接口。
- 已实现每应用事务式失效与观察通知、离散事件间一致性重建、generational Element/Scene 焦点与绘制所有权、可 O(1) 采用的持久焦点声明片段、Capture/Target/Bubble 事件传播、显式有界指针契约与容器有序 AABB 路由、截止时间续帧、有界事件等待/跨线程唤醒、图元与文本缓存、惰性渲染、自动组合/渲染边界、层次化 ScenePatch 命令槽及有序持久 BVH、32 MiB 有界 LRU 显示列表与保守局部 damage；`WidgetTestHost` 同构指针/焦点事件并支持真实 Renderer/damage 对照，阶段剖析、命令规模诊断、基准报告和 examples E2E 工具用于精细验证。

扩展阅读：[现代 GUI 核心范式洞察辨析：函数式/对象式，立即模式/保留模式](docs/modern-GUI-insights-and-analysis.md)

## 许可证

本项目以 [MIT 许可证](LICENSE) 发布。
