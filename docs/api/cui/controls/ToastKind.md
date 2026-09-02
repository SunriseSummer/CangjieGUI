[cui](../../index.md) › [cui.controls](index.md) › ToastKind

# ToastKind

位于 `cui.controls` 包的公开枚举

Toast 通知的类别，决定通知卡片左侧强调条的颜色。作为 [`Toaster.show`](Toaster.md#show) 的 `kind` 参数传入，由 [`ToastLayer`](ToastLayer.md) 渲染时取色：`Info` 用主题强调色，`Error` 用主题危险色，`Success` 与 `Warning` 用固定的绿与琥珀色。

## 声明

```cangjie
public enum ToastKind
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let toaster = Toaster()
    toaster.show("配置已保存", kind: ToastKind.Success)
    toaster.show("磁盘空间不足", kind: ToastKind.Warning, durationMs: 6000)
    println("当前通知 ${toaster.count()} 条")
    // 输出: 当前通知 2 条
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Info` | 中性信息通知，强调条用主题强调色；`Toaster.show` 的默认类别。 |
| `Success` | 成功通知，强调条用固定绿色。 |
| `Warning` | 警告通知，强调条用固定琥珀色。 |
| `Error` | 错误通知，强调条用主题危险色。 |

## 另请参阅

- [Toaster](Toaster.md) — 弹出通知的控制器。
- [ToastLayer](ToastLayer.md) — 按类别取色渲染通知的浮层。
