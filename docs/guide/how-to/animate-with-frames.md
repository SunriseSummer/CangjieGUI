<!-- kind: how-to; audience: component-author -->

# 驱动会停止的逐帧动画

## 目标

用 `Animator` 建立确定时长的动画，确认它到达目标后停止；在 GUI 中只在动画未稳定时续帧。完成约需 15 分钟。

## 适用场景

淡入、位移、颜色过渡和确定时长的状态切换使用 `Animator`；弹簧反馈使用 `Spring`；无终点的呼吸或加载指示使用 `Pulse`。计时器和后台结果轮询不属于补间动画，应直接使用按需 `FrameHandler`。

## 准备工作

先写下起点、终点、时长、是否允许中途改向以及停止条件。为“减少动态效果”确定替代行为，例如立即跳到终点。准备显式毫秒步进测试，再把同一动画器接入 GUI；这样数值错误和帧循环错误不会混在一起排查。

## 操作步骤

### 1. 先脱离 GUI 验证时间

显式 `deltaMs` 让测试不依赖机器帧率。目标变化时动画从当前值重新起步；目标相同不会不断重置。

```cangjie verify role=complete
package docexample

import cui.core.{Animator, Easing}

main(): Unit {
    let fade = Animator(0.0, duration: 250, easing: Easing.EaseInOutQuad)
    let mid = fade.animate(target: 100.0, deltaMs: 125)
    println("半程 ${Int64(mid)} 目标 ${Int64(fade.goal)}")
    let done = fade.animate(target: 100.0, deltaMs: 125)
    println("到达 ${Int64(done)} 已稳定 ${fade.settled()}")
}
```

输出应表明半程约为 50，第二步到达 100 且 `settled()` 为 `true`。这段程序可在 CI 中运行，不需要窗口或 SDL 显示环境。

### 2. 把动画器放到稳定模型

不要在构建函数里每帧 `Animator(0.0)`；那会不断回到起点。把实例放进页面模型或由稳定记忆机制持有，按钮只修改目标。

### 3. 只在运动期间续帧

动画尚未稳定时，用 `FrameHandler` 的回调调用 `model.fade.tick(info.deltaMs)`，并在子树中显示当前值；稳定后直接声明静态内容，不再挂载 FrameHandler。这样桌面循环才能回到空闲。持续循环的 `Pulse` 是例外：只在界面可见且确实需要运动时挂载，页面隐藏或“减少动态效果”开启时暂停。

## 确认结果

先运行完整控制台程序，确认输出稳定。接入 GUI 后记录静止状态 5 秒，帧报告不应持续增长；点击触发动画时才出现连续帧，到达目标后再次停止。快速反向触发时，值应从当前位置平滑改向，而不是跳回旧起点。

再用 16、33 和 100 毫秒三种步长推进同一总时长，终值都应到达目标。中间值可能因取样点不同而不同，但不能越界或永远不稳定。页面卸载后动画不再请求帧；重新进入时采用产品明确的恢复或重置策略。

## 常见错误

- 构建时创建动画器：每帧重置，永远到不了目标。
- 永久挂载 `FrameHandler`：静止页面仍满速重绘。
- 用墙钟时间写测试：慢机器上产生偶发失败。
- 把长任务进度伪装成动画：显示值与真实任务状态脱节。

## 相关 API

[Animator](../../api/cui/core/Animator.md)、[Easing](../../api/cui/core/Easing.md)、[Spring](../../api/cui/core/Spring.md)、[Pulse](../../api/cui/core/Pulse.md)、[FrameHandler](../../api/cui/core/FrameHandler.md)。

## 下一步

用[快照与帧报告](snapshot-and-profile.md)验证终态和续帧边界。
