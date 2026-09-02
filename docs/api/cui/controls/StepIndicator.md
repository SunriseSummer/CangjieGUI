[cui](../../index.md) › [cui.controls](index.md) › StepIndicator

# StepIndicator

位于 `cui.controls` 包的公开类

多步流程（结账、引导、向导）的横向步骤进度条：编号节点由连接线串起，`current` 之前的步骤实心打勾、当前步高亮、其后置灰。每步的标签位于对应节点下方。

## 声明

```cangjie
public class StepIndicator <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

控件以展示为先：`current` 是普通值而非绑定，由流程自己的"上一步/下一步"控件驱动。传入 `onSelect` 回调后，已到达的步骤（下标 ≤ `current`）变为可点击，用户可以跳回已完成的步骤；未到达的步骤始终不可点。控件不注册焦点项。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("StepIndicator", 640, 420))
    app.run {
        let jumped = rememberState<Int64>("jumped") {-1}
        let indicator = StepIndicator(["账户", "配置", "确认"], 1, onSelect: {step => jumped.value = step})
        // 运行时：已到达步骤可点击返回，尚未到达的步骤只展示不可点击。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(steps: Array<String>, current: Int64, onSelect!: ?(Int64) -> Unit = None, key!: ?String = None)`](#init) | 以步骤标签与当前步下标构造步骤条。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, available: Size)`](#measure) | 报告全可用宽度、固定 58 逻辑像素高的期望尺寸（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配的矩形作为节点排布与命中的基准（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 先画连接线再画节点与标签：完成段强调色、未达段中性色（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 有 `onSelect` 时，点击已到达步骤的节点触发回调（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

以步骤标签与当前步下标构造步骤条。

```cangjie
public init(steps: Array<String>, current: Int64, onSelect!: ?(Int64) -> Unit = None, key!: ?String = None)
```

**参数**

- `steps`: `Array<String>` — 各步标签，绘制在对应节点下方；空数组时不绘制任何内容。
- `current`: `Int64` — 当前步下标：其前的步骤记为已完成，其后的置灰。
- `onSelect!`: `?(Int64) -> Unit` — 点击已到达步骤（下标 ≤ `current`）时的回调，参数为被点步骤的下标；默认 `None`，所有节点不可点击。
- `key!`: `?String` — 稳定标识，须在同一次构建内唯一；默认 `None` 按声明顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

报告全可用宽度、固定 58 逻辑像素高的期望尺寸（[`Widget`](../core/Widget.md) 协议）。高度为节点圆（直径 28）加顶部留白与标签行。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级提供的可用尺寸（逻辑像素）。

**返回值** `Size` — 宽为 `available.w`、高 58 的期望尺寸。

### layout

记录分配的矩形作为节点排布与命中的基准（[`Widget`](../core/Widget.md) 协议）。节点在左右各留 44 逻辑像素后均匀分布，使两端标签有摆放空间。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 分配给控件的框架矩形（逻辑像素）。

### draw

先画连接线再画节点与标签：完成段强调色、未达段中性色（[`Widget`](../core/Widget.md) 协议）。已完成节点实心并打勾，当前节点实心显示序号，后续节点浅底描边、序号置灰；当前步标签用强调色，完成步用正文色，其余置灰。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文。

### handle

有 `onSelect` 时，点击已到达步骤的节点触发回调（[`Widget`](../core/Widget.md) 协议）。命中区是节点圆外扩 4 逻辑像素的圆域；指针悬停在可点节点上时申请交互指针形状。未传 `onSelect` 时忽略一切事件。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 点击命中了已到达步骤并触发回调时为 `true`。

## 另请参阅

- [Pagination](Pagination.md) — 平级页码导航，不表达完成进度。
- [ProgressBar](ProgressBar.md) — 连续量的进度展示。
