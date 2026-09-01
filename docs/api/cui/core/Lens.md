[cui](../../index.md) › [cui.core](index.md) › Lens

# Lens

`cui.core` 包中的 public class

从整体值 `S` 到局部值 `A` 的可组合双向投影。`get` 读取焦点，`set` 以新焦点重建整体，`update` 把焦点端态变换
提升到整体；[`Bindable.project`](Bindable.md#project-with-lens) 可把 Lens 变成控件可写的 [`Binding`](Binding.md)。

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
测试可用 [`checkLensLaws`](../testing/functions.md#checklenslaws) 对代表 source/focus witness 输出逐律结果；有限样本用于
发现反例，不代替对全部值的数学证明。

Lens 还把 `A → A` 的端态变换保存为一等组合路径。组合后的 `set`/`update` 按从外到内读取、从内到外重建，
每层最多访问一次；不会因 `then` 深度重复读取全部前缀。`get`、`set` 与变换仍应纯净，异常会原样传播。

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

在一个整体快照上变换焦点并重建整体。对于组合 Lens，它复用融合的 endomorphism 路径；Reducer pullback 与
Lens-backed Binding 的 `update` 也使用此操作。

### then

```cangjie
public func then<B>(next: Lens<A, B>): Lens<S, B>
```

把当前 `S → A` 投影与 `A → B` 投影组合成 `S → B`。

## 示例

```cangjie
let profileName = Lens<Profile, String>(
    get: {profile => profile.name},
    set: {profile, name => Profile(name, profile.subscribed)}
)
let name = profileState.project(profileName)
let renamed = profileName.update(profile, {name => "${name}青"})
```

## 另请参阅

- [Bindable](Bindable.md) — 把 Lens 投影为可写 Binding。
- [Binding](Binding.md) — 供控件读写的投影视图。
