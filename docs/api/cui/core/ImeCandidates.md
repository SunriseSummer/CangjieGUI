[cui](../../index.md) › [cui.core](index.md) › ImeCandidates

# ImeCandidates

输入法候选列表快照。输入法愿意向应用公开候选项时，自定义文本控件或诊断界面可通过 `UiContext` 读取它。

## 声明

```cangjie
public struct ImeCandidates {
    public let values: Array<String>
    public let selected: Int32
    public let horizontal: Bool
}
```

## 构造函数

```cangjie
public init(values: Array<String>, selected: Int32, horizontal: Bool)
```

- `values`：候选文本，顺序与输入法事件一致。
- `selected`：输入法报告的当前候选下标。
- `horizontal`：`true` 表示候选列表采用横向排列。

三个字段均为只读。结构体只保存平台事件快照，不校正候选下标，也不负责提交文本。

## 示例

```cangjie verify
package docexample

import cui.core.ImeCandidates

main(): Unit {
    let candidates = ImeCandidates(["你", "泥"], 0, true)
    println(candidates.values[Int64(candidates.selected)])
}
```

## 另请参阅

- [`UiContext.imeCandidates`](UiContext.md#ime-composition) — 读取当前焦点控件的候选状态。
- [`ImeComposition`](ImeComposition.md) — 尚未提交的预编辑文本。
