[cui](../../index.md) › [cui.core](index.md) › SemanticsChange

# SemanticsChange

无障碍 adapter 收到的确定性语义树增量。

```cangjie
public enum SemanticsChange {
    | Added(String)
    | Removed(String)
    | Updated(String)
    | Moved(String, Int64, Int64)
    | FocusChanged(String, String)
}
```

字符串是稳定语义 id；`Moved` 表示节点的声明顺序或语义父节点发生变化，两个位置分别是旧索引和新索引；
仅父节点变化时两者可以相等。`FocusChanged` 是旧/新焦点 id（空字符串表示没有焦点）。adapter 从同一
[`AccessibilityUpdate`](AccessibilityUpdate.md) 的完整快照取得最终节点数据，因此 patch 不复制属性对象。
