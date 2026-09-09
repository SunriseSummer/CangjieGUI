[cui](../../index.md) › [cui.core](index.md) › LazyColumn

# LazyColumn

位于 `cui.core` 包的公开类

只构建视口附近行的定行高垂直滚动列表，构建、布局与绘制均为 O(可见) 而非 O(行数)。行按索引惰性（按需）构建，上千行任意组件的列表以一屏的成本滚动。

## 声明

```cangjie
public class LazyColumn <: Widget
```

## 继承

LazyColumn <: [`Widget`](Widget.md)

## 说明

可见行的物化区间与滚动位移分属不同相位：区间内滚动只重新布局/绘制已有行，视口加预取首次越过区间边界时才在同帧稳定化事务中重建一次。构建期的偏移只作候选提示；布局期会跟踪并复核最新 State revision，因此不会以陈旧画面换取命中。首帧假定 720 逻辑像素的视口，布局立即校正。预取按像素计算，静止时默认前后各 144px，快速滚动时只沿前进方向扩展、最多再扩一屏；不会因行很短而过量构建，也不会因行很高而露白。

只有视口和预取范围内的行真实存在：行内局部状态（`rememberState` / [`Keyed`](Keyed.md)）随行滚出销毁，需要跨滚动存活的状态请上提到应用模型。`key` 应返回唯一、稳定的业务标识；数据由 `State<Array<T>>` 持有时优先把 State 直接传给 `of`，框架会一次采样值与版本，插入、删除或重排无需再维护平行的 revision。兼容的 `Array<T>` 重载仍要求结构变化时同步递增 `revision`。两种形式都会把原顶部 key 锚定在原像素位置。State 数据必须通过赋新数组推进版本，不能只原地改写数组元素。

滚动可由 `scroll` 或 [`LazyViewportController`](LazyViewportController.md) 二选一持有；控制器支持按当前索引或稳定 key 定位。`id` 界定内部状态作用域。内容溢出时右缘保留滚动条车道，内容不足一屏时滚轮让给外层。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("LazyColumn", 640, 420))
    app.run {
        let scroll = rememberState<Float32>("scroll") {0.0}
        let inbox = LazyColumn(1000, 48.0, spacing: 8.0, scroll: Some(scroll), id: "inbox") {
            index => Label("第 ${index} 封邮件")
        }
        // 运行时：滚动千行列表，视口只构建当前可见及预取范围内的行。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 索引形式：`count` 行按索引惰性构建，行高固定。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static of(...)`](#of) | 数据驱动形式：接受 `Array<T>` 或自动版本化的 `State<Array<T>>`。 |
| [`measure(...)`](#measure) | 恒占满全部可用空间：列表填满父容器分配的区域。 |
| [`layout(...)`](#layout) | 跟踪最新滚动偏移、限制到有效范围并平移已物化行；越过物化边界时请求一次稳定化重建。 |
| [`draw(...)`](#draw) | 裁剪到视口逐行绘制，内容溢出时在右缘画滚动条。 |
| [`handle(...)`](#handle) | 滚轮滚动列表、滚动条按下/拖拽优先处理，其余事件从视觉最上层的行开始分发。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`：列表吸收所在栈的剩余空间。 |
| [`focusableIds()`](#focusableids) | 汇总当前已构建行的焦点项，只有可见行进入 Tab 遍历。 |

## 构造函数

### init

索引形式：`count` 行按索引惰性构建，行高固定。数据驱动的形式见 [`of`](#of)。

```cangjie
public init(
    count: Int64,
    itemHeight: Float32,
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

- `count`: `Int64` — 行数；负值按 0 处理。
- `itemHeight`: `Float32` — 固定行高，逻辑像素；下限 1。
- `spacing!`: `Float32` — 行间距，逻辑像素；默认 `0.0`，负值按 0 处理。
- `scroll!`: `?`[`State`](State.md)`<Float32>` — 外部持有的滚动偏移；默认 `None`，由列表按 `id` 自持。
- `key!`: `?((Int64) -> String)` — 行的稳定标识函数，让行内状态跟随条目跨插入/重排；默认 `None`，按索引键控。
- `id!`: `?String` — 容器标识，界定保留的滚动与行内状态；默认 `None` 按构建顺序自动推导，显式给出时须非空。
- `revision!`: `UInt64` — 数据 key 顺序的版本；插入、删除或重排时递增，使顶部稳定 key 保持像素锚定。
- `controller!`: `?`[`LazyViewportController`](LazyViewportController.md) — 外部控制器；与 `scroll` 二选一。
- `overscan!`: `Float32` — 静止时前后预取的逻辑像素；负值按 0，滚动时沿前进方向自适应扩展。
- `item!`: `(Int64) -> Unit` — 行构建器，收到行索引；只对视口附近的行调用。

**异常**

- `IllegalArgumentException` — `id` 为空，或同时给出 `scroll` 与 `controller`。

## 方法

### of

数据驱动形式：由 `Array<T>` 与每条目的行构建器建列表，无需手写 `count` 与按索引取数。`key` 给条目稳定标识（行内状态与位置跟随条目跨插入/重排）；省略则按索引键控。

```cangjie
public static func of<T>(
    data: Array<T>,
    itemHeight: Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    revision!: UInt64 = UInt64(0),
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyColumn

public static func of<T>(
    data: State<Array<T>>,
    itemHeight: Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyColumn
```

**参数**

- `data`: `Array<T>` 或 [`State`](State.md)`<Array<T>>` — 数据源；State 形态原子采样数组与 revision，省略手工版本参数。
- `itemHeight`: `Float32` — 固定行高，逻辑像素。
- `spacing!`: `Float32` — 行间距；默认 `0.0`。
- `scroll!`: `?`[`State`](State.md)`<Float32>` — 外部滚动偏移；默认 `None`。
- `key!`: `?((T) -> String)` — 条目的稳定标识函数；默认 `None` 按索引键控。
- `id!`: `?String` — 容器标识；默认 `None` 自动推导。
- `revision!`: `UInt64` — 数据 key 顺序版本；结构变化时递增。
- `controller!`: `?`[`LazyViewportController`](LazyViewportController.md) — 按 key 定位或持有滚动；与 `scroll` 二选一。
- `overscan!`: `Float32` — 静止预取像素；默认 `144.0`。
- `item!`: `(T) -> Unit` — 行构建器，直接收到条目。

**返回值** `LazyColumn` — 配置好的列表。

例如，可把便笺数组状态传给 `LazyColumn.of`，设置 72 逻辑像素行高，并用便笺 ID 作为稳定 key。

### measure

恒占满全部可用空间：列表填满父容器分配的区域。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 与 `available` 相同。

### layout

跟踪最新滚动偏移、限制到有效范围，并把每个已物化行摆到内容坐标减滚动偏移的位置。视口与方向预取仍落在当前物化区间内时不执行声明体；越界时发布离散物化信号并在绘制前完成一次稳定化重建。内容溢出时行宽让出右缘的滚动条车道。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

裁剪到视口逐行绘制，内容溢出时在右缘画滚动条。每行按照组件声明的 `paintOutset` 扩张裁剪范围，因此阴影等合法外溢可见，未声明的任意越界仍被截断。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

滚轮滚动列表、滚动条按下/拖拽优先处理，其余事件从视觉最上层的行开始分发。显式传入的 `Frame` 广播给全部已构建行且不消费；内容不足一屏时滚轮不消费、让给外层滚动容器；行拖拽进行中允许指针越出视口继续跟踪。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 事件被列表或某个行消费时为 `true`。

### isFlexible

恒返回 `true`：列表吸收所在栈的剩余空间。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### focusableIds

汇总当前已构建行的焦点项，只有可见行进入 Tab 遍历。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 声明顺序的焦点标识。

桌面宿主的正常帧回调使用独立订阅表，不依赖列表逐行广播 `Frame`。

## 另请参阅

- [LazyRow](LazyRow.md) — 水平方向的惰性条带。
- [LazyList](LazyList.md) — 行高逐行可变的惰性列表。
- [LazyGrid](functions.md#lazygrid) — 在 LazyColumn 上按行虚拟化的网格函数。
- [ScrollView](ScrollView.md) — 内容不多时的非虚拟化滚动容器。
- [Keyed](Keyed.md) — 行内局部状态的键控作用域。
