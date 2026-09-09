[cui](../../index.md) › [cui.core](index.md) › Overlay

# Overlay

位于 `cui.core` 包的公开类

浮在整棵组件树之上的交互浮层：下拉弹出面板、菜单或对话框。已打开的浮层先于树收到事件（点击与按键不会被下方控件截走），并在树之后绘制（画在最上层）。

## 声明

```cangjie
public class Overlay
```

## 说明

浮层按登记顺序叠放，事件从顶层向下派发，绘制从底层向上执行。内建控件在布局阶段调用 [`setOverlay`](UiContext.md#setoverlay)，先登记对话框，再布局并登记其中的弹出面板，因此嵌套面板位于对话框上方。宿主在布局阶段重建登记；干净的保留布局可复用登记片段，无需重新执行整棵树。

`owner` 用于跨构建识别登记者：同 `owner` 重复登记会原位替换并保持叠放位置，关闭中的控件用 [`removeOverlay`](UiContext.md#removeoverlay) 精确移除自己的登记。空 `owner` 只能追加，不能据此替换或单独移除；自定义交互浮层应提供稳定的非空标识。

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
- `render!`: `(UiContext) -> Unit` — 需要绘制时，在主树之后调用，绘制浮层内容。应把交互登记放在布局阶段，使输入与画面使用同一组浮层。
- `owner!`: `String` — 跨帧识别登记者的标识；默认空串（不可替换、不可单独移除）。

## 另请参阅

- [UiContext](UiContext.md) — 浮层栈的登记、派发与绘制入口（`setOverlay`、`dispatchOverlay`、`drawActiveOverlay`）。
- [Tooltip](Tooltip.md) — 不参与事件派发的只绘制提示浮层。
- [Modal](../controls/Modal.md) — 基于浮层实现的模态对话框控件。
