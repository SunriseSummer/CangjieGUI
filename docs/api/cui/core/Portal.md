[cui](../../index.md) › [cui.core](index.md) › Portal

# Portal

`cui.core` 包中的 public class

把真实 Widget 子树声明到应用浮层平面。内容保留正常的 State、焦点、语义、事件和 retained layout 协议，但在声明位置不占版面；`placement` 返回视口绝对坐标。

```cangjie
public class Portal <: Widget
```

## 构造函数

```cangjie
public init(
    owner: String,
    open: Bool,
    placement: (UiContext) -> Rect,
    blocksInput!: Bool = false,
    body!: () -> Unit
)
```

- `owner`：跨构建稳定且非空的浮层身份。
- `open`：关闭时不执行 body、不注册浮层。
- `placement`：根据当前 viewport/context 计算绝对矩形。
- `blocksInput`：内容未消费事件时是否仍阻断其落到下层树；模态式表面设为 `true`。
- `body`：正常声明的 Widget 子树。

```cangjie
Portal("account.menu", menuOpen.value, {_ => Rect(320.0, 48.0, 180.0, 240.0)}) {
    VStack {
        Button("设置", {=> openSettings()})
        Button("退出", {=> signOut()})
    }
}
```

Portal 通过“脱离版面但仍需 layout”的协议让所有内建容器在不计尺寸/间距的前提下执行注册；自动渲染节点和修饰器会转发该协议。事件由浮层栈优先派发，离散事件事务之间仍会重建。
