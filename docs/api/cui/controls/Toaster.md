[cui](../../index.md) › [cui.controls](index.md) › Toaster

# Toaster

位于 `cui.controls` 包的公开类

瞬态 Toast 通知的调度器：保存当前仍在显示的通知及各自的剩余时间，从任意处调用 `show` 即可加入一条消息。它只负责“有哪些通知、各自还剩多久”，不负责界面；渲染与计时由组件树中的 [`ToastLayer`](ToastLayer.md) 完成。

## 声明

```cangjie
public class Toaster
```

## 说明

为应用的整个生命周期创建一个实例（通常放在模型里），视图中放一个 `ToastLayer(toaster)`。每条通知滑入、停留完自己的时长、再淡出；时钟由 `ToastLayer` 从帧循环驱动——没有 `ToastLayer` 时通知只入队不老化，`count()` 不会自行回落。Toaster 本身不是组件，不注册焦点也不占布局。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let toaster = Toaster()
    let app = DesktopApp(WindowSpec("Toaster", 520, 300))
    app.run {
        VStack(spacing: 12.vp) {
            Label("通知演示")
            Button("显示成功通知", {=> toaster.show("同步完成", kind: ToastKind.Success)})
        }.padding(24.0)
        ToastLayer(toaster)
        // 运行时：点击按钮弹出成功通知，通知在右下角显示后自动淡出。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init()`](#init) | 创建一个尚无通知的调度器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`show(message: String, kind!: ToastKind = ToastKind.Info, durationMs!: UInt64 = 3200)`](#show) | 弹出一条存活 `durationMs` 毫秒后淡出的通知。 |
| [`count()`](#count) | 当前仍在显示的通知条数。 |

## 构造函数

### init

**由编译器生成：** 仓颉会为所有实例字段均有初值且未声明构造函数的类提供该无参构造函数。

创建一个尚无通知的调度器。`show` 加入第一条通知后，`count()` 才从零增加。

```cangjie
public init()
```

## 方法

### show

弹出一条存活 `durationMs` 毫秒后淡出的通知。通知加入队尾，由 [`ToastLayer`](ToastLayer.md) 在右下角自底向上堆叠展示；可在事件回调、模型方法等任意处调用。

```cangjie
public func show(message: String, kind!: ToastKind = ToastKind.Info, durationMs!: UInt64 = 3200): Unit
```

**参数**

- `message`: `String` — 通知文本，单行显示，超出卡片宽度被裁剪。
- `kind!`: [`ToastKind`](ToastKind.md) — 通知类别，决定强调条颜色；默认 `ToastKind.Info`。
- `durationMs!`: `UInt64` — 通知的存活时长（毫秒），到期前 300 毫秒开始淡出；默认 `3200`。

### count

当前仍在显示的通知条数。包含正在滑入和淡出的通知；通知由 `ToastLayer` 计时至到期后，数量才会减少。

```cangjie
public func count(): Int64
```

**返回值** `Int64` — 当前通知数，无通知时为 0。

## 另请参阅

- [ToastLayer](ToastLayer.md) — 渲染通知并驱动其时钟的浮层组件。
- [ToastKind](ToastKind.md) — 通知类别枚举。
