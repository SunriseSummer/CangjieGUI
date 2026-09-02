[cui](../../index.md) › [cui.core](index.md) › LazyRow

# LazyRow

位于 `cui.core` 包的公开类

只构建视口附近列的定列宽水平滚动条带，是 [`LazyColumn`](LazyColumn.md) 的水平对应物。条目按索引惰性（按需）构建，上千项的胶片带以一屏的成本滚动；滚轮直接驱动水平滚动，内容溢出时底缘出现滚动条。

## 声明

```cangjie
public class LazyRow <: Widget
```

## 继承

LazyRow <: [`Widget`](Widget.md)

## 说明

可见列的物化区间与水平位移分属不同相位：区间内滚动只重新布局/绘制已有列，视口加预取首次越界时才在同帧重建一次；布局期跟踪最新 State revision，构建期提示不会冻结画面。首帧假定 720 逻辑像素，布局立即校正。预取按像素并沿滚动方向自适应扩展。只有预取范围内的条目真实存在；`key`、[`LazyViewportController`](LazyViewportController.md)、`overscan`、状态卸载与顶部（此处为左侧）锚定均与 [`LazyColumn`](LazyColumn.md) 同义。`of(State<Array<T>>, ...)` 自动从 State 的值/版本快照处理结构变化；兼容 Array 形态才需要显式 `revision`。滚轮水平分量直接驱动条带；只有垂直分量时映射到水平方向。内容溢出时底缘保留滚动条车道。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("LazyRow", 640, 420))
    app.run {
        let scroll = rememberState<Float32>("scroll") {0.0}
        let timeline = LazyRow(365, 160.0, spacing: 12.0, scroll: Some(scroll), id: "timeline") {
            index => Label("第 ${index + 1} 天")
        }
        // 运行时：使用滚轮横向浏览 365 个日期卡片，屏外项按需回收。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 索引形式：`count` 列按索引惰性构建，列宽固定。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static of(...)`](#of) | 数据驱动形式：接受 `Array<T>` 或自动版本化的 `State<Array<T>>`。 |
| [`measure(...)`](#measure) | 恒占满全部可用空间：条带填满父容器分配的区域。 |
| [`layout(...)`](#layout) | 跟踪最新水平偏移并平移已物化列；越过物化边界时请求一次稳定化重建。 |
| [`draw(...)`](#draw) | 裁剪到视口逐列绘制，内容溢出时在底缘画滚动条。 |
| [`handle(...)`](#handle) | 滚轮沿条带轴滚动（垂直滚轮自动重映射）、滚动条按下/拖拽优先处理，其余事件从视觉最上层的列开始分发。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`：条带吸收所在栈的剩余空间。 |
| [`focusableIds()`](#focusableids) | 汇总当前已构建列的焦点项，只有可见列进入 Tab 遍历。 |

## 构造函数

### init

索引形式：`count` 列按索引惰性构建，列宽固定。数据驱动的形式见 [`of`](#of)。

```cangjie
public init(
    count: Int64,
    itemWidth: Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((Int64) -> String) = None,
    id!: ?String = None,
    revision!: UInt64 = UInt64(0),
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (Int64) -> Unit
)
```

**参数**

- `count`: `Int64` — 列数；负值按 0 处理。
- `itemWidth`: `Float32` — 固定列宽，逻辑像素；下限 1。
- `spacing!`: `Float32` — 列间距，逻辑像素；默认 `0.0`，负值按 0 处理。
- `scroll!`: `?`[`State`](State.md)`<Float32>` — 外部持有的滚动偏移；默认 `None`，由条带按 `id` 自持。
- `key!`: `?((Int64) -> String)` — 条目的稳定标识函数，让条目状态跟随数据跨插入/重排；默认 `None`，按索引键控。
- `id!`: `?String` — 容器标识，界定保留的滚动与条目状态；默认 `None` 按构建顺序自动推导，显式给出时须非空。
- `revision!`: `UInt64` — key 顺序版本；结构变化时递增以保持左侧稳定 key 锚定。
- `controller!`: `?`[`LazyViewportController`](LazyViewportController.md) — 外部滚动/按 key 定位；与 `scroll` 二选一。
- `overscan!`: `Float32` — 静止预取像素；默认 `144.0`。
- `item!`: `(Int64) -> Unit` — 条目构建器，收到条目索引；只对视口附近的条目调用。

**异常**

- `IllegalArgumentException` — `id` 显式给出且为空字符串，或同时给出 `scroll` 与 `controller` 时。

## 方法

### of

数据驱动形式：由 `Array<T>` 与每条目的构建器建条带，无需手写 `count` 与按索引取数。`key` 给条目稳定标识；省略则按索引键控。

```cangjie
public static func of<T>(
    data: Array<T>,
    itemWidth: Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    revision!: UInt64 = UInt64(0),
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyRow

public static func of<T>(
    data: State<Array<T>>,
    itemWidth: Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyRow
```

**参数**

- `data`: `Array<T>` 或 [`State`](State.md)`<Array<T>>` — 数据源；State 形态自动采样同一时刻的数组与 revision。
- `itemWidth`: `Float32` — 固定列宽，逻辑像素。
- `spacing!`: `Float32` — 列间距；默认 `0.0`。
- `scroll!`: `?`[`State`](State.md)`<Float32>` — 外部滚动偏移；默认 `None`。
- `key!`: `?((T) -> String)` — 条目的稳定标识函数；默认 `None` 按索引键控。
- `id!`: `?String` — 容器标识；默认 `None` 自动推导。
- `revision!`: `UInt64` — key 顺序版本。
- `controller!`: `?`[`LazyViewportController`](LazyViewportController.md) — 外部控制器；与 `scroll` 二选一。
- `overscan!`: `Float32` — 静止预取像素。
- `item!`: `(T) -> Unit` — 条目构建器，直接收到条目。

**返回值** `LazyRow` — 配置好的条带。

例如，可把照片数组状态传给 `LazyRow.of`，设置 160 逻辑像素列宽，并用照片 ID 作为稳定 key。

### measure

恒占满全部可用空间：条带填满父容器分配的区域。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 与 `available` 相同。

### layout

跟踪最新水平偏移、限制到有效范围，并平移已物化列；视口加方向预取越过当前区间时在绘制前稳定化重建一次。内容溢出时条目高度让出底缘的滚动条车道。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

裁剪到视口逐列绘制，内容溢出时在底缘画滚动条。每列按照组件声明的 `paintOutset` 扩张裁剪范围，因此阴影等合法外溢可见，未声明的任意越界仍被截断。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

滚轮沿条带轴滚动（垂直滚轮自动重映射）、滚动条按下/拖拽优先处理，其余事件从视觉最上层的列开始分发。帧事件广播给全部已构建列且不消费；内容不足一屏时滚轮不消费、让给外层滚动容器；列内拖拽进行中允许指针越出视口继续跟踪。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 事件被条带或某个条目消费时为 `true`。

### isFlexible

恒返回 `true`：条带吸收所在栈的剩余空间。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### focusableIds

汇总当前已构建列的焦点项，只有可见列进入 Tab 遍历。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 声明顺序的焦点标识。

## 另请参阅

- [LazyColumn](LazyColumn.md) — 垂直方向的惰性列表，语义约定的完整说明。
- [LazyList](LazyList.md) — 行高逐行可变的垂直惰性列表。
- [HScrollBar](HScrollBar.md) — 条带内置使用的水平滚动条控制器。
