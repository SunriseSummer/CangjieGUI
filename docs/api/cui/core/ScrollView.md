[cui](../../index.md) › [cui.core](index.md) › ScrollView

# ScrollView

位于 `cui.core` 包的公开类

裁剪显示、支持滚轮与拖动滚动条的垂直滚动视口，滚动位置按稳定标识跨帧保留。内容以无上限高度测量出自然尺寸，超出视口的部分按当前偏移滚动显示。

## 声明

```cangjie
public class ScrollView <: Widget
```

## 继承

ScrollView <: [`Widget`](Widget.md)

## 说明

滚动偏移是距内容顶部的逻辑像素，始终被限制在 0 与最大偏移（内容高 − 视口高，不小于 0）之间；滚轮每格步进 72 逻辑像素。内容装得下时视口不拥有滚轮——事件穿透给外层滚动面，不会形成"死区"。滚动条只在内容溢出时出现：内容让出条的槽宽（10 逻辑像素）以免被遮，滑块可拖拽（记录抓取点、不跳变），点击滑块之外的轨道按 0.9 视口高分页。

偏移与滑块拖动状态标识默认由声明顺序自动派生；树的结构会变化（条件分支、动态列表）时给显式 `key!`，或用 [`scrollState`](#scrollstate) 换成外部持有的状态以便程序化滚动（如"发送后滚到底部"）。绘制在滚动轴上精确裁剪，交叉轴留出阴影余量，视口边缘卡片的软阴影不会被竖直切掉。

数据量大的列表改用惰性容器 [`LazyColumn`](LazyColumn.md)/[`LazyList`](LazyList.md)：`ScrollView` 每帧测量并布局全部内容，惰性容器只构建视口附近的行；变高内容可用 `LazyList.measured`，无需业务维护逐行高度。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ScrollView", 640, 420))
    app.run {
        let offset = rememberState<Float32>("offset") {0.0}
        let feed = ScrollView(key: "activity") {
            VStack(spacing: 0.vp) {
                for (i in 0..10) {
                    Label("动态 ${i}").height(30.0)
                }
            }
        }.scrollState(offset)
        // 运行时：滚轮滚动超出视口的活动列表，内容装得下时滚轮可继续冒泡。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(key!: ?String = None, body!: () -> Unit)`](#init) | 以可选的稳定标识与界面构建函数块创建滚动视口。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`scrollState(value: State<Float32>)`](#scrollstate) | 改用外部持有的垂直滚动偏移状态。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 原样返回可用空间：视口总是填满分到的区域。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 先用不限高度的空间测量内容；确认溢出后为滚动条留出宽度并再测量一次。 |
| [`draw(ctx: UiContext)`](#draw) | 在滚动轴上精确裁剪地绘制内容，内容溢出时再绘制滚动条。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 处理滚轮与滚动条的按下/拖拽，其余事件转发给内容并实现指针捕获。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`：滚动视口天生填满父容器分到的空间。 |
| [`focusableIds()`](#focusableids) | 转发内容子树注册的焦点项。 |

## 构造函数

### init

以可选的稳定标识与界面构建函数块创建滚动视口。标识命名滚动偏移与滑块拖动状态标识，让它们跨帧存续。

```cangjie
public init(key!: ?String = None, body!: () -> Unit)
```

**参数**

- `key!`: `?String` — 稳定标识；默认 `None`，按声明顺序自动派生（同形状的树跨帧稳定）。树的结构会变化时给显式键，滚动位置才不会串位。
- `body!`: `() -> Unit` — 界面构建函数块；块内声明多个组件时自动竖排为一个子树。

**异常**

- `IllegalArgumentException` — `key!` 传入空串时。

## 方法

### scrollState

改用外部持有的垂直滚动偏移状态。偏移为距内容顶部的逻辑像素，布局时被限制在有效区间；应用写这份状态即可程序化滚动。

```cangjie
public func scrollState(value: State<Float32>): ScrollView
```

**参数**

- `value`: [`State`](State.md)`<Float32>` — 外部拥有的偏移状态；替换掉按标识保留的内部状态。

**返回值** `ScrollView` — 本视口自身，用于链式调用。

### measure

原样返回可用空间：视口总是填满分到的区域。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 即 `available`。

### layout

先用不限高度的空间测量内容；确认溢出后为滚动条留出宽度并再测量一次。随后按限制后的偏移向上放置内容。内容变窄只会相同或更高，因此一次重测就能得到最终宽度。只有偏移真的变化时才写回状态，避免每帧布局都发出无意义的变化通知。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文。
- `rect`: `Rect` — 分配给视口的框架，逻辑像素。

### draw

在滚动轴上精确裁剪地绘制内容，内容溢出时再绘制滚动条。交叉轴留出阴影余量，视口边缘卡片的圆角软阴影不被竖直切掉；拖拽中的滑块以高亮绘制。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

处理滚轮与滚动条的按下/拖拽，其余事件转发给内容并实现指针捕获。滚轮仅在指针位于视口内且内容可滚动时消费（装得下时穿透给外层滚动面）；按在滑块上开始拖拽、按在轨道上按 0.9 视口高分页；内容里有拖拽存续时，视口外的移动与释放仍送达内容（指针捕获），否则视口外的指针事件不进入内容。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件；`MouseWheel` 的参数顺序是（滚动增量 x、滚动增量 y、指针 x、指针 y）。

**返回值** `Bool` — 事件被视口或内容消费时为 `true`。

### isFlexible

恒返回 `true`：滚动视口天生填满父容器分到的空间。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### focusableIds

转发内容子树注册的焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 内容子树内全部焦点项 id，按声明顺序。

## 另请参阅

- [ScrollBar](ScrollBar.md) — 视口复用的滑块拖拽与轨道分页控制器。
- [LazyColumn](LazyColumn.md) / [LazyList](LazyList.md) — 大数据量下只构建视口附近行的惰性容器。
- [State](State.md) — 外部滚动偏移的状态载体。
