[cui](../../index.md) › [cui.core](index.md) › Lens

# Lens

位于 `cui.core` 包的公开类

描述整体值 `S` 与局部值 `A` 之间的双向访问。`get` 读取局部值，`set` 用新局部值重建整体，`update` 在整体中修改
局部值；[`Bindable.project`](Bindable.md#project-with-lens) 可把 Lens 转为控件可写的 [`Binding`](Binding.md)。

## 声明

```cangjie
public class Lens<S, A>
```

## 定律

良好 Lens 应满足三条等式：

- Get-Put：`set(s, get(s)) == s`。
- Put-Get：`get(set(s, a)) == a`。
- Put-Put：`set(set(s, a1), a2) == set(s, a2)`。

框架不强制 `S`/`A` 实现 `Equatable`，因此自定义 Lens 应在模型测试中验证这些定律。`then` 保持良好 Lens 的定律并让深层字段投影不必手写嵌套更新。
测试可用 [`checkLensLaws`](../testing/functions.md#checklenslaws) 检查一组代表性的整体值和局部值。有限样本可以发现问题，
但不能证明所有输入都满足定律。

组合后的 `set` 和 `update` 从外到内读取、从内到外重建，每层最多访问一次。`get`、`set` 和变换函数都应无副作用；
其中的异常会原样传播。

## 构造函数

```cangjie
public init(get!: (S) -> A, set!: (S, A) -> S)
```

## 方法

### get

```cangjie
public func get(source: S): A
```

读取焦点值。

### set

```cangjie
public func set(source: S, value: A): S
```

围绕新焦点重建整体值。

### update

```cangjie
public func update(source: S, transform: (A) -> A): S
```

在一个整体值中修改局部值并重建整体。Reducer 的 `pullback` 和基于 Lens 的 Binding 更新也使用此操作。

### then

```cangjie
public func then<B>(next: Lens<A, B>): Lens<S, B>
```

把当前 `S → A` 投影与 `A → B` 投影组合成 `S → B`。

## 使用方式

模型包含 `name` 和 `subscribed` 时，Lens 的 `get` 返回姓名，`set` 用新姓名和原订阅状态重建模型。该 Lens 可传给
`profileState.project` 创建姓名 Binding，也可用 `update` 直接得到修改后的完整模型。

## 另请参阅

- [Bindable](Bindable.md) — 把 Lens 投影为可写 Binding。
- [Binding](Binding.md) — 供控件读写的投影视图。
