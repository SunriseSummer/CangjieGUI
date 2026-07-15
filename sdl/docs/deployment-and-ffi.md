# SDL 部署、动态库与 FFI 说明

## cjpm 链接配置

`sdl/cjpm.toml` 声明：

```toml
[ffi.c]
SDL3 = { path = "./.sdl3" }
SDL3_ttf = { path = "./.sdl3" }
```

路径相对于 `sdl/cjpm.toml`。当前 Windows 目录包含：

| 文件 | 用途 |
|---|---|
| `libSDL3.dll` | cjpm/cjc 使用的 SDL3 链接名称 |
| `libSDL3_ttf.dll` | cjpm/cjc 使用的 SDL3_ttf 链接名称 |
| `SDL3.dll` | Windows 运行时加载名称 |
| `SDL3_ttf.dll` | Windows 运行时加载名称 |

如果目录中同时提供 `.dll.a` 导入库，工具链可根据目标与链接器选择相应产物。

## 发布可执行文件

最稳妥的 Windows 发布结构为：

```text
application/
├── app.exe
├── SDL3.dll
└── SDL3_ttf.dll
```

也可以把 DLL 放入系统动态库搜索路径，但不建议依赖开发机的全局环境。应确保 DLL 架构与生成的
可执行文件一致，当前仓库使用 x86_64 Windows 产物。

## 字体依赖

SDL3_ttf 动态库只提供字体渲染能力，实际字体由操作系统路径加载。部署到精简系统镜像时，应确认至少
存在一个受支持字体。Windows 桌面系统通常自带 Microsoft YaHei UI 或 Segoe UI；Linux 容器可能
需要显式安装 Noto Sans CJK 或 DejaVu Sans。

## FFI 包边界

raw 文件只声明与 SDL C ABI 完全一致的函数和结构；调用代码负责：

- 将 `String` 转换成受资源托管的 `CString`。
- 校验返回指针、长度、错误码和枚举值。
- 把原始结果复制成仓颉值后再释放 SDL 内存。
- 将失败转换为 `CuiException`、`Option` 或明确的结果枚举。
- 保证 `Surface`、`Texture`、`Cursor`、窗口和字体对象确定性释放。

## raw 声明为何不集中到单一包

仓颉 1.0.5 在静态模块外部消费场景中，跨包直接引用 `foreign` 声明可能生成未解析的包符号。因此，
领域专属 raw 声明与调用它的安全封装保持在同一包，例如 `sdl.input`、`sdl.dialogs` 和
`sdl.system`。共享 C 结构保留在 `sdl` 根包。该布局不是应用 API 分层，而是工具链约束下的链接
正确性设计。

## 平台移植

移植到 macOS 或 Linux 时，需要提供与目标架构匹配的 SDL3/SDL3_ttf 动态库或共享库，并相应调整
`[ffi.c]` 路径和发布脚本。字体候选路径已经包含常见 macOS 与 Linux 位置，但应在目标发行版上运行
`sdl` 字体测试进行确认。
