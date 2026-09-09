[cui](../../index.md) › [cui.core](index.md) › LazyList

# LazyList

位于 `cui.core` 包的公开类

可由高度模型或可见行自测量驱动的惰性垂直列表，是 [`LazyColumn`](LazyColumn.md) 的变高对应物。聊天气泡、评论、带折行文本的卡片这类“行高随内容”的列表，构建、布局与绘制同样只花一屏的成本。

## 声明

```cangjie
public class LazyList <: Widget
```

## 继承

LazyList <: [`Widget`](Widget.md)

## 说明

框架使用前缀和索引保存行高，因此定位行和更新单行高度都是 O(log N)。`measured` 形式只需要初始估计高度：行进入
预取范围后，框架测量其实际高度，并把本批可见行结果合并为一次更新。宽度、字体或显示环境变化会自动清除旧测量，
业务无需维护逐行高度数组。提供唯一且稳定的 key 后，插入、删除或重排还会把已测高度迁移到新索引；只有数据结构变化时
才执行一次 O(N) 重索引。

兼容的 `heightOf` 形式在未给 `revision` 时每次构建扫描全部高度，确保任意闭包变化仍正确；它也保留随滚动重建的兼容语义，因为框架无法观察闭包捕获的高度是否变化。若高度和 key 顺序在版本不变期间稳定，传 `revision` 后只在版本变化时重建索引，并像固定高度列表一样把区间内滚动降为布局变换。`State<Array<T>>`、[`LazyListExtents`](LazyListExtents.md) 与 `measured` 形式均具有可观察版本，自动使用相位分离；`LazyListExtents.update` 不扫描其余行。

`heightOf` 必须返回已存或预估高度，不能现场测量文本，并须与实际行槽一致。`measured` 行必须能在有限宽度、无界高度约束下报告有限 intrinsic height；不要把 `.fillHeight()` 或裸 `Spacer` 作为行根。像素预取、稳定 key 锚定、[`LazyViewportController`](LazyViewportController.md)、局部状态卸载和滚动条语义与 [`LazyColumn`](LazyColumn.md) 相同。

## 示例

```cangjie verify
package docexample

import cui.*

// 消息行高不一：真实应用把高度存在消息模型上，这里用奇偶模拟
func rowHeight(index: Int64): Float32 {
    if (index % 2 == 0) {
        88.0
    } else {
        44.0
    }
}

main(): Unit {
    let app = DesktopApp(WindowSpec("LazyList", 640, 420))
    app.run {
        let scroll = rememberState<Float32>("scroll") {0.0}
        let thread = LazyList(200, rowHeight, spacing: 6.0, scroll: Some(scroll), id: "thread") {
            index => Label("消息 ${index}")
        }
        // 运行时：滚动不同高度的消息列表，行由可见范围按需构建。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 索引形式：`count` 行按索引惰性构建，行高来自 `heightOf(index)`。 |
| [`init(extents, ...)`](#init-extents) | 可变 extent 模型形式：单行高度更新保持 O(log N)。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static of(...)`](#of) | 数据驱动形式：由 `Array<T>`、每条目的高度提取器与构建器建列表。 |
| [`static ofExtents(...)`](#ofextents) | 数据数组与 `LazyListExtents` 组合的高频变高形式。 |
| [`static measured(...)`](#measured) | 自测量形式：只给初始估计，不维护逐行高度模型。 |
| [`measure(...)`](#measure) | 恒占满全部可用空间：列表填满父容器分配的区域。 |
| [`layout(...)`](#layout) | 按 extent 前缀平移已物化行；可观察 extent 形式仅在越过物化边界时请求重建。 |
| [`draw(...)`](#draw) | 裁剪到视口逐行绘制，内容溢出时在右缘画滚动条。 |
| [`handle(...)`](#handle) | 滚轮滚动列表、滚动条按下/拖拽优先处理，其余事件从视觉最上层的行开始分发。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`：列表吸收所在栈的剩余空间。 |
| [`focusableIds()`](#focusableids) | 汇总当前已构建行的焦点项，只有可见行进入 Tab 遍历。 |

## 构造函数

### init

索引形式：`count` 行按索引惰性构建，行高来自 `heightOf(index)`。数据驱动的形式见 [`of`](#of)。

```cangjie
public init(
    count: Int64,
    heightOf: (Int64) -> Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((Int64) -> String) = None,
    id!: ?String = None,
    revision!: ?UInt64 = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (Int64) -> Unit
)
```

**参数**

- `count`: `Int64` — 行数；负值按 0 处理。
- `heightOf`: `(Int64) -> Float32` — 行高函数，逻辑像素；须为 O(1) 且与行槽一致，负值按 0。
- `spacing!`: `Float32` — 行间距，只存在于行与行之间；默认 `0.0`，负值按 0 处理。
- `scroll!`: `?`[`State`](State.md)`<Float32>` — 外部持有的滚动偏移；默认 `None`，由列表按 `id` 自持。
- `key!`: `?((Int64) -> String)` — 行的稳定标识函数，让行内状态跟随条目跨插入/重排；默认 `None`，按索引键控。
- `id!`: `?String` — 容器标识，界定保留的滚动与行内状态；默认 `None` 按构建顺序自动推导，显式给出时须非空。
- `revision!`: `?UInt64` — 高度与 key 顺序快照版本。`None` 每帧重扫；`Some(v)` 仅在 `v`、数量或间距变化时重建索引。
- `controller!`: `?`[`LazyViewportController`](LazyViewportController.md) — 外部滚动/按 key 定位；与 `scroll` 二选一。
- `overscan!`: `Float32` — 静止预取像素；默认 `144.0`。
- `item!`: `(Int64) -> Unit` — 行构建器，收到行索引；只对视口附近的行调用。

**异常**

- `IllegalArgumentException` — `id` 为空，或同时给出 `scroll` 与 `controller`。

### init extents

由可变 extent 模型驱动；间距属于模型，单行 `update` 后列表 O(log N) 重新定位并保持顶部 key 锚定。

```cangjie
public init(
    extents: LazyListExtents,
    scroll!: ?State<Float32> = None,
    key!: ?((Int64) -> String) = None,
    id!: ?String = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (Int64) -> Unit
)
```

## 方法

### measured

自测量形式使用 `estimatedHeight` 计算尚未出现的行；进入视口/预取区后以组件真实 intrinsic height 替换估计。一次布局中所有可见变化只发布一次，顶部稳定 key 在前序行变高时保持原屏幕位置。数据本来就在 `State<Array<T>>` 中时直接传 State：框架在一次读取中取得一致的数组/revision 快照，插入、删除或重排无需手工版本。Array 兼容形态仍需递增 `revision`。普通可见内容的 State 变化会随测量依赖自动更新，无需手工改 extent。

```cangjie
public static func measured(
    count: Int64,
    estimatedHeight!: Float32 = 64.0,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((Int64) -> String) = None,
    id!: ?String = None,
    revision!: UInt64 = 0,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (Int64) -> Unit
): LazyList

public static func measured<T>(
    data: Array<T>,
    estimatedHeight!: Float32 = 64.0,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    revision!: UInt64 = 0,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyList

public static func measured<T>(
    data: State<Array<T>>,
    estimatedHeight!: Float32 = 64.0,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyList
```

例如，消息列表可使用 72 逻辑像素估计高度、消息 ID 作为稳定 key，并为列表设置稳定 id；实际行高仍由内容测量。

估计值只影响尚未测量区域的初始滚动条和预取范围，不会强制行高。首次发现内容是否需要滚动条时最多经历“初始宽度、滚动条宽度、稳定证明”三次同帧稳定化 pass；之后稳定可见行命中缓存。精确固定高度场景继续使用开销最低的 [`LazyColumn`](LazyColumn.md)。

### of

数据驱动形式：由 `Array<T>`、每条目的高度提取器与构建器建列表。`heightOf` 须为 O(1)（存好的或预计算的高度）；`key` 给条目稳定标识，省略则按索引键控。

```cangjie
public static func of<T>(
    data: Array<T>,
    heightOf: (T) -> Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    revision!: ?UInt64 = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyList

public static func of<T>(
    data: State<Array<T>>,
    heightOf: (T) -> Float32,
    spacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyList
```

**参数**

- `data`: `Array<T>` 或 [`State`](State.md)`<Array<T>>` — 数据源；State 形态自动捕获一致的值/版本并省略 `revision`。
- `heightOf`: `(T) -> Float32` — 每条目的高度提取器，逻辑像素。
- `spacing!`: `Float32` — 行间距；默认 `0.0`。
- `scroll!`: `?`[`State`](State.md)`<Float32>` — 外部滚动偏移；默认 `None`。
- `key!`: `?((T) -> String)` — 条目的稳定标识函数；默认 `None` 按索引键控。
- `id!`: `?String` — 容器标识；默认 `None` 自动推导。
- `revision!`: `?UInt64` — 高度/key 快照版本；语义同构造函数。
- `controller!`: `?`[`LazyViewportController`](LazyViewportController.md) — 外部控制器；与 `scroll` 二选一。
- `overscan!`: `Float32` — 静止预取像素。
- `item!`: `(T) -> Unit` — 行构建器，直接收到条目。

**返回值** `LazyList` — 配置好的列表。

例如，消息模型已保存高度时，可把高度读取函数和消息 ID key 一起传给 `LazyList.of`。

### ofExtents

把数据数组与可变 extent 模型组合；两者数量必须一致，否则抛出 `IllegalArgumentException`。

```cangjie
public static func ofExtents<T>(
    data: Array<T>,
    extents: LazyListExtents,
    scroll!: ?State<Float32> = None,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    controller!: ?LazyViewportController = None,
    overscan!: Float32 = 144.0,
    item!: (T) -> Unit
): LazyList
```

### measure

恒占满全部可用空间：列表填满父容器分配的区域。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 与 `available` 相同。

### layout

记录视口高度供下一帧构建、把滚动偏移限制在有效范围，并按前缀和偏移逐行摆放已构建行。内容溢出时行宽让出右缘的滚动条车道。

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

- [LazyColumn](LazyColumn.md) — 定行高的惰性列表，语义约定的完整说明。
- [LazyRow](LazyRow.md) — 水平方向的惰性条带。
- [LazyGrid](functions.md#lazygrid) — 按行虚拟化的网格函数。
