[cui](../../index.md) › cui.testing

# cui.testing

```cangjie
import cui.testing.*
```

## 类型

| 类型 | 说明 |
|---|---|
| [`LensLawCheck`](LensLawCheck.md) | 一个具体 Lens witness 的 Get-Put、Put-Get 与 Put-Put 结果。 |
| [`PrismLawCheck`](PrismLawCheck.md) | 一个具体 Prism source/payload witness 的两个往返结果。 |
| [`RetainedTestMode`](RetainedTestMode.md) | 测试宿主的增量或强制全量 retained 执行模式。 |
| [`StateMutationPolicyLawCheck`](StateMutationPolicyLawCheck.md) | 三个样本上的策略确定性、自反、对称和传递结果。 |
| [`WidgetTestHost`](WidgetTestHost.md) | 按桌面帧事务运行构建、布局、事件、一致性重建与绘制，并可注入真实 Renderer/damage 的确定性宿主。 |
| [`TestFrameResult`](TestFrameResult.md) | 一帧产生的稳定组件树、指标与下一帧计划。 |
| [`TestFrameMetrics`](TestFrameMetrics.md) | 构建/布局/事件/绘制耗时、稳定化、文本和浮层探针。 |

## 函数

| 函数 | 说明 |
|---|---|
| [`checkLensLaws`](functions.md#checklenslaws) | 检查一个具体 Lens witness 的三定律。 |
| [`checkPrismLaws`](functions.md#checkprismlaws) | 检查一个具体 Prism witness 的两个往返律。 |
| [`checkStateMutationPolicyLaws`](functions.md#checkstatemutationpolicylaws) | 检查三个值上的策略确定性与等价关系定律。 |
