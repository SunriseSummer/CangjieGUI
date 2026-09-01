[cui](../../index.md) › [cui.core](index.md) › AccessibilityAdapter

# AccessibilityAdapter

平台原生无障碍桥或外部语义工具实现的 push 接口。框架只在一次完整 build/layout/事件稳定化事务完成后调用
`update`，因此适配器不会观察到中间树。首次安装会收到当前树的 bootstrap，后续只在已解析节点、顺序或状态
实际变化时收到更新。

```cangjie
public interface AccessibilityAdapter {
    func update(value: AccessibilityUpdate): Unit
}
```

回调在 UI 线程同步执行，必须尽快返回，不应阻塞平台 RPC。适配器可保存最新
[`AccessibilityUpdate`](AccessibilityUpdate.md)，并通过 `performAction` 把原生激活、聚焦、增减或设值请求路由到
最新提交目标；旧 update 也不会调用已经卸载的闭包。

`update` 抛出的异常原样传播，已提交语义树保持有效；失败 adapter 会自动脱离，避免随后每帧重复失败。安装替代
adapter 时会从这棵完整树重新 bootstrap。

用 [`UiContext.setAccessibilityAdapter`](UiContext.md#setaccessibilityadapter) 或
[`DesktopApp.setAccessibilityAdapter`](../desktop/DesktopApp.md#setaccessibilityadapter) 安装。替换适配器不会自动
关闭旧对象，资源生命周期由调用方负责。
