# 声明式桌面 GUI 框架

基于 SDL3 图形接口，使用仓颉编程语言实现了一个自渲染、声明式的桌面 GUI 框架，提供声明式界面构建、
状态管理、常用布局容器、常用控件、文本渲染、矢量绘制以及系统能力集成等。

本项目由两个边界清晰的核心包组成：

- `sdl`：SDL/SDL_ttf 的仓颉安全封装，可脱离 CUI 单独用于游戏和图形软件等。
- `cui`：在 `sdl` 基础上实现的自渲染、声明式 GUI 框架。

<table>
    <tr>
        <td>
            <img src="https://github.com/user-attachments/assets/fa41c938-ffde-42d8-afb2-7c1df05211cb" />
        </td>
        <td>
            <img src="https://github.com/user-attachments/assets/41f355cd-25db-49b1-b9af-1bc1b01e9711" />
        </td>
    </tr>
    <tr>
        <td>
            <img src="https://github.com/user-attachments/assets/387f5237-09b4-4797-a9f4-47bda49c4f0e" />
        </td>
        <td>
            <img src="https://github.com/user-attachments/assets/0e26d146-675e-498b-beee-68ebcb2418b3" />
        </td>
    </tr>
    <tr>
        <td>
            <img src="https://github.com/user-attachments/assets/e9f40aa5-8478-416f-baaa-9f1ce5d7356f" />
        </td>
        <td>
            <img src="https://github.com/user-attachments/assets/f1624385-ae74-4c29-8a89-70bb56a1f63f" />
        </td>
    </tr>
</table>

## 核心能力

- 基于 SDL3 实现自渲染 GUI 引擎。通过 SDL3_ttf 渲染平台字体，完整支持 UTF-8 中文文本。
- 基于仓颉尾随 lambda、extend、prop 等特性构建声明式 UI 编码范式。
- 提供 `VStack`、`HStack`、`ZStack`、`Grid`、`FlowRow`、`ScrollView` 与 `Panel` 等布局容器，
  以及数据驱动、只渲染视口附近行的惰性虚拟化 `LazyColumn`/`LazyGrid`。
- 提供按钮、文本框、开关、复选框、单选框、选择器、步进器、滑块、进度条、列表、数据表格、分段控件、
  标签页、下拉和组合框等控件。
- 提供下拉/右键菜单、提示与模态对话框等浮层，浮层按栈管理、可嵌套，对话框内可继续打开下拉、组合框与右键菜单。
- 使用有顺序语义的链式修饰器配置尺寸、约束、内边距、表面、弹性、可见性和可用性，支持
  `.px`，`.vp`，`.fp` 尺寸单位表达。
- 以 `Observable`/`Bindable` 实现状态管理：可写 `State<T>`、带缓存的派生只读 `DerivedState`
  （`derive`/`map`）、双向投影 `Binding`（`project`），控件按读写需要接受对应抽象。
- 以 `Keyed`、`rememberState`、`ForEach` 明确复杂嵌套树与列表中的局部状态身份，控件交互身份按构建顺序自动唯一。
- 支持主轴/交叉轴排列、权重布局、内容自适应、流式换行、裁剪滚动和可复用组件组合。
- 文本超宽自动省略号，可选 `maxLines` 换行。
- 使用 GPU 几何图元和超采样渲染圆角、描边、图标、阴影及抗锯齿图形。
- 提供文件对话框、消息框、剪贴板、光标、显示器、文件系统、时间、系统信息等平台能力接口。

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

发布和部署基于 CUI 的桌面软件时，请确保 SDL 和 SDL_ttf 动态库位于仓颉可执行文件同目录，或在目标平台的动态库搜索路径中。

> [!WARNING]
>
> 部分 Linux 发行版上，系统 `libglib-2.0.so.0`（`SDL3_ttf` 的间接依赖）编译时链接了带
> 版本符号的 PCRE2，而仓颉运行时中的 `libpcre2-8.so.0` 不带版本符号。链接器若优先找到
> 运行时自带的 PCRE2，会出现大量 `undefined reference to ...@PCRE2_10.47` 链接错误。
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

## 示例应用

`examples/` 中包含 11 个可独立构建运行的演示应用：

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

## 许可证

本项目（含 `sdl` 模块与全部示例）以 [MIT 许可证](LICENSE) 发布。
