# SDL：基于 SDL3 封装的仓颉图形引擎

`sdl` 是可独立分发和引用的仓颉静态模块，封装了 SDL3 与 SDL3_ttf 的核心能力。该模块不依赖
CUI，可用于游戏、图形工具、可视化程序、自定义 UI 框架以及其他需要底层窗口和渲染能力的场景。

## 功能范围

- 窗口创建、事件轮询、窗口状态与运行时控制。
- 点、线、矩形、圆形、圆角矩形、纹理、图像和矢量图标渲染。
- SDL3_ttf 系统 UI 字体渲染、UTF-8 测量和标准字号。
- 表面、纹理和光标的 `Resource` 生命周期管理。
- 键盘、鼠标、剪贴板、文件对话框和消息框。
- 显示器信息、文件系统、应用路径、平台信息、时间和高精度计时。

## 引用方式

在消费项目的 `cjpm.toml` 中添加：

```toml
[dependencies]
sdl = { path = "../CangjieGUI/sdl" }
```

按需显式导入包成员：

```cangjie
import sdl.{Color, FontSizes, Rect, SdlWindow, WindowSpec}
import sdl.input.{Cursor, Keyboard, Mouse}
import sdl.system.{PerformanceClock, Time}
```

完整窗口与渲染循环见 [SDL 快速入门](docs/getting-started.md)。

## 包结构

| 包 | 职责 |
|---|---|
| `sdl` | 几何、事件、窗口、渲染器、表面、纹理、图标和版本信息 |
| `sdl.dialogs` | 异步文件对话框与原生消息框 |
| `sdl.displays` | 显示器、方向、工作区和全屏模式 |
| `sdl.input` | 键盘、鼠标、光标与剪贴板 |
| `sdl.system` | 元数据、路径、文件系统、Hints、平台、时间与计时 |
| `sdl.text` | SDL3_ttf 内部文本后端，不属于应用层公共 API |

领域专属的 C ABI 声明与调用它的安全封装位于同一包。这一布局用于规避仓颉 1.0.5 静态库场景下
跨包引用 `foreign` 声明可能产生的未解析符号，同时确保 `CPointer`、`CString` 等 C 类型不会暴露给
应用层 API。

## 文档

- [SDL 文档中心](docs/README.md)
- [快速入门](docs/getting-started.md)
- [SDL 使用指南](docs/user-guide.md)
- [SDL API 参考](docs/api-reference.md)
- [部署、动态库与 FFI 说明](docs/deployment-and-ffi.md)

## 构建与测试

```powershell
cjpm build
cjpm test
```

模块从当前目录的 `.sdl3/` 加载 SDL3 与 SDL3_ttf 链接库。Windows 发布产物必须同时携带
`SDL3.dll` 和 `SDL3_ttf.dll`。
