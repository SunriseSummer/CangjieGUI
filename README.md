# 仓颉桌面 GUI 框架

基于 [SDL3](https://github.com/libsdl-org) 图形接口，使用仓颉编程语言实现了一个跨平台/自渲染/声明式的桌面 GUI 框架，提供声明式界面构建、
状态管理、常用布局容器、常用控件、文本渲染、矢量绘制以及系统能力集成等。

本项目由两个边界清晰的核心包组成：

- `sdl`：SDL/SDL_ttf 的仓颉安全封装，可脱离 CUI 单独用于游戏和图形软件等。
- `cui`：在 `sdl` 基础上实现的自渲染、声明式 GUI 框架。

<img src="./images/gallery.jpg" />

## 核心能力

- 基于 SDL3 实现自渲染 GUI 引擎。通过 SDL3_ttf 渲染平台字体，完整支持 UTF-8 中文文本。
- 基于仓颉尾随 lambda、extend、prop 等特性构建声明式 UI 编码范式。
- 提供 `VStack`、`HStack`、`ZStack`、`Grid`、`Panel`、`FlowRow`、`ScrollView`、`SplitView`、`Accordion` 等布局容器，
  以及数据驱动、只渲染视口附近的懒加载容器 `LazyColumn`、`LazyRow`、`LazyList` 与 `LazyGrid`。
- 提供按钮、文本框、开关、复选框、单选框、选择器、步进器、滑块、进度条、环形进度、评分、状态徽标、过滤标签、
  步骤条、分页导航、面包屑、列表、数据表格、树视图、日期选择器、时间选择器、拖动重排列表、分段控件、标签页、下拉和组合框等控件。
- 提供下拉/右键菜单、应用菜单栏、选择器、提示、通知与模态对话框等浮层，浮层按栈管理、可嵌套，对话框内可继续打开下拉、组合框与右键菜单。
- 使用有顺序语义的链式修饰器配置尺寸、约束、内边距、表面、弹性、可见性和可用性，支持
  `.px`，`.vp`，`.fp` 尺寸单位表达。
- 以 `Observable`/`Bindable` 实现状态管理：可写 `State<T>`、带缓存的派生只读 `DerivedState`
  （`derive`/`map`）、双向投影 `Binding`（`project`），控件按读写需要接受对应抽象。
- 以 `Keyed`、`rememberState`、`ForEach` 明确复杂嵌套树与列表中的局部状态身份，控件交互身份按构建顺序自动唯一。
- 支持主轴/交叉轴排列、权重布局、内容自适应、流式换行、裁剪滚动和可复用组件组合。
- 使用 GPU 几何图元和超采样渲染圆角、描边、图标、阴影及抗锯齿图形。
- 提供文件对话框、消息框、剪贴板、光标、显示器、文件系统、时间、系统信息等平台能力接口。
- 已实现图元缓存、惰性渲染、脏帧检测/按需刷新等性能优化机制。

## 构建运行

```text
CangjieGUI/
├── cjpm.toml              # CUI 项目配置
├── src/                   # CUI 框架实现
├── examples/              # CUI 示例应用，端到端测试
├── bench/                 # CUI 性能测试
├── docs/                  # CUI 使用指南、API 与架构文档
└── sdl/                   # SDL 仓颉封装库，目前聚焦于图形接口
    ├── cjpm.toml          
    ├── .sdl3/             # SDL 与 SDL_ttf 运行库
    ├── src/               # SDL 仓颉核心封装
    └── docs/              # SDL 使用指南、API 与部署文档
```

本项目依赖跨平台多媒体库 [SDL-3.4.12](https://github.com/libsdl-org/SDL/releases/tag/release-3.4.12) 及其字体增强库 [SDL_ttf-3.2.2](https://github.com/libsdl-org/SDL_ttf/releases/tag/release-3.2.2)，其中 `Windows x64` 版本动态库已经预置到 `sdl/.sdl3` 目录，在此平台本项目开箱即用。

对于 Linux、Mac、Android 等平台，请打开以上超链接，在 release 板块下载相关发布件，解压后将动态库文件放到 `sdl/.sdl3` 目录中。如果官方 release 中没有匹配平台规格的发布件，可以用系统包管理工具安装（如 Mac 上执行 `brew install sdl3 sdl3_ttf`），或直接从 SDL 项目源码构建。

依赖库配置后，可以先跑一遍单元测试，在项目目录下执行 `cjpm test`，确保所有测试用例通过。

然后测试运行示例项目（对框架的端到端测试），`sdl/examples/` 下是基于 `sdl` 基础图形接口开发的小游戏，`examples/` 下则是基于 `cui` 桌面图形界面框架开发的小应用。选择您感兴趣的示例项目，在项目根目录执行 `cjpm run`，感受仓颉在桌面端的生动呈现。

> [!IMPORTANT]
>
> 发布和部署基于 CUI 的桌面软件时，请确保 SDL 和 SDL_ttf 动态库位于仓颉可执行文件目录，或在目标平台的动态库搜索路径中，即可以作为私有资产打包或在目标平台作为公共运行时安装。

> [!WARNING]
>
> 部分 Linux 发行版上，系统 `libglib-2.0.so.0`（`SDL3_ttf` 的间接依赖）编译时链接了带版本符号的 PCRE2，而仓颉运行时中的 `libpcre2-8.so.0` 不带版本符号。链接器若优先找到运行时自带的 PCRE2，会出现大量 `undefined reference to ...@PCRE2_10.47` 链接错误。
>
> 遇到这种情况，请在项目 `cjpm.toml` 中通过 `link-option` 显式指定系统 PCRE2：
>
> ```toml
> [target.x86_64-unknown-linux-gnu]
> link-option = "/usr/lib/libpcre2-8.so"
> ```

## 快速开始

新建仓颉项目，在 `cjpm.toml` 配置 CUI 依赖：

```toml
[dependencies]
cui = { path = "<path/to>/CangjieGUI" }
```

创建一个简单窗口：

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

在项目目录执行：

```shell
cjpm run
```

## 文档

- [CUI 使用指南](docs/user-guide.md)
- [CUI 组件文档](docs/components.md)
- [CUI API 文档](docs/api-reference.md)
- [SDL API 文档](sdl/docs/README.md)
- [现代 GUI 核心范式洞察辨析：函数式/对象式，立即模式/保留模式](docs/modern-GUI-insights-and-analysis.md)

## 示例应用

`examples/` 中包含 22 个可独立构建运行的演示应用：

| 示例 | 主要内容 |
|---|---|
| `calculator` | 权重网格、枚举化按键、键盘输入和数值边界保护 |
| `calendar` | 七列日历布局、日期 API、派生标题、状态导航和图像视图 |
| `command_palette` | 自动聚焦搜索、模糊过滤、应用级键盘路由与深色浮层 |
| `contacts` | 通讯录 CRM：可排序表格、组合框搜索、右键菜单、模态表单（含对话框内组合框的嵌套浮层）与校验 |
| `data_board` | 单一数据源看板、派生计数、ForEach 列表身份与筛选 |
| `data_table` | 服务器监控表：多列排序、窗口化滚动、行选择、自定义单元格负载条与派生详情 |
| `notepad` | 文本编辑、文件对话框、应用内确认条、剪贴板和拖放 |
| `notes` | 主从式笔记：`project` 双向绑定、每笔记撤销、右键菜单与删除确认 |
| `paint` | 自定义 Widget、画布绘制、事件边界处理、滑块和系统光标 |
| `planner` | 局部状态、进度条、组合框、文本换行、滚动与桌面控件 |
| `process_manager` | 后台任务、互斥邮箱、异常兜底、进程数据表格与系统信息 |
| `workbench` | 嵌套 `SplitView` 三区分栏（导航｜编辑｜信息）、可拖动/键盘微调分隔条、`derive` 派生大纲与统计 |
| `file_explorer` | `TreeView` 目录树（展开/折叠、层级图标、键盘导航）与 `SplitView` 组合的左树右详情资源管理器 |
| `booking` | `DatePicker` 月历选择器（弹出、点选/键盘、越月翻页）与 `CalendarDate` 日期运算驱动的酒店预订结算表单 |
| `editor` | `MenuBar` 应用菜单栏（多菜单、快捷键提示、分隔线、动态启用/禁用、悬停切换与键盘导航）驱动的文本编辑器 |
| `timeline` | `LazyRow` 横向虚拟化日期带（400 天只渲染视口附近、横向滚动、点选）与 `CalendarDate` 运算的时间轴 |
| `chat` | `LazyList` 变高虚拟列表（长短不一的气泡按预估高度定位、只渲染视口附近、发送滚到底部）的聊天界面 |
| `activity` | `RichText` 富文本活动流（彩色图标 + 彩色操作者/文件 + 弱化时间、长路径自动换行）与动作筛选 |
| `settings` | `Accordion` 折叠面板设置屏：外观/通知/隐私/关于分区（含真实控件）、单开模式、派生摘要 |
| `tasklist` | `ReorderableList` 拖动重排任务优先级（手柄拖动、行悬浮/让位、内容复选框照常）与派生完成计数 |
| `notify` | `Toaster`/`ToastLayer` 瞬态通知：四类通知右下角堆叠、滑入淡出、自动消失（时间动画驱动帧刷新） |
| `wizard` | `StepIndicator` 四步账户设置向导：步骤条进度/跳回、分步表单、必填校验与上一步/下一步导航 |
| `catalog` | `Pagination` 商品目录分页浏览：140 件商品每页 8 件、首末页+省略号页导航、分类过滤切换回首页 |
| `scheduler` | `TimePicker` 会议排期：时/分网格选时、实时算时长、与 `DatePicker` 并排的日程表单与排序列表 |
| `watchlist` | `Rating` 观影清单评分：逐部电影可交互圆点评分（点选/清除/键盘）、镜头绑定、实时已评数与平均分 |
| `explorer` | `Breadcrumb` 文件浏览器：面包屑路径导航（点段跳回、超长折叠省略号）、模拟目录树、点文件夹进入 |
| `tracker` | `Badge`/`Chip` 问题追踪：语义色状态/优先级徽标、成排过滤标签切换显示、镜头绑定与派生列表 |
| `goals` | `ProgressRing` 每日目标：四指标环形进度 + 总完成度环、点 +/- 调整、完成度实时派生 |

## 许可证

本项目（含 `sdl` 模块与全部示例）以 [MIT 许可证](LICENSE) 发布。
