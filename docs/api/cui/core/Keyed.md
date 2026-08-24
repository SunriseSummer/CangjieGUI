[cui](../../index.md) › [cui.core](index.md) › Keyed

# Keyed

`cui.core` 包中的 public class

给子树赋予稳定声明式标识的透明包装组件：其下的局部状态键与控件交互标识都以该键为命名空间。布局、绘制与事件全部转发给子树。

## 声明

```cangjie
public class Keyed <: Widget
```

## 继承

Keyed <: [`Widget`](Widget.md)

## 说明

普通组件值可在渲染更新中重建，而 retained scope 也需要在重排/条件挂载间保持声明身份；跨帧局部状态（[`rememberState`](functions.md#rememberstate)）与控件交互标识（焦点、按下）因此都按字符串键索引。`Keyed` 打开一个标识作用域：块内 `rememberState("draft")` 的完整键以本键为命名空间，同一行构建函数因此可以被复用任意多次而互不串扰；块内控件按声明顺序自动派生的交互标识同样被隔离。

列表场景不必手写 `Keyed`：[`ForEach`](functions.md#foreach) 为每个条目声明一棵键随条目走的 `Keyed` 子树（重排、删除后状态跟随原条目），[`ForEachIndexed`](functions.md#foreachindexed) 则以位置为键。`participatesInLayout` 被转发，因此 `ForEach` 里 `.visible(false)` 的条目不会留下多余的间距空位。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Keyed", 640, 420))
    app.run {
        VStack(spacing: 12.vp) {
            Keyed("task.42") {
                let clicks = rememberState<Int64>("clicks") {0}
                Button("补充回归用例：${clicks.value}", {=> clicks.value = clicks.value + 1})
            }
            Keyed("task.77") {
                let clicks = rememberState<Int64>("clicks") {0}
                Button("整理发布说明：${clicks.value}", {=> clicks.value = clicks.value + 1})
            }
        }.padding(24.0)
        // 运行时：两行使用不同 Keyed 命名空间，各自行内状态不会串扰。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(key: String, body!: () -> Unit)`](#init) | 以键与界面构建函数块打开一个标识作用域。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 把可用空间原样转给子树并返回其测量尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把框架原样转给子树布局。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制子树。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件转发给子树并返回其结果。 |
| [`isFlexible()`](#isflexible) | 转发子树的弹性参与声明。 |
| [`flexWeight()`](#flexweight) | 转发子树声明的弹性权重。 |
| [`acceptsStretch(axis: Axis)`](#acceptsstretch) | 转发子树是否允许在给定轴上被拉伸。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子树是否占据父布局中的位置。 |
| [`focusableId()`](#focusableid) | 转发子树的单一焦点项 id。 |
| [`focusableIds()`](#focusableids) | 转发子树注册的全部焦点项。 |

## 构造函数

### init

以键与界面构建函数块打开一个标识作用域。

```cangjie
public init(key: String, body!: () -> Unit)
```

**参数**

- `key`: `String` — 作用域的命名空间；对每处使用应稳定且唯一，状态与交互标识才能跨帧、跨重排跟对子树。
- `body!`: `() -> Unit` — 界面构建函数块；块内声明多个组件时自动竖排为一个子树。

## 方法

### measure

把可用空间原样转给子树并返回其测量尺寸。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 子树的测量尺寸。

### layout

把框架原样转给子树布局。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给本包装的框架，逻辑像素。

### draw

绘制子树。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

把事件转发给子树并返回其结果。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 子树消费该事件时为 `true`。

### isFlexible

转发子树的弹性参与声明。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 子树是否参与所在栈的弹性分配。

### flexWeight

转发子树声明的弹性权重。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 子树的权重份额。

### acceptsStretch

转发子树是否允许在给定轴上被拉伸。

```cangjie
public func acceptsStretch(axis: Axis): Bool
```

**参数**

- `axis`: [`Axis`](Axis.md) — 询问的轴向。

**返回值** `Bool` — 子树允许被拉伸时为 `true`。

### participatesInLayout

转发子树是否占据父布局中的位置。`ForEach` 里 `.visible(false)` 的条目因此不留间距空位。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 子树参与布局时为 `true`。

### focusableId

转发子树的单一焦点项 id。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 子树的焦点项 id，子树不可聚焦时为 `None`。

### focusableIds

转发子树注册的全部焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 子树内全部焦点项 id，按声明顺序。

## 另请参阅

- [函数 ForEach](functions.md#foreach) — 为每个数据条目声明一棵键随条目走的 `Keyed` 子树。
- [函数 rememberState](functions.md#rememberstate) — 键在 `Keyed` 作用域下命名空间化的局部状态。
- [State](State.md) — 可观察的单一数据源状态。
