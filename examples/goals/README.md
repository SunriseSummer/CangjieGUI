# goals：每日目标（环形进度）

一个每日目标仪表盘，集中演示 `ProgressRing` 环形进度：轨道 + 顺时针进度弧 + 环心百分比，配合派生完成度
与 +/- 交互调整，各环与总完成度环实时更新。

## 演示要点

- `ProgressRing` 一圈轨道 + 从 12 点顺时针扫到当前完成度的弧（圆角折线，任意尺寸都平滑），环心显示百分比
- 四个目标各一个环（直径 88），顶部另有一个较小的总完成度环（直径 58）
- 点每张卡片的 +/- 按步长增减当前值（下限 0，超额记满环），对应环与总环随即更新
- 完成度分数（current/target 钳到 0..1）与总完成度（各分数平均）都是当前值的纯函数，每帧现算

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Goal` 类型、完成度分数、总完成度、数值更新（纯函数） |
| [model.cj](src/model.cj) | `GoalsModel`：各目标当前值；完成度与总完成度派生、+/- 增减 |
| [views.cj](src/views.cj) | 标题、总完成度环、四个目标卡（环 + 名称 + 当前/目标 + 增减按钮） |
| [theme.cj](src/theme.cj) | 浅色主题（青绿强调，进度弧用强调色） |

## 关键实现

### 完成度是当前值的纯函数

每个环的完成度分数由当前值与目标现算，视图每帧读取、随 +/- 实时更新，无缓存：

```cangjie
func goalFraction(current: Int64, target: Int64): Float32 {
    if (target <= 0) { return 0.0 }
    let f = Float32(current) / Float32(target)
    if (f > 1.0) { 1.0 } else if (f < 0.0) { 0.0 } else { f } // 超额记满环
}
```

### 进度弧是圆角折线

`ProgressRing` 无需渲染层画弧：它把弧离散成若干点、以圆角端点的 `strokeLine` 依次相连，段数随完成度自适应，
任意尺寸都平滑；总完成度环是各目标分数的平均，同一控件不同尺寸复用。

## 运行

```powershell
cd examples/goals
cjpm run
```

点各卡片的 +/- 调整当前值，对应环与顶部总完成度环随之更新。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot goals.bmp"
```
