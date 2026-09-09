# shadows：多重阴影（shadow(layers) + Shadow.keyAmbient）

一页阴影对比：`shadow(layers)` 按序叠绘多层投影，`Shadow.keyAmbient(level)` 给出 Material 式「环境光 +
方向光」双层预设。同一层级下单层与双层并排对照——单层是一团均匀的晕，双层由宽而淡的环境光叠上窄而深的
方向光，深度感来自两者的差。

## 演示要点

- `shadow(layers: Array<Shadow>[, radius!:])`：叠层投影修饰符，按数组顺序绘制（先画的在最深处），全部绘于内容之下
- `Shadow.keyAmbient(level[, color!:])`：双层预设——环境层（宽模糊、低透明、近似无方向）在前，方向层（窄模糊、较深、下坠更多）在后；`level` 与单层 `elevation` 同刻度、同钳 1..6
- 并排对比卡：两张完全相同的卡片各套单层与双层，层级由 Stepper 实时调节
- 双层阶梯 e1..e6：逐级加深的参考行
- 空层数组是安全的空操作；叠层阴影同为装饰，不改变量得尺寸

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [model.cj](src/model.cj) | `ShadowsModel`：层级状态、`clampLevel` 纯函数、状态文案 |
| [views.cj](src/views.cj) | 标题、层级调节、对比区（Grid + Panel 卡）、双层阶梯、状态条 |
| [theme.cj](src/theme.cj) | 中性浅灰主题（阴影在无彩底上最易读） |

## 关键实现

### 双层即两层普通阴影

`keyAmbient` 不引入新绘制机制，只是把业界经验参数装进一个数组，交给逐层绘制的修饰符：

```cangjie
Panel { ... }.contentPadding(18.vp, 16.vp)
    .shadow(Shadow.keyAmbient(level), radius: 12.0) // 半径与 Panel 圆角一致，晕贴角
```

自定义叠层同理：`.shadow([Shadow(color: c1, blur: 30.0), Shadow(color: c2, offsetY: 6.0, blur: 8.0)])`。

### 修饰符顺序

与单层阴影相同：`background/Panel → shadow(layers) → border`，各处传同一圆角。阴影绘于内容之前（视觉在下），
故链式顺序即层叠顺序。

## 运行

```powershell
cd examples/shadows
cjpm run
```

调层级 Stepper 对照两卡的深度感差异（层级越高差异越明显）。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot shadows.bmp"
```

## 练习与验收

用两层自定义阴影替换预设，观察层序与裁剪边界。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
