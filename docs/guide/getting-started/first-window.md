[CUI 指南](../index.md) › 第一个窗口

# 创建第一个 CUI 窗口

本课创建一个可调整大小的计数器：按钮修改状态，标签显示新值，关闭窗口后程序退出。需要了解仓颉的函数、lambda 和字符串插值。

## 准备项目

安装仓颉 SDK 1.0.5，确认 `cjpm --version` 可运行。将两个仓库与应用放在同一父目录：

```text
workspace/
├─ CangjieSDL/      # 包名 sdl；原生运行库位于 .sdl3/
├─ CangjieGUI/      # 包名 cui；依赖 ../CangjieSDL
└─ hello_cui/       # 本课创建的应用
```

在 `workspace` 中执行：

```text
cjpm init --name docexample --type=executable --path hello_cui
cd hello_cui
```

在生成的 `cjpm.toml` 中添加依赖，保留生成的 `[package]` 配置：

```toml
[dependencies]
cui = { path = "../CangjieGUI" }
```

Windows x64 可使用 CangjieSDL 的 `.sdl3/` 预置运行库。在应用目录把它加入当前终端的搜索路径：

```powershell
$sdlRuntime = (Resolve-Path ../CangjieSDL/.sdl3).Path
$env:PATH = "$sdlRuntime;$env:PATH"
```

运行需要 `SDL3.dll`、`SDL3_ttf.dll` 和 `SDL3_image.dll`。其他系统须准备匹配平台、架构的原生库，见[SDL 部署指南](../../../../CangjieSDL/docs/guide/how-to/deploy-native-runtime.md)；分发应用另见[打包桌面应用](../how-to/package-desktop-app.md)。

## 编写并运行

将 `src/main.cj` 替换为以下完整程序：

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("计数器", 360, 240))
    app.run {
        let count = rememberState<Int64>("count") {0}
        VStack(spacing: 12.vp) {
            Label("已点击 ${count.value} 次")
            Button("加一", {=> count.value = count.value + 1})
        }.padding(24.vp)
    }
}
```

在应用目录执行：

```text
cjpm build
cjpm run
```

初始标签应为“已点击 0 次”。连续点击后数字递增；调整窗口大小不重置计数；关闭窗口后终端恢复提示符。

## 理解一次点击

1. `DesktopApp` 创建窗口，负责事件循环以及构建、布局、绘制和退出清理。
2. `app.run` 的构建函数描述当前界面，可以再次执行。`rememberState` 用稳定键取回已有状态，初始值只在该状态首次创建时求值。
3. `Label` 读取 `count.value`，框架记录这项依赖；`Button` 在点击时修改同一状态。
4. 状态变化使相关界面重新构建，布局和绘制按需更新。`VStack` 只负责排列子控件。

构建函数应保持轻量。文件读取、网络请求和资源初始化不能随着每次重建重复执行；后台结果通过 `DesktopApp.post` 交回 UI 线程。

## 练习

把按钮放进 `HStack(spacing: 8.vp)`，添加“减一”按钮，两个回调共享 `count`。再添加从计数计算的“奇数／偶数”标签，避免保存第二份需要同步的状态。

验收：两个按钮均能操作，调整窗口大小后数值保持，奇偶标签始终与计数一致。

## 排错与后续阅读

- 找不到 `cui`：依赖应指向含 `cjpm.toml` 的 CangjieGUI 根目录；同时检查它的 `../CangjieSDL` 依赖。
- 启动时报 DLL 错误：检查运行库名称、架构和当前终端的 `PATH`。
- 点击后不更新或重置：确认读写同一份 `State`，且 `rememberState` 的键稳定、在当前作用域内唯一。

继续阅读[声明式构建与生命周期](../concepts/composition-and-lifecycle.md)及[状态、绑定与派生值](../concepts/state-and-binding.md)。精确接口见 [`DesktopApp`](../../api/cui/desktop/DesktopApp.md)、[`State`](../../api/cui/core/State.md) 和 [`rememberState`](../../api/cui/core/functions.md#rememberstate)。
