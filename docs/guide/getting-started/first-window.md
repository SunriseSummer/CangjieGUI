[CUI 指南](../index.md) › 第一个窗口

# 创建第一个 CUI 窗口

## 你将完成

你会从空的仓颉可执行项目创建一个标题为“计数器”的桌面窗口。窗口中显示当前点击次数和“加一”按钮；每次点击，数字立即增加，窗口保持打开直到用户正常关闭。这个结果验证真实应用生命周期、可保留状态、布局与用户事件，而不是在测试代码里手工调用控件方法。

教程先使用默认主题和一个纵向容器。窗口成功后再解释状态与构建过程；不要一开始同时加入表单、滚动、主题和浮层，否则启动失败时难以知道问题来自哪里。

## 开始之前

- 已安装仓颉 1.0.5，`cjpm --version` 可运行。
- 已取得 `cui` 源码。本例假设新项目与 `cui` 目录同级。
- Windows 运行时需要让仓库 `sdl/.sdl3` 中的 SDL3 与 SDL3_ttf DLL 位于可执行文件目录或 `PATH`。其他系统同样需要可加载的对应动态库。
- 你只需理解 `main`、lambda 和字符串插值；不需要先知道 CUI 包层次。

创建 `docexample` 可执行项目，并在 `cjpm.toml` 中写入：

```toml
[package]
cjc-version = "1.0.5"
name = "docexample"
version = "0.1.0"
output-type = "executable"

[dependencies]
cui = { path = "../cui" }
```

先执行 `cjpm build`。依赖路径错误会在构建阶段出现；动态库问题通常在启动阶段出现。把两类问题分开能减少无关修改。

## 先建立一个模型

`DesktopApp` 拥有窗口、事件循环和每一帧的构建/布局/绘制。传给 `app.run` 的函数不是只执行一次的初始化脚本，而是“当前状态下界面应该是什么样”的描述。按钮修改状态后，下一次构建读取新值，标签文字随之变化。

普通局部变量会随着构建函数重新执行而重新创建。`rememberState` 用稳定键把值保留在应用的状态存储中，所以计数不会每帧回到零。`VStack` 只负责从上到下安排子控件；它不拥有计数，也不处理点击业务。

## 操作步骤

### 1. 创建应用对象

使用 `WindowSpec` 提供标题和逻辑尺寸。逻辑像素会由运行时缩放到实际显示设备；入门阶段不需要自己换算物理像素。

### 2. 在构建函数中取得状态

调用 `rememberState<Int64>("计数") {0}`。键必须稳定且在当前构建作用域内唯一。初次访问创建值，之后构建取回同一状态。

### 3. 描述界面和动作

`Label` 读取 `count.value`，`Button` 回调只修改同一状态。不要另设一个“显示计数”变量再同步；标签每次直接从事实来源生成文字。

### 4. 运行并交给用户关闭

`app.run` 启动事件循环，直到窗口关闭才返回。构建函数中不要执行耗时网络或文件任务；这些会阻塞界面响应。

## 完整程序

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("计数器", 360, 240))
    app.run {
        let count = rememberState<Int64>("计数") {0}
        VStack(spacing: 12.vp) {
            Label("已点击 ${count.value} 次")
            Button("加一", {=> count.value = count.value + 1})
        }
    }
}
```

## 确认结果

执行 `cjpm run`。窗口标题应为“计数器”，初始文字为“已点击 0 次”。连续点击按钮后依次显示 1、2、3；调整窗口大小不会重置计数。关闭窗口后终端命令返回。

如果编译成功但启动时报 SDL3/SDL3_ttf 缺失，先修复动态库搜索路径。若点击后数字不变，确认按钮回调修改的是 `count.value`，标签也读取同一个状态。若数字每次短暂变化又归零，检查是否把状态改成了普通局部变量或使用不稳定键。

## 接着试一试

把完整程序中的单个按钮改成 `HStack(spacing: 8.vp)`，在其中放置“减一”和“加一”两个按钮；两个回调分别对同一个 `count.value` 减一、加一。
```

1. 连续执行减一、加一，让两个按钮修改同一 `count`，观察标签始终只有一个事实来源。
2. 用 `HStack` 把两个按钮并排，但保留外层 `VStack` 的标签—按钮组结构。
3. 添加一个从计数计算的文字，例如“偶数/奇数”。先直接从 `count.value` 计算，不要创建第二份需要同步的状态。

## 如果没有成功

- **构建找不到 cui**：依赖路径应指向 `cui` 项目根，不是 `src`。
- **启动时缺动态库**：把 SDL 运行库加入产物目录或系统搜索路径。
- **点击无变化**：确认回调真的写入 `count.value`，而不是只计算表达式。
- **每帧重置**：使用 `rememberState` 且键稳定唯一；不要在键中加入每次变化的文本。
- **程序像是没有返回**：窗口打开期间事件循环正在正常运行，关闭窗口后才结束。

## 相关 API

- [`DesktopApp`](../../api/cui/desktop/DesktopApp.md) — 窗口、事件循环和运行生命周期。
- [`cui` 伞包中的 WindowSpec](../../api/cui/index.md) — 窗口标题、逻辑尺寸和缩放选项。
- [`VStack`](../../api/cui/core/VStack.md) 与 [`Button`](../../api/cui/core/Button.md) — 排列与用户动作。
- [`rememberState`](../../api/cui/core/functions.md#rememberstate) 与 [`State`](../../api/cui/core/State.md) — 局部状态保留和读写。

## 下一步

继续[声明式构建与应用生命周期](../concepts/composition-and-lifecycle.md)，理解构建函数为何反复执行；再读[状态、绑定与派生值](../concepts/state-and-binding.md)，为完整表单选择正确的数据所有权。
