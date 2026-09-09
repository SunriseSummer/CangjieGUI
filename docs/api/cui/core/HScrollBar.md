[cui](../../index.md) › [cui.core](index.md) › HScrollBar

# HScrollBar

位于 `cui.core` 包的公开类

[`ScrollBar`](ScrollBar.md) 的水平镜像：为沿 x 轴滚动的表面提供同样的滑块拖拽与轨道分页控制器。它不是组件；[`LazyRow`](LazyRow.md) 内部用它驱动底缘滚动条，自绘的水平滚动表面同样适用。

## 声明

```cangjie
public class HScrollBar
```

## 说明

偏移数学（限制、最大偏移、滚轮步进）本身与轴向无关、两个控制器共享，只有轨道与滑块的几何互为镜像：这里的轨道是贴着帧底缘内缩的固定高度车道，滑块宽度与"视口/内容"比例成正比、有 18 逻辑像素的下限。抓取点同样存放在 [`UiContext`](UiContext.md) 里跨帧存活；点击滑块之外的轨道空白向该方向翻一屏的 90%；内容不超过视口时 [`press`](#press) 返回 `false`。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let bar = HScrollBar("胶片带:thumb")
    let offset = State<Float32>(0.0)
    let frame = Rect(0.0, 0.0, 200.0, 120.0) // 视口宽 200，内容宽 800

    // 点击滑块右侧的轨道空白：向右翻一屏的 90%
    let paged = bar.press(ctx, frame, offset, 800.0, 200.0, 150.0, 115.0)
    println("分页命中: ${paged}，偏移 ${Int64(offset.value)}")
    // 输出: 分页命中: true，偏移 180

    // 按住滑块向右拖出轨道末端：偏移限制为最大值 600
    let _ = bar.press(ctx, frame, offset, 800.0, 200.0, 50.0, 115.0)
    ctx.leftMouseDown = true
    let _ = bar.drag(ctx, frame, offset, 800.0, 200.0, 190.0)
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
| [`drag(...)`](#drag) | 继续一次进行中的滑块拖拽，把指针 x 映射回滚动偏移。 |

## 构造函数

### init

以稳定的拖动状态标识创建控制器。控制器可能随所属声明重新构建，`dragId` 用于关联重建前后的同一次拖拽。

```cangjie
public init(dragId: String)
```

**参数**

- `dragId`: `String` — 拖动状态标识，须在整棵树内稳定且唯一。

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

消费落在滚动条上的主键按下：命中滑块则抓取开始拖拽，命中轨道空白则向该方向分页。抓取点（指针相对滑块左端的偏移）记录进上下文；分页步长为视口宽度的 90%，写回的偏移限制在有效范围内。拥有者在自己的 `MouseDown` 分支里调用。

```cangjie
public func press(
    ctx: UiContext,
    frame: Rect,
    offset: State<Float32>,
    contentW: Float32,
    viewportW: Float32,
    x: Float32,
    y: Float32
): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 记录拖拽与抓取点的上下文。
- `frame`: `Rect` — 滚动表面的视口帧；轨道贴其底缘。
- `offset`: [`State`](State.md)`<Float32>` — 滚动偏移状态，分页时就地写回。
- `contentW`: `Float32` — 内容总宽，逻辑像素。
- `viewportW`: `Float32` — 视口宽，逻辑像素。
- `x`: `Float32` — 按下点 x。
- `y`: `Float32` — 按下点 y。

**返回值** `Bool` — 按下属于滚动条（滑块或轨道）时为 `true`；内容未溢出时恒为 `false`。

### drag

继续一次进行中的滑块拖拽，把指针 x 映射回滚动偏移。只在本控制器持有活动拖拽且主键仍按住（`ctx.leftMouseDown`）时生效；映射按抓取点校正，结果限制在 `[0, 内容宽 − 视口宽]`。拥有者在自己的 `MouseMove` 分支里调用。

```cangjie
public func drag(
    ctx: UiContext,
    frame: Rect,
    offset: State<Float32>,
    contentW: Float32,
    viewportW: Float32,
    x: Float32
): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 持有活动拖拽与抓取点的上下文。
- `frame`: `Rect` — 滚动表面的视口帧。
- `offset`: [`State`](State.md)`<Float32>` — 滚动偏移状态，拖拽时就地写回。
- `contentW`: `Float32` — 内容总宽，逻辑像素。
- `viewportW`: `Float32` — 视口宽，逻辑像素。
- `x`: `Float32` — 当前指针 x。

**返回值** `Bool` — 本次移动被拖拽消费时为 `true`。

## 另请参阅

- [ScrollBar](ScrollBar.md) — 垂直方向的对应控制器，几何约定的完整说明。
- [LazyRow](LazyRow.md) — 内置使用本控制器的水平惰性条带。
