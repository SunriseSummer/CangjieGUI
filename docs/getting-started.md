# CUI 快速入门

## 环境要求

- 仓颉 SDK 与 cjpm `1.0.5`。
- Windows x86_64，或具备兼容 SDL3/SDL3_ttf 动态库的目标平台。
- Windows 运行时需要 `SDL3.dll` 和 `SDL3_ttf.dll`。

仓库中的 `sdl/.sdl3/` 已包含 Windows 链接所需的 cjpm 名称与运行库名称。

## 创建应用

应用目录建议采用标准 cjpm 结构：

```text
hello_cui/
├── cjpm.toml
└── src/
    └── main.cj
```

`cjpm.toml`：

```toml
[package]
cjc-version = "1.0.5"
name = "hello_cui"
version = "0.1.0"
output-type = "executable"

[dependencies]
cui = { path = "../CangjieGUI" }
```

路径相对于当前应用的 `cjpm.toml`。如果 CUI 位于其他目录，应相应调整 `path`。

## 编写首个界面

`src/main.cj`：

```cangjie
package hello_cui

import cui.{Button, ButtonRole, DesktopApp, Label, LengthUnits, Panel, State, VStack, WindowSpec}

main(): Unit {
    let message = State<String>("你好，CUI")
    let app = DesktopApp(WindowSpec("首个 CUI 应用", 640, 420))

    app.run {
        VStack {
            Panel {
                Label(message.value)
            }.flexible(false)
            Button("更新文本", {=> message.value = "欢迎使用仓颉 GUI"})
                .role(ButtonRole.Primary)
                .width(180.vp)
        }.spacing(12.vp).padding(20.vp)
    }
}
```

关键点：

- `DesktopApp` 持有窗口、渲染器、主题和事件循环。
- `app.run` 的尾随 Lambda 是根视图构建函数，在需要重绘的帧重新执行（空闲帧跳过以省开销）。
- `State<String>` 位于构建闭包外，因此状态不会随控件实例重建而丢失。
- 在容器构建块中创建的控件会自动成为该容器的子项。
- 构造函数只承载文本、状态、事件等必要信息；尺寸和外观通过链式修饰器表达。
- 尺寸以“整数 + 单位”书写：导入 `LengthUnits` 后，`180.vp` 是密度无关的虚拟像素，
  `15.fp` 是跟随字体缩放的字号，`100.px` 是物理像素。
- 修饰器顺序有语义，例如 `.padding(12.vp).background(color)` 会让背景包含 padding。

## 局部状态

简单共享状态建议放在应用模型中。仅属于某个子树的临时状态可由框架跨帧保留：

```cangjie
import cui.{Keyed, LengthUnits, TextField, rememberState}

Keyed("profile.editor") {
    let nickname = rememberState<String>("nickname") { "仓颉开发者" }
    TextField(nickname, key: "profile.nickname").width(260.vp)
}
```

`Keyed` 建立稳定命名空间，`rememberState` 在子树仍挂载时复用同一状态；子树从成功构建的视图树中
消失后，对应局部状态会被清理。重复列表应使用业务主键，而不是可变化的位置索引。

## 构建与运行

```powershell
cjpm build
cjpm run
```

若在 Windows 上直接运行复制后的可执行文件，请把 `SDL3.dll` 和 `SDL3_ttf.dll` 放在可执行文件
同目录。通过 `cjpm run` 启动仓库示例时，cjpm 会使用模块声明的本地动态库路径。

## 选择主题与窗口参数

```cangjie
import cui.{DesktopApp, Theme, WindowSpec}

let app = DesktopApp(
    WindowSpec("深色界面", 960, 640, resizable: true, highDpi: true, scale: 1.0),
    theme: Theme.dark(),
    frameDelay: UInt32(16),
    fontScale: 1.0
)
app.setMinimumSize(640, 480)
```

`WindowSpec.width` 和 `height` 是逻辑尺寸；`scale` 会影响实际窗口像素、事件坐标换算与 `px`
单位的解析。`fontScale` 全局缩放所有 `fp` 尺寸。可缩放窗口建议调用 `setMinimumSize` 设置
设计最小尺寸，避免内容被挤出窗口。无明确需求时保留 `scale: 1.0`，并启用 `highDpi`。

`WindowSpec` 另有两个默认无需改动的可选项：`vsync!: Bool = true`（关闭可让帧循环不受刷新率量化，
基准测真实每帧成本时用）与 `supersample!: Int32 = 2`（每轴超采样倍数，2 为默认的 4× 抗锯齿，
软件渲染或极大窗口可降为 1 以省填充）。运行时加 `--profile` 命令行参数可打印每帧各阶段耗时，用于定位性能瓶颈。

## 下一步

- 学习状态、布局和控件组合：[CUI 使用指南](user-guide.md)。
- 查阅构造参数和方法：[CUI API 参考](api-reference.md)。
- 学习画布、窗口和系统底层能力：[SDL 文档](../sdl/docs/README.md)。
