[cui](../../index.md) › [cui.core](index.md) › EventScope

# EventScope

位于 `cui.core` 包的公开枚举

```cangjie
public enum EventScope {
    | Subtree
    | Global
}
```

- `Subtree`：默认值；指针按布局矩形命中，键盘与文本按子树焦点命中。
- `Global`：观察宿主路由到此包装的所有输入，适合应用级快捷键与诊断，不应用来绕过控件焦点协议。

## 另请参阅

- [`EventListener`](EventListener.md)
- [`EventHandler`](EventHandler.md)
