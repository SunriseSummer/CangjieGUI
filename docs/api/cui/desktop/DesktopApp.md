[cui](../../index.md) › [cui.desktop](index.md) › DesktopApp

# DesktopApp

位于 `cui.desktop` 包的公开类

桌面应用对象：拥有一个 SDL 窗口，并运行按需更新的事件和渲染循环。输入、状态变化、窗口变化、动画或显式帧请求会触发工作；空闲时阻塞等待。输入修改状态后，应用会在本帧绘制前完成必要的重建和布局，避免显示新旧状态混合的界面。

## 声明

```cangjie
public class DesktopApp
```

## 运行规则

- 应用统一管理焦点、悬停、连续点击、指针捕获和浮层。浮层先于普通组件树接收命中的事件。
- 除 [`post`](#post) 外，窗口、资源、文件对话框、批处理和 `run` 都只能在应用的 UI 线程调用；错误线程会抛出 `IllegalStateException`。
- 一次输入或 `post` 动作中的多次状态写入会作为一个事务提交。布局代码如果持续修改状态，应用最多在本帧尝试三轮稳定化，剩余工作留到下一帧，避免无限循环。
- 开启垂直同步时，呈现过程负责帧节奏；应用不会再叠加固定延时。
- `--profile` 输出构建、布局和绘制耗时分布、稳定化次数、触发来源、局部重绘次数和文本测量数据。

## 增量绘制

只有状态变化、没有输入、浮层或逐帧订阅的安全帧，可以只清理受影响区域并重放相交的绘制命令。输入、动画、窗口变化、根级依赖、变化区域过大或渲染器不支持时，会自动退回全帧绘制。

[`lastFrameUsedPartialDamage`](#lastframeusedpartialdamage) 返回后端最终是否采用局部重绘。`--cui-force-full-retained` 用于比较默认增量执行和强制全量执行的结果；`--cui-disable-retained-damage` 只关闭局部重绘，保留构建和绘制命令缓存。两者都是测试和排错开关，不是常规性能配置。

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
| [`setAccessibilityAdapter(...)`](#setaccessibilityadapter) | 安装平台原生或外部无障碍语义树 adapter。 |
| [`setAccessibilityFailureHandler(...)`](#setaccessibilityfailurehandler) | 安装无障碍分支故障的即时通知回调。 |
| [`takeAccessibilityFailures()`](#takeaccessibilityfailures) | 取得并清空结构化无障碍失败。 |
| [`post(...)`](#post) | 从任意线程投递短动作，并唤醒 UI 事件等待。 |
| [`clearRememberedState()`](#clearrememberedstate) | 在下一次重建前丢弃全部 `rememberState` 局部值。 |
| [`openFileDialog(...)`](#openfiledialog) | 发起系统"打开文件"对话框，返回可轮询的请求。 |
| [`saveFileDialog(...)`](#savefiledialog) | 发起系统"保存文件"对话框。 |
| [`openFolderDialog(...)`](#openfolderdialog) | 发起系统"选择文件夹"对话框。 |
| [`run(...)`](#run) | 进入帧循环直到窗口关闭；`body` 描述根界面，框架按依赖重建受影响路径。 |

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

在 UI 线程执行一个原子动作。多次状态写入只产生一次应用更新；同一状态的观察通知合并为“批次前值 → 最终值”，派生观察者在全部源稳定后运行一次。某个观察者失败不会阻止其余依赖更新，框架完成事务后再抛出最先发生的异常。嵌套 `batch` 仍由最外层统一提交。后台结果应使用 [`post`](#post)，不要跨线程调用本方法。

### retainedDiagnostics

```cangjie
public func retainedDiagnostics(): RetainedGraphDiagnostics
```

返回最近一次已提交增量执行图的结构、失效原因、各阶段依赖与命中，以及生命周期 effect 数量。应从 `FrameHandler`、事件回调或 `post` 动作调用；尚无已提交构建或从错误线程调用时抛出 `IllegalStateException`。

### lastFrameUsedPartialDamage

```cangjie
public func lastFrameUsedPartialDamage(): Bool
```

返回当前或最近完成的帧是否**实际**采用局部重绘。即使框架计算出变化区域，渲染器也可能退回全帧，此时返回 `false`。只能从 UI 线程的绘制、事件或 `post` 动作读取。该值用于性能分析和端到端断言，不应改变业务界面。

### setAccessibilityAdapter

在 UI 线程安装 [`AccessibilityAdapter`](../core/AccessibilityAdapter.md)。安装时先向新适配器发送当前完整语义树，之后只发送变化。Windows 内建的 UI Automation 仍然保留；外部适配器作为独立观察者接收相同更新，不会替换或关闭原生桥。方法也不负责关闭外部适配器。初始同步失败时只隔离该适配器，并把原异常抛给调用方。

```cangjie
public func setAccessibilityAdapter(adapter: AccessibilityAdapter): Unit
```

### setAccessibilityFailureHandler

在 UI 线程安装无障碍故障通知回调。原生桥、外部适配器和故障回调彼此隔离；某一分支失败时，其余分支和帧循环继续运行。回调与语义提交同步执行，必须快速且不能阻塞，适合记录日志或更新轻量诊断状态。回调自身失败时会被卸载，其异常仍可由 `takeAccessibilityFailures` 取得。

```cangjie
public func setAccessibilityFailureHandler(handler: (AccessibilityFailure) -> Unit): Unit
```

### takeAccessibilityFailures

返回并清空尚未取得的 [`AccessibilityFailure`](AccessibilityFailure.md)，用于测试、诊断面板或关闭后的故障汇总。
该方法只能在 DesktopApp 的 UI 线程调用；读取是破坏性的，不会重复返回同一条记录。

```cangjie
public func takeAccessibilityFailures(): Array<AccessibilityFailure>
```

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
