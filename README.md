# 声明式桌面 GUI 框架

基于 SDL3 图形接口，使用仓颉编程语言实现了一个自渲染、声明式的桌面 GUI 框架，提供声明式界面构建、
状态管理、常用布局容器、常用控件、文本渲染、矢量绘制以及系统能力集成等。

仓库由两个边界清晰、可独立使用的模块组成：

- `sdl`：SDL3/SDL3_ttf 的仓颉安全封装，可脱离 CUI 单独用于游戏和图形软件等。
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

- 基于仓颉尾随 Lambda 等特性构建声明式 UI 编码范式。
- 尺寸以“整数 + 单位”表达：`100.px`（物理像素）、`100.vp`（虚拟像素）、`15.fp`（字体像素），
  由类型系统携带单位、在布局时按窗口缩放与字体缩放解析。
- 提供 `VStack`、`HStack`、`ZStack`、`Grid`、`FlowRow`、`ScrollView` 与 `Panel` 等容器，
  以及数据驱动、只渲染视口附近行的惰性虚拟化 `LazyColumn`/`LazyGrid`（长列表与网格恒为一屏成本）。
- 使用有顺序语义的链式修饰器配置尺寸、约束、内边距、表面、弹性、可见性和可用性。
- 提供按钮、图标按钮、复选框、开关、单选项、选择器、步进器、滑块、进度条、列表、数据表格、分段控件、
  标签页、下拉、组合框和文本输入等控件，以及提示、下拉/右键菜单与模态对话框等浮层；
  浮层按栈管理、可嵌套，对话框内可继续打开下拉、组合框与右键菜单。
- 以 `Observable`/`Bindable` 组织状态：可写 `State<T>`、带缓存的派生只读 `DerivedState`
  （`derive`/`map`）、双向投影 `Binding`（`project`），控件按读写需要接受对应抽象。
- 以 `Keyed`、`rememberState`、`ForEach` 明确复杂嵌套树与列表中的局部状态身份；
  控件交互身份按构建顺序自动唯一。
- 支持主轴/交叉轴排列、权重布局、内容自适应、流式换行、裁剪滚动和可复用组件组合；
  文本超宽自动省略号，可选 `maxLines` 换行。
- 通过 SDL3_ttf 使用平台字体，完整支持 UTF-8 中文文本。
- 使用 GPU 几何图元和超采样渲染圆角、描边、图标、阴影及抗锯齿图形。
- 提供文件对话框、消息框、剪贴板、光标、显示器、文件系统、时间、系统信息等平台能力接口。

## 快速开始

在应用的 `cjpm.toml` 中声明本地依赖：

```toml
[dependencies]
cui = { path = "../CangjieGUI" }
```

创建一个最小窗口：

```cangjie
package hello_cui

import cui.{Button, ButtonRole, DesktopApp, Label, LengthUnits, Panel, State, VStack, WindowSpec}

main(): Unit {
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

在应用目录执行：

```powershell
cjpm run
```

更完整的安装、生命周期和布局说明见[快速入门](docs/getting-started.md)与
[CUI 使用指南](docs/user-guide.md)。

## 文档

- [文档中心](docs/README.md)
- [快速入门](docs/getting-started.md)
- [CUI 使用指南](docs/user-guide.md)
- [CUI API 参考](docs/api-reference.md)
- [架构与设计说明](docs/architecture.md)
- [SDL 独立模块文档](sdl/docs/README.md)
- [示例应用说明](examples/README.md)

## 示例应用

`examples/` 中包含十一个可独立构建运行的应用：

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

运行示例：

```powershell
cd examples/calendar
cjpm run
```

## 项目结构

```text
CangjieGUI/
├── cjpm.toml              # cui 模块，依赖 ./sdl
├── src/                   # cui、cui.core、controls、text、media、desktop
├── docs/                  # CUI 使用指南、API 与架构文档
├── examples/              # 独立示例应用
└── sdl/
    ├── cjpm.toml          # 可独立引用的 sdl 模块
    ├── .sdl3/             # SDL3 与 SDL3_ttf 链接库和运行库
    ├── src/               # sdl、dialogs、displays、input、system、text
    └── docs/              # SDL 使用指南、API 与部署文档
```

## 构建与测试

当前模块要求仓颉工具链 `1.0.5`。在 Windows 上，仓库已按 cjpm 链接约定放置 SDL 动态库。
分别验证底层模块与 GUI 模块：

```powershell
cd sdl
cjpm build
cjpm test

cd ..
cjpm build
cjpm test
```

发布原生可执行文件时，必须保证 `SDL3.dll` 与 `SDL3_ttf.dll` 位于可执行文件同目录，或位于
操作系统动态库搜索路径中。详细说明见 [SDL 部署与 FFI](sdl/docs/deployment-and-ffi.md)。

macOS 开发机可直接安装 Homebrew SDL，并将当前架构的动态库放入现有 FFI 搜索目录：

```bash
brew install sdl3 sdl3_ttf
cp "$(brew --prefix sdl3)/lib/libSDL3.dylib" sdl/.sdl3/
cp "$(brew --prefix sdl3_ttf)/lib/libSDL3_ttf.dylib" sdl/.sdl3/
cjpm build
cd examples/notepad
cjpm run
```

复制的 `.dylib` 已被 Git 忽略，不会替换仓库内原有的 Windows DLL。Homebrew bottle 的最低系统版本
由其构建环境决定；开发机链接运行成功不等于已生成兼容旧版 macOS 的便携发行包。

## 渲染与字体

CUI 将矢量图元绘制到高分辨率离屏纹理，再以线性过滤缩放到窗口，从而改善圆角、曲线和斜线边缘。
文本走独立于几何缩放的专用通道：字形按“字号 × 有效渲染缩放”由 FreeType 光栅化，以 1:1 缩放绘制在
对齐物理像素的坐标上——避免小尺寸字形位图被几何缩放拉伸产生的模糊；布局与光标度量取自同一份缩放
光栅化结果，与实际绘制像素严格一致。字体按“字号 × 缩放”缓存，中英文共用同一条渲染路径。
标准字号由 `FontSizes` 统一提供，包括说明文字、正文、控件、标题和大号展示文本。

## 设计约束

- UI 树在 UI 线程逐帧重建，耗时任务不得阻塞事件循环。
- 状态遵循单一事实源；共享状态向共同祖先提升，局部状态使用稳定 key 明确身份。
- 链式修饰器按源码顺序形成包装节点，调整顺序可能改变布局、绘制和命中区域。
- 长时任务应通过 `spawn` 执行，并以同步保护的数据结构向 UI 帧回传结果。
- 实现 `Resource` 的对象应交由 `DesktopApp.manage` 管理，或由调用方显式关闭。
- 应用通常只需从 `cui` 根包显式导入所需 API；底层图形应用可直接依赖 `sdl`。

## 许可证

本项目（含 `sdl` 模块与全部示例）以 [MIT 许可证](LICENSE) 发布。
