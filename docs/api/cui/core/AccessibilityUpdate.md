[cui](../../index.md) › [cui.core](index.md) › AccessibilityUpdate

# AccessibilityUpdate

一次原子的、带 revision 的语义树 patch。

```cangjie
public class AccessibilityUpdate {
    public let previousRevision: UInt64
    public let snapshot: SemanticsSnapshot
    public let changes: Array<SemanticsChange>
    public func performAction(id: String, action: SemanticsAction): Bool
}
```

`snapshot.revision` 是提交后的版本；`previousRevision` 是适配器可用于检查漏包的前一版本。`changes` 以稳定顺序
列出 Removed，再按新树顺序列出 Added、Updated 和 Moved。属性与位置同时变化时同一 id 可同时出现 Updated 与
Moved。`performAction` 始终查询当前已提交索引，而不是捕获该 update 创建时的 Widget。
