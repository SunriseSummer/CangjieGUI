# stagger：交错入场（Animator / Reveal 的 delay）

一组入场卡片，集中演示动画的 `delay`（CSS `transition-delay` 的对应物）。诀窍只有一句：让第 i 行多等
`i × 步进` 毫秒。整组于是从「一起弹出」变成「依次落位的瀑布」——现代界面里最常见的入场手法之一。
每行右侧标出它等了多久，把交错的数学摆在明面上。

## 演示要点

- `Animator(value, duration!:, easing!:, delay!:)`：每次重定目标后先按住 `delay` 毫秒不动，再开始缓动
- `Reveal(shown!:, duration!:, easing!:, delay!:, content!:)`：把 delay 透传给内部 Animator，一行代码即得交错展开
- 交错 = 行号 × 步进：纯函数 `staggerDelay(index, stepMs)` 产出每行的等待，`cascadeTotalMs` 算整组耗时，均可单测
- 延迟期间动画「未静止」，故仍按帧推进（脏帧循环不会提前休眠）；延迟在每次重定目标时重置，故来回切换都会重播瀑布
- `delay` 缺省为 0，此时时间线与不带延迟完全一致（既有动画路径分毫未变，有单测逐帧比对为证）

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Item` 数据、时长/步进常量，纯函数 `staggerDelay`/`cascadeTotalMs` |
| [model.cj](src/model.cj) | `StaggerModel`：展开态、步进档位、每行延迟、状态文案 |
| [views.cj](src/views.cj) | 标题、档位/开关、逐行 Reveal 的卡片列表、状态条 |
| [theme.cj](src/theme.cj) | 浅色主题 |

## 关键实现

### 交错就是「多等一点点」

```cangjie
// 第 index 行等 index × 步进；步进为 0 即所有行同时入场。
func staggerDelay(index: Int64, stepMs: Int64): UInt64 {
    if (index <= 0 || stepMs <= 0) { return UInt64(0) }
    UInt64(index * stepMs)
}
```

视图里把它交给 Reveal 的 `delay` 即可，其余交给动画系统：

```cangjie
Reveal(shown: model.shown.value, key: "row-${i}-${model.step()}", duration: UInt64(REVEAL_MS),
       easing: Easing.EaseOutCubic, delay: model.delayFor(i)) {
    itemCard(model, i)
}
```

### 换档为何要带进 key

`Reveal` 的 `duration`/`easing`/`delay` 是在它内部的 `Animator` 首次创建时读取的（动画进度要跨帧存活，故
存在 `localState` 里，不会每帧重建）。所以换交错档位时把步进带进 `key`，让这一档拥有新身份、新 Animator。
新 Animator 以当前展开态创建即静止，故换档本身不闪动，再按一次开关就能用新节奏重播。

### 延迟不等于「静止」

延迟期间 `settled()` 为假，动画照常请求下一帧——否则脏帧循环会在延迟里睡过去，瀑布就永远等不到自己的回合。
而缺省 `delay: 0` 时整条时间线退化为原来的 `elapsed / duration`，既有动画一字未改。

## 运行

```powershell
cd examples/stagger
cjpm run
```

按「收起 / 入场」反复切换观察瀑布，用左侧三档（无 / 轻 / 明显）对比交错步进的手感差异。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot stagger.bmp"
```

首帧即静止（默认已入场），故快照稳定；要拍到瀑布中段，可临时把初始 `shown` 设为 false、用 `FrameHandler`
在首帧翻转，并调长时长/步进让快照帧落在中途。

## 练习与验收

更换步进档位再重播，确认每行延迟和整组耗时一致。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
