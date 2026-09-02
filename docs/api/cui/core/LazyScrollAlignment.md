[cui](../../index.md) › [cui.core](index.md) › LazyScrollAlignment

# LazyScrollAlignment

位于 `cui.core` 包的公开枚举

按稳定 key 定位时，条目在惰性视口滚动轴上的目标位置。

```cangjie
public enum LazyScrollAlignment {
    | Start
    | Center
    | End
    | Nearest
}
```

- `Start`：条目起边对齐视口起边。
- `Center`：条目居中。
- `End`：条目末边对齐视口末边。
- `Nearest`：条目已完整可见时不滚动，否则移动到最近边；默认。

最终偏移始终裁剪到内容范围。

## 另请参阅

- [LazyViewportController](LazyViewportController.md) — 通过 `scrollToIndex` 或 `scrollToKey` 使用本枚举。
