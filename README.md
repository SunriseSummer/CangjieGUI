# CUI：仓颉声明式桌面 GUI 框架

CUI 是一个使用仓颉语言编写的桌面图形界面框架，基于 SDL3 与 SDL3_ttf，提供声明式界面构建、
弹性布局、状态绑定、常用控件、文本编辑、矢量绘制以及桌面系统集成能力。

仓库由两个边界清晰、可独立使用的模块组成：

- `sdl`：SDL3/SDL3_ttf 的安全仓颉封装，可脱离 CUI 单独用于游戏、可视化及自定义渲染器。
- `cui`：在 `sdl` 基础上实现自渲染、声明式 GUI 框架。

## 核心能力

- 基于仓颉尾随 Lambda 等特性构建声明式 UI 编码范式。
- 提供 `VStack`、`HStack`、`Panel` 等容器组件。
- 提供按钮、复选框、滑块、进度条、列表、分段选择、标签页、文本输入和图像视图等基础控件。
- 使用 `State<T>` 驱动界面刷新，以普通 `if`、`for-in` 表达动态结构。
- 提供权重布局、内容自适应、滚动区域和可复用组件组合机制。
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

import cui.{Button, ButtonRole, DesktopApp, Insets, Label, Panel, State, VStack, WindowSpec}

main(): Unit {
    let message = State<String>("你好，CUI")
    let app = DesktopApp(WindowSpec("CUI 示例", 640, 420))

    app.run {
        VStack(spacing: 12.0, padding: Insets(20.0)) {
            Panel(flexible: false) {
                Label(message.value)
            }
            Button("更新文本", {=> message.value = "状态已更新"}, role: ButtonRole.Primary)
        }
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

`examples/` 中包含五个可独立构建运行的应用：

| 示例 | 主要内容 |
|---|---|
| `calculator` | 权重网格、派生状态、样式复用和动态科学计算行 |
| `calendar` | 七列日历布局、日期 API、状态导航和图像视图 |
| `notepad` | 文本编辑、文件对话框、消息框、剪贴板和拖放 |
| `paint` | 自定义 Widget、画布绘制、滑块和系统光标 |
| `process_manager` | 后台任务、互斥邮箱、标签页和系统信息 |

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

## 渲染与字体

CUI 将矢量图元绘制到高分辨率离屏纹理，再以线性过滤缩放到窗口，从而改善圆角、曲线和斜线边缘。
文本由 SDL3_ttf 使用真实字形度量完成排版和渲染；字体按字号缓存，中英文文本使用同一条高清渲染路径。
标准字号由 `FontSizes` 统一提供，包括说明文字、正文、控件、标题和大号展示文本。

## 设计约束

- UI 树在 UI 线程逐帧重建，耗时任务不得阻塞事件循环。
- 长时任务应通过 `spawn` 执行，并以同步保护的数据结构向 UI 帧回传结果。
- 实现 `Resource` 的对象应交由 `DesktopApp.manage` 管理，或由调用方显式关闭。
- 应用通常只需从 `cui` 根包显式导入所需 API；底层图形应用可直接依赖 `sdl`。
