[cui](../../index.md) › [cui.testing](index.md) › 函数

# 函数 — cui.testing

可组合状态抽象的确定性定律检查。所有入口只执行调用者提供的纯投影/比较；任一闭包抛出的异常原样传播。

### checkLensLaws

```cangjie
public func checkLensLaws<S, A>(
    lens: Lens<S, A>,
    source!: S,
    first!: A,
    second!: A
): LensLawCheck where S <: Equatable<S>, A <: Equatable<A>
```

检查一组具体输入的 Get-Put、两个 Put-Get 和 Put-Put 规则。应选择相等、不同和边界值，并在需要时结合属性测试重复执行。

例如，可传入一个资料姓名 Lens、原资料和两个候选姓名，再断言返回结果的 `isLawful()` 为 `true`。

### checkPrismLaws

```cangjie
public func checkPrismLaws<S, A>(
    prism: Prism<S, A>,
    source!: S,
    value!: A
): PrismLawCheck where S <: Equatable<S>, A <: Equatable<A>
```

检查 `extract(embed(value))` 和已命中 source 的 `embed(extract(source))` 两个往返。应分别提供命中与未命中的源样本。

### checkStateMutationPolicyLaws

```cangjie
public func checkStateMutationPolicyLaws<T>(
    policy: StateMutationPolicy<T>,
    first!: T,
    second!: T,
    third!: T
): StateMutationPolicyLawCheck
```

在三个值上构造九项有序关系矩阵，重复矩阵以检查样本确定性，再检查自反、对称以及全部传递蕴含。此函数不要求
`T` 可判等，因为判定对象正是调用方策略本身。
