# CUI/苍翠：仓颉桌面 GUI 框架

用[仓颉编程语言](https://cangjie-lang.cn/)实现的跨平台/自渲染/声明式桌面 GUI 框架，提供声明式界面构建、状态管理、常用组件、文本渲染、矢量绘制以及系统能力集成等。底层依赖[仓颉 SDL 图形库](https://github.com/SunriseSummer/CangjieSDL)。

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## 文档与示例

- [入门指南](docs/guide/index.md)
- [API 文档](docs/api/index.md)
- [示例应用](examples/)

## 开发环境

- Cangjie SDK 1.0.5
- Windows/Mac/Linux
- 参阅 [`CangjieSDL`](https://github.com/SunriseSummer/CangjieSDL) 项目文档，根据目标平台规格配置 SDL 和 SDL_ttf 动态库

> [!IMPORTANT]
>
> 发布和部署基于 CUI 的桌面软件时，请确保 SDL 和 SDL_ttf 动态库位于仓颉可执行文件目录，或在目标平台的动态库搜索路径中，即可以作为私有资产打包或在目标平台作为公共运行时安装。

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

| 能力领域 | 提供什么 | 设计亮点 |
|---|---|---|
| 声明式 UI | 利用仓颉尾随 lambda、`extend` 和 `prop` 组合界面；支持自定义控件、容器与 Canvas。 | 自定义组件可复用框架的布局、事件、状态、语义和渲染机制，不局限于内置控件组合。 |
| 布局与控件 | 提供 Stack、Grid、Panel、Flow、Scroll、Split、Accordion、Reveal，以及列表、表格、树、表单、选择和导航等常用控件。 | `LazyColumn`、`LazyRow`、`LazyList` 和 `LazyGrid` 只处理视口附近内容，兼顾复杂界面与大数据量。 |
| 样式与设计系统 | 链式 Modifier 配置尺寸、约束、间距、圆角、边框、阴影、渐变、弹性和可用性；支持 `.px`、`.vp`、`.fp`。 | `Theme`、`FontSizes`、`Spacing`、`Radii`、`Motion` 和 `Shadow.elevation` 提供统一设计令牌。 |
| 状态与绑定 | `State<T>` 提供事务式、可重入的变更通知；`DerivedState` 缓存派生值；`Binding`、`Lens` 和 `project` 支持局部读写。 | 等价策略可过滤空写和净零事务；依赖自动收集，派生状态作为惰性节点参与增量图。 |
| 应用架构与副作用 | `Reducer`、`ModelStore`、`ScopedStore` 和 `FeaturePath` 支持强类型单向数据流；`EffectReducer` 与 `EffectStore` 显式描述外部效果。 | 批量 Action 只提交一次模型，子特征共享根事实；文件、网络和计时器等效果保持可测试、可解释。 |
| 增量重建 | `remember`、`rememberState`、`Keyed` 和 `ForEach` 保留稳定对象与业务身份；builder 自动跟踪状态读取。 | 仅重建受影响路径，干净子树可直接复用；布局、overlay、语义、事件拓扑和副作用随 Element 原子提交。 |
| 渲染与动画 | SDL3 GPU 图元、纹理、文字、圆角、描边、阴影和物理密度感知的 Auto 超采样；提供 `Spring`、`Animator`、`Pulse` 与 `Reveal`。 | ScenePatch、持久命令槽、BVH、显示列表缓存和局部 damage 共同减少无效布局、绘制与提交。 |
| 事件、焦点与浮层 | 支持 Capture、Target、Bubble 传播，稳定的焦点与指针路由，以及菜单、提示、通知和模态对话框。 | Overlay 按栈管理且可嵌套；owner generation 与声明身份避免动态结构中的事件误路由。 |
| 生命周期与调度 | `mountEffect`、`lifecycleEffect` 管理可清理资源；渲染循环提供动画时钟、截止时间续帧和跨线程唤醒。 | 副作用只在成功提交后生效，静态声明和 Frame 订阅可跨干净帧复用。 |
| 可访问性与平台能力 | 控件生成 `SemanticsNode`，Windows 后端接入 UI Automation；同时封装对话框、剪贴板、光标、显示器、文件系统、时间和系统信息。 | 语义树增量提交并提供快速导航、命中和动作索引；自定义组件也能声明角色、值与操作。 |
| 测试与诊断 | `WidgetTestHost` 覆盖布局、指针、焦点、Renderer 和 damage；提供状态定律验证、阶段剖析、命令诊断、基准与示例 E2E 工具。 | `retainedDiagnostics()` 可追踪作用域、脏因、依赖和 effect 状态，便于定位增量链路问题。 |

## 许可证

本项目以 [MIT 许可证](LICENSE) 发布。
