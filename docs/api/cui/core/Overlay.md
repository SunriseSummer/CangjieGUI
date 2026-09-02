[cui](../../index.md) › [cui.core](index.md) › Overlay

# Overlay

位于 `cui.core` 包的公开类

浮在整棵组件树之上的交互浮层：下拉弹出面板、菜单或对话框。已打开的浮层先于树收到事件（点击与按键不会被下方控件截走），并在树之后绘制（画在最上层）。

## 声明

```cangjie
public class Overlay
```

## 说明

浮层按栈管理：登记顺序即 z 顺序，事件自顶向下走栈、绘制自底向顶落笔，因此对话框内打开的弹出层浮在对话框之上、也先看到事件。控件在其 `draw` 期间调用 [`UiContext`](UiContext.md) 的 [`setOverlay`](UiContext.md#setoverlay) 登记浮层，打开多久就登记多久；宿主在每帧开始时清空浮层栈，控件停止登记（关闭）即移除了自己的浮层。

`owner` 用于跨帧识别登记者（组件树每帧重建）：同 `owner` 重复登记原位替换、保持 z 位置，关闭中的控件用 [`removeOverlay`](UiContext.md#removeoverlay) 精确移除自己的登记。`owner` 为空串的浮层无法被替换或单独移除，只随每帧清空一起消失。

与之对照，提示（[`Tooltip`](Tooltip.md)）是更简单的只绘制浮层，不参与事件派发。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let rendered = State<Bool>(false)
    let dialog = Overlay(
        handleEvent: {_, _ => true},
        render: {_ => rendered.value = true},
        owner: "settings.dialog"
    )
    ctx.setOverlay(dialog)
    ctx.drawActiveOverlay()
    println("浮层数: ${ctx.overlayCount()}，已绘制: ${rendered.value}")
    // 输出: 浮层数: 1，已绘制: true
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以事件回调、绘制回调与跨帧标识创建浮层。 |

## 构造函数

### init

以事件回调、绘制回调与跨帧标识创建浮层。两个回调分别由 [`dispatchOverlay`](UiContext.md#dispatchoverlay) 与 [`drawActiveOverlay`](UiContext.md#drawactiveoverlay) 驱动。

```cangjie
public init(handleEvent!: (UiContext, UiEvent) -> Bool, render!: (UiContext) -> Unit, owner!: String = "")
```

**参数**

- `handleEvent!`: `(UiContext, UiEvent) -> Bool` — 浮层收到事件时调用，返回是否消费。返回 `false` 让事件落往下一层浮层，全部浮层都未消费时才轮到组件树；模态对话框对一切返回 `true`，事件因此永远不会穿透到背后的树。
- `render!`: `(UiContext) -> Unit` — 每帧在树绘制之后调用，绘制浮层内容；绘制期间登记的新浮层会在同一帧内画在其上。
- `owner!`: `String` — 跨帧识别登记者的标识；默认空串（不可替换、不可单独移除）。

## 另请参阅

- [UiContext](UiContext.md) — 浮层栈的登记、派发与绘制入口（`setOverlay`、`dispatchOverlay`、`drawActiveOverlay`）。
- [Tooltip](Tooltip.md) — 不参与事件派发的只绘制提示浮层。
- [Modal](../controls/Modal.md) — 基于浮层实现的模态对话框控件。
