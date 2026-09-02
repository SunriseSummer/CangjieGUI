[cui](../../index.md) › cui.testing

# cui.testing

```cangjie
import cui.testing.*
```

无需创建真实窗口的测试工具。`WidgetTestHost` 按桌面应用的顺序执行构建、布局、事件、状态稳定和绘制，适合验证组件行为；定律检查函数用于验证自定义 Lens、Prism 和状态比较策略。

## 类型

| 类型 | 说明 |
|---|---|
| [`LensLawCheck`](LensLawCheck.md) | 一组代表值上的 Get-Put、Put-Get 与 Put-Put 检查结果。 |
| [`PrismLawCheck`](PrismLawCheck.md) | 一组代表值上的两个 Prism 往返检查结果。 |
| [`RetainedTestMode`](RetainedTestMode.md) | 测试宿主的增量或强制全量 retained 执行模式。 |
| [`StateMutationPolicyLawCheck`](StateMutationPolicyLawCheck.md) | 三个样本上的策略确定性、自反、对称和传递结果。 |
| [`WidgetTestHost`](WidgetTestHost.md) | 按桌面帧事务运行构建、布局、事件、一致性重建与绘制，并可注入真实 Renderer/damage 的确定性宿主。 |
| [`TestFrameResult`](TestFrameResult.md) | 一帧产生的稳定组件树、指标与下一帧计划。 |
| [`TestFrameMetrics`](TestFrameMetrics.md) | 构建/布局/事件/绘制耗时、稳定化、文本和浮层探针。 |

## 函数

| 函数 | 说明 |
|---|---|
| [`checkLensLaws`](functions.md#checklenslaws) | 用代表值检查 Lens 的三条读写规则。 |
| [`checkPrismLaws`](functions.md#checkprismlaws) | 用代表值检查 Prism 的两个往返规则。 |
| [`checkStateMutationPolicyLaws`](functions.md#checkstatemutationpolicylaws) | 检查三个值上的策略确定性与等价关系定律。 |
