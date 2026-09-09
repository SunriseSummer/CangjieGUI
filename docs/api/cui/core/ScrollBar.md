[cui](../../index.md) › [cui.core](index.md) › ScrollBar

# ScrollBar

位于 `cui.core` 包的公开类

供滚动容器内部复用的垂直滚动条拖拽控制器，把命中滚动条的按下与移动转发给它，即得一致的滑块拖拽与轨道分页行为。它不是组件，不参与布局与绘制：[`ScrollView`](ScrollView.md)、[`ListView`](../controls/ListView.md)、[`TextArea`](../text/TextArea.md) 与惰性列表都各自持有一个，自绘滚动表面时同样适用。

## 声明

```cangjie
public class ScrollBar
```

## 说明

控制器以稳定的 `dragId` 键控，而拖拽的抓取点存放在 [`UiContext`](UiContext.md) 里而不是实例字段——组件可能因状态变化重新构建，抓取点保存在稳定上下文中，才能在重建后延续同一次拖拽。几何约定与绘制侧一致：轨道是贴着帧右缘内缩的固定宽度车道；滑块长度与"视口/内容"比例成正比、有 18 逻辑像素的下限；内容不超过视口时没有滑块，[`press`](#press) 直接返回 `false`。点击滑块之外的轨道空白向该方向翻一屏的 90%。滚动偏移经 [`State`](State.md)`<Float32>` 传入传出，写回时自动限制在有效范围内。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let bar = ScrollBar("目录:thumb")
    let offset = State<Float32>(0.0)
    let frame = Rect(0.0, 0.0, 300.0, 200.0) // 视口高 200，内容高 800

    // 点击滑块下方的轨道空白：向下翻一屏的 90%
    let paged = bar.press(ctx, frame, offset, 800.0, 200.0, 295.0, 150.0)
    println("分页命中: ${paged}，偏移 ${Int64(offset.value)}")
    // 输出: 分页命中: true，偏移 180

    // 按住滑块往下拖出轨道底端：偏移限制为最大值 600
    let _ = bar.press(ctx, frame, offset, 800.0, 200.0, 295.0, 60.0)
    ctx.leftMouseDown = true
    let _ = bar.drag(ctx, frame, offset, 800.0, 200.0, 200.0)
    println("拖拽中: ${bar.dragging(ctx)}，偏移 ${Int64(offset.value)}")
    // 输出: 拖拽中: true，偏移 600
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(dragId: String)`](#init) | 以稳定的拖动状态标识创建控制器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`dragging(ctx: UiContext)`](#dragging) | 判断滑块此刻是否正被拖拽，驱动滚动条的活跃高亮。 |
| [`press(...)`](#press) | 消费落在滚动条上的主键按下：命中滑块则抓取开始拖拽，命中轨道空白则向该方向分页。 |
| [`drag(...)`](#drag) | 继续一次进行中的滑块拖拽，把指针位置映射回滚动偏移。 |

## 构造函数

### init

以稳定的拖动状态标识创建控制器。控制器可能随所属声明重新构建，`dragId` 用于关联重建前后的同一次拖拽。

```cangjie
public init(dragId: String)
```

**参数**

- `dragId`: `String` — 拖动状态标识，须在整棵树内稳定且唯一（惯用形如 `"容器标识:thumb"`）。

## 方法

### dragging

判断滑块此刻是否正被拖拽，驱动滚动条的活跃高亮。

```cangjie
public func dragging(ctx: UiContext): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 持有活动拖拽记录的上下文。

**返回值** `Bool` — 本控制器的 `dragId` 是活动拖拽时为 `true`。

### press

消费落在滚动条上的主键按下：命中滑块则抓取开始拖拽，命中轨道空白则向该方向分页。抓取点（指针相对滑块顶端的偏移）记录进上下文，之后的拖拽保持在抓住的位置不跳变；分页步长为视口高度的 90%，写回的偏移限制在有效范围内。拥有者在自己的 `MouseDown` 分支里调用。

```cangjie
public func press(
    ctx: UiContext,
    frame: Rect,
    offset: State<Float32>,
    contentH: Float32,
    viewportH: Float32,
    x: Float32,
    y: Float32
): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 记录拖拽与抓取点的上下文。
- `frame`: `Rect` — 滚动表面的视口帧；轨道贴其右缘。
- `offset`: [`State`](State.md)`<Float32>` — 滚动偏移状态，分页时就地写回。
- `contentH`: `Float32` — 内容总高，逻辑像素。
- `viewportH`: `Float32` — 视口高，逻辑像素。
- `x`: `Float32` — 按下点 x。
- `y`: `Float32` — 按下点 y。

**返回值** `Bool` — 按下属于滚动条（滑块或轨道）时为 `true`；内容未溢出时恒为 `false`。

### drag

继续一次进行中的滑块拖拽，把指针位置映射回滚动偏移。只在本控制器持有活动拖拽且主键仍按住（`ctx.leftMouseDown`）时生效；映射按抓取点校正，结果限制在 `[0, 内容高 − 视口高]`。拥有者在自己的 `MouseMove` 分支里调用。

```cangjie
public func drag(
    ctx: UiContext,
    frame: Rect,
    offset: State<Float32>,
    contentH: Float32,
    viewportH: Float32,
    y: Float32
): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 持有活动拖拽与抓取点的上下文。
- `frame`: `Rect` — 滚动表面的视口帧。
- `offset`: [`State`](State.md)`<Float32>` — 滚动偏移状态，拖拽时就地写回。
- `contentH`: `Float32` — 内容总高，逻辑像素。
- `viewportH`: `Float32` — 视口高，逻辑像素。
- `y`: `Float32` — 当前指针 y。

**返回值** `Bool` — 本次移动被拖拽消费时为 `true`。

## 另请参阅

- [HScrollBar](HScrollBar.md) — 沿 x 轴的水平镜像。
- [ScrollView](ScrollView.md) — 使用本控制器的通用滚动容器。
- [UiContext](UiContext.md) — 跨帧保存拖动状态标识与抓取点的上下文。
