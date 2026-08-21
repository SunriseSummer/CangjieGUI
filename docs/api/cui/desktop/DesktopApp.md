[cui](../../index.md) › [cui.desktop](index.md) › DesktopApp

# DesktopApp

`cui.desktop` 包中的 public class

桌面应用对象：拥有 SDL 窗口并运行帧循环——每帧从 [`run`](#run) 的界面构建函数重建组件树、布局、分发输入、绘制。闲置帧被跳过：只有输入、[`State`](../core/State.md) 写入、窗口缩放或组件的 `ctx.requestFrame()` 才触发渲染，时间驱动的动画必须请求帧否则冻结。

## 声明

```cangjie
public class DesktopApp
```

## 说明

帧循环统一处理焦点、悬停、连续点击和指针事件。事件先交给已打开的浮层，再进入普通组件树，因此弹出菜单和对话框不会把点击漏给下层控件；提示和浮层也绘制在普通内容之上。Tab 按组件构建顺序移动焦点，Shift+Tab 反向移动，且不会把 Tab 交给文本框。经 [`manage`](#manage) 注册的资源会在退出时按注册的相反顺序关闭，然后关闭窗口；即使组件抛出异常离开帧循环，`finally` 也会执行这套清理。内置命令行开关：`--snapshot <path.bmp>` 在界面稳定后截图并退出，供视觉测试和文档配图使用；`--profile` 输出各阶段的帧耗时。IME 候选窗会跟随聚焦文本控件报告的光标矩形。

## 示例

```cangjie verify
package docexample

import cui.*

// 完整桌面应用骨架:运行时开窗进入帧循环,关窗后 run 返回。
main(): Unit {
    let app = DesktopApp(
        WindowSpec("计数器", 360, 240),
        theme: Theme.light()
    )
    app.setMinimumSize(280, 180)
    app.run {
        let count = rememberState<Int64>("计数") {0}
        VStack(spacing: 12.vp) {
            Label("已点击 ${count.value} 次")
            Button("加一", {=> count.value = count.value + 1})
        }
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以窗口规格、主题、帧间隔、字体缩放、应用元数据与 SDL hint 创建桌面应用对象。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`manage(...)`](#manage) | 注册退出时自动关闭的资源（逆序关闭）。 |
| [`setMinimumSize(...)`](#setminimumsize) | 阻止窗口被缩小到给定逻辑尺寸以下。 |
| [`useBaseCursor(...)`](#usebasecursor) | 设置窗口的基础光标——没有控件申请其它形状时显示的形状（如绘图画布上的十字线）。 |
| [`clearRememberedState()`](#clearrememberedstate) | 在下一次重建前丢弃全部 `rememberState` 局部值。 |
| [`openFileDialog(...)`](#openfiledialog) | 发起系统"打开文件"对话框，返回可轮询的请求。 |
| [`saveFileDialog(...)`](#savefiledialog) | 发起系统"保存文件"对话框。 |
| [`openFolderDialog(...)`](#openfolderdialog) | 发起系统"选择文件夹"对话框。 |
| [`run(...)`](#run) | 进入帧循环直到窗口关闭；`body` 每渲染帧重建视图树。 |

## 构造函数

### init

以窗口规格、主题、帧间隔、字体缩放、应用元数据与 SDL hint 创建桌面应用对象。元数据与 hint 在建窗前生效。

```cangjie
public init(
    spec: WindowSpec,
    theme!: Theme = Theme.light(),
    frameDelay!: UInt32 = UInt32(16),
    fontScale!: Float32 = 1.0,
    metadata!: ?AppMetadata = None,
    hints!: Array<SdlHintSetting> = []
)
```

**参数**

- `spec`: `WindowSpec` — 标题、逻辑尺寸、DPI/垂直同步/超采样等一次性窗口选项（sdl 模块）。
- `theme!`: [`Theme`](../core/Theme.md) — 语义调色板；默认值为 `Theme.light()`。
- `frameDelay!`: `UInt32` — 每帧轮询后的等待毫秒数（帧节奏）；默认值为 `UInt32(16)`。
- `fontScale!`: `Float32` — 应用到 `fp` 长度的用户字体缩放；下限 0.1。默认 `1.0`。
- `metadata!`: `?AppMetadata` — 应用名/版本等元数据（sdl.system）。默认 `None`。
- `hints!`: `Array<SdlHintSetting>` — 建窗前应用的 SDL hint。默认空。

**异常**

- `SdlException` — 应用元数据或 SDL hint 无法应用，或者窗口、渲染器、文本输入初始化失败时；CUI 不捕获或改写该异常。

## 方法

### manage

注册退出时自动关闭的资源（逆序关闭）。

```cangjie
public func manage(resource: Resource): Unit
```

**参数**

- `resource`: `Resource` — 随应用生命周期存活的资源。

### setMinimumSize

阻止窗口被缩小到给定逻辑尺寸以下。布局不会在设计最小值以下重排，可缩放窗口应设置一个，避免内容被挤出屏幕。

```cangjie
public func setMinimumSize(width: Int32, height: Int32): Unit
```

**参数**

- `width`、`height`: `Int32` — 最小逻辑尺寸。

**异常**

- `SdlException` — SDL 拒绝设置窗口最小尺寸时；CUI 不捕获或改写该异常。

### useBaseCursor

设置窗口的基础光标——没有控件申请其它形状时显示的形状（如绘图画布上的十字线）。悬停驱动的形状（按钮上的手形、文本上的 I 形）仍叠加其上。系统无法创建所选光标时保留当前或系统默认光标，不会让应用退出。

```cangjie
public func useBaseCursor(kind: SystemCursor): Unit
```

**参数**

- `kind`: `SystemCursor` — 系统光标种类（sdl.input）。

### clearRememberedState

在下一次重建前丢弃全部 `rememberState` 局部值。

```cangjie
public func clearRememberedState(): Unit
```

### openFileDialog

发起系统"打开文件"对话框，返回可轮询的请求。对话框异步完成——在 [`FrameHandler`](../core/FrameHandler.md) 或下一帧轮询请求结果。

```cangjie
public func openFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest
```

**参数**

- `options!`: `FileDialogOptions` — 过滤器、初始目录等（sdl.dialogs）；默认值为 `FileDialogOptions()`。

**返回值** `FileDialogRequest` — 可轮询的异步请求（sdl.dialogs）。

**异常**

- `SdlException` — 文件对话框选项非法时；CUI 不捕获或改写该异常。

### saveFileDialog

发起系统"保存文件"对话框。

```cangjie
public func saveFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest
```

**参数**

- `options!`: `FileDialogOptions` — 过滤器、初始目录等；默认值为 `FileDialogOptions()`。

**返回值** `FileDialogRequest` — 可轮询的异步请求。

**异常**

- `SdlException` — 文件对话框选项非法时；CUI 不捕获或改写该异常。

### openFolderDialog

发起系统"选择文件夹"对话框。

```cangjie
public func openFolderDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest
```

**参数**

- `options!`: `FileDialogOptions` — 初始目录等文件夹选择选项；默认值为 `FileDialogOptions()`。

**返回值** `FileDialogRequest` — 可轮询的异步请求。

**异常**

- `SdlException` — 文件夹对话框选项非法时；CUI 不捕获或改写该异常。

### run

进入帧循环直到窗口关闭；`body` 每渲染帧重建视图树。`body` 内可用 [`rememberState`](../core/functions.md#rememberstate) 保留键控局部状态；退出时（含异常路径）先逆序关闭受管资源、再关窗口。

```cangjie
public func run(body: () -> Unit): Unit
```

**参数**

- `body`: `() -> Unit` — 界面构建函数，声明整个界面。

## 另请参阅

- [`UiContext`](../core/UiContext.md) — 帧循环驱动的每帧上下文。
- [`rememberState`](../core/functions.md#rememberstate) — 构建间保留的局部状态。
- `WindowSpec` / `SdlWindow`（见同版本 SDL API 参考）— 窗口层。
