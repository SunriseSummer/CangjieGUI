[cui](../../index.md) › [cui.desktop](index.md) › DesktopApp

# DesktopApp

`cui.desktop` 包中的 public class

桌面应用对象：拥有 SDL 窗口并运行按需帧循环。输入、应用内 [`State`](../core/State.md) 失效、窗口缩放、DPI/设备重置、立即续帧或定时截止触发渲染；空闲时以最长 250 ms 的有界原生等待阻塞。输入造成的状态变化会在同一帧绘制前重新构建/布局，避免混合新旧状态。

## 声明

```cangjie
public class DesktopApp
```

## 说明

帧循环统一处理焦点、悬停、连续点击和指针事件。事件先交给稳定布局登记的浮层，再进入普通组件树。除 [`post`](#post) 明确用于跨线程投递外，`DesktopApp` 的资源、窗口、对话框、批处理和 `run` API 都封闭在首次使用它们的 UI 线程；错误线程调用抛出 `IllegalStateException`。一次输入或 `post` 动作内的多次写由 [`batch`](#batch) 同类事务合并；布局若持续写状态，最多稳定化三轮并把后续工作留给下一帧，避免无限循环。开启 vsync 时呈现本身节奏控制，不再叠加固定延时。`--profile` 输出阶段均值、P50/P90/P95/P99/最大值、稳定化次数、触发来源、实际局部 damage 帧数和文本探针，并附一条可采集的 `@@FRAME_PROFILE` 键值记录。

纯 State 驱动、无交互/浮层/Frame 订阅的安全帧会消费 retained scope 的布局范围，在持久超采样目标上局部清理并
只重放相交 display list。输入、计时/动画、窗口变化、root 阶段 State、damage 过大或渲染器拒绝时自动全帧；
`lastFrameUsedPartialDamage` 报告后端实际选择。测试工具可传 `--cui-force-full-retained` 关闭所有 retained 命中，
以便与默认增量截图做正确性差分；`--cui-disable-retained-damage` 只关闭局部 damage、保留构建和命令缓存。
两个诊断开关都是排障/对照逃生口，不应作为常规性能配置。

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
| [`batch(...)`](#batch) | 在 UI 线程把多次状态写合并为一次视觉失效。 |
| [`retainedDiagnostics()`](#retaineddiagnostics) | 获取最近一次已提交 retained 执行图的结构化诊断快照。 |
| [`lastFrameUsedPartialDamage()`](#lastframeusedpartialdamage) | 查询当前/最近一帧是否被后端实际接受为局部 damage。 |
| [`post(...)`](#post) | 从任意线程投递短动作，并唤醒 UI 事件等待。 |
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
- `frameDelay!`: `UInt32` — 关闭垂直同步时立即续帧的最小帧间隔；vsync 开启时由呈现阻塞控制节奏，不再叠加该延时。默认 `16`。
- `fontScale!`: `Float32` — 应用到 `fp` 长度的用户字体缩放；下限 0.1。默认 `1.0`。
- `metadata!`: `?AppMetadata` — 应用名/版本等元数据（sdl.system）。默认 `None`。
- `hints!`: `Array<SdlHintSetting>` — 建窗前应用的 SDL hint。默认空。

**异常**

- `SdlException` — 应用元数据或 SDL hint 无法应用，或者窗口、渲染器、文本输入初始化失败时；CUI 不捕获或改写该异常。

## 方法

### manage

注册退出时自动关闭的资源（逆序关闭）。某个资源关闭失败不会阻止其余资源和窗口继续清理；全部清理完成后重新抛出首个清理异常。应用停止后调用会抛出 `IllegalStateException`。

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

### batch

```cangjie
public func batch(action: () -> Unit): Unit
```

在 UI 线程执行动作；其中的多次 `State` 写入只推进一次应用失效代数。跨线程调用会快速失败，后台结果
应使用 `post`。

### retainedDiagnostics

```cangjie
public func retainedDiagnostics(): RetainedGraphDiagnostics
```

返回最近一次已提交 retained 图的稳定结构、dirty 原因、分相依赖/命中和 effect 计数。应从 `FrameHandler`、
事件回调或 `post` 动作调用；构建尚未提交时调用抛 `IllegalStateException`，跨 UI 线程调用同样被拒绝。

### lastFrameUsedPartialDamage

```cangjie
public func lastFrameUsedPartialDamage(): Bool
```

返回当前或最近完成绘制的帧是否**实际**采用自动 retained 局部 damage。框架计划了区域但 Renderer 因没有兼容
持久目标等原因回退全帧时返回 `false`。应从 UI 线程的 widget draw、事件或 `post` 动作读取；跨线程调用被拒绝。
此值用于剖析和 E2E 断言，不应改变业务 UI。

### post

```cangjie
public func post(action: () -> Unit): Bool
```

把动作加入线程安全队列并推送 SDL 唤醒事件。动作稍后在 UI 线程事务中执行。运行中若 SDL 拒绝极少见的唤醒事件，返回 `false`，但动作仍由最长 250 ms 的有界事件等待兜底取出；应用停止后返回 `false` 且不再接收动作，已接受但尚未执行的动作会在关闭时丢弃。应用负责在退出前取消或 join 自己的工作任务。

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

进入帧循环直到窗口关闭；`body` 每渲染帧重建视图树。`body` 内可用 [`rememberState`](../core/functions.md#rememberstate) 保留键控局部状态；退出时（含异常路径）先逆序尝试关闭全部受管资源、再关窗口。一个实例只能调用一次 `run`，再次调用抛出 `IllegalStateException`；停止后其它窗口/状态操作同样拒绝执行。

```cangjie
public func run(body: () -> Unit): Unit
```

**参数**

- `body`: `() -> Unit` — 界面构建函数，声明整个界面。

## 另请参阅

- [`UiContext`](../core/UiContext.md) — 帧循环驱动的每帧上下文。
- [`rememberState`](../core/functions.md#rememberstate) — 构建间保留的局部状态。
- `WindowSpec` / `SdlWindow`（见同版本 SDL API 参考）— 窗口层。
