[cui](../../index.md) › [cui.core](index.md) › Semantics

# Semantics

位于 `cui.core` 包的公开类

平台无关的无障碍属性：标签、角色、当前值、提示、启用/选中/勾选状态。它不包含像素边界或平台对象；布局后由 [`SemanticsNode`](SemanticsNode.md) 与边界、动作组合。

```cangjie
public class Semantics
```

## 构造函数

```cangjie
public init(
    label!: String = "",
    role!: SemanticsRole = SemanticsRole.Generic,
    value!: String = "",
    hint!: String = "",
    enabled!: Bool = true,
    selected!: ?Bool = None,
    checked!: ?Bool = None
)
```

所有字段均为 public 只读。Button、Label、Checkbox、TextField 已自动生成语义；自定义组件可用 `widget.semantics(...)` 或 [`UiContext.registerSemantics`](UiContext.md#registersemantics) 注册。
