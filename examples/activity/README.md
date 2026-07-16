# activity：文件活动流（富文本）

一条条文件操作事件，集中演示 `RichText` 内联样式文本：每条活动把彩色图标、彩色操作者、动词、彩色文件与
弱化时间拼在一行，长路径自动换行、图标随文流动。

## 演示要点

- `RichText` 由若干 `RichSpan` 拼成：`RichSpan.icon`（内联图标）、`RichSpan.text`（默认或指定色文本）、
  `RichSpan.muted`（弱化文本）
- 每条活动一段富文本：行首按动作着色的图标 + 强调色操作者 + 常规色动词 + 动作色文件 + 弱化时间
- 图标、动词、配色都由动作类型（新建/保存/复制/删除/打开）派生，五种动作各有图标与颜色
- 长文件路径在卡片宽度内逐字符自动换行，图标与文本在同一行内流动、随换行下移
- 文本段共享同一字号、仅以颜色区分（渲染层无粗斜体，故富文本走“多色 + 内联图标”这条实现路径）
- 顶部分段控件按动作类型筛选，列表由 `filtered()` 派生；单一数据源、派生视图

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Action`/`Activity`、图标/动词/配色映射、活动种子 |
| [model.cj](src/model.cj) | `ActivityModel`：全部活动、筛选下标、`filtered()` |
| [views.cj](src/views.cj) | 抬头、动作筛选、`RichText` 活动列表 |
| [theme.cj](src/theme.cj) | 浅底 + 靛蓝强调主题与操作者色令牌 |

## 关键实现

### 一段活动即一段富文本

`RichText` 接收一串 `RichSpan`，把不同颜色的文本与内联图标拼在一起并自动换行：

```cangjie
RichText([
    RichSpan.icon(actionIcon(a.action), color: actionColor(a.action)),
    RichSpan.text("  ${a.actor} ", color: ACTIVITY_ACTOR),
    RichSpan.text("${actionVerb(a.action)} "),
    RichSpan.text(a.file, color: actionColor(a.action)),
    RichSpan.muted("    ${a.time}")
])
```

图标随文流动、文本段各自着色，长路径超出卡片宽度时逐字符换行到下一行，卡片高度随之增高。

### 单一字号、以颜色区分

渲染层只提供颜色与字号（没有粗斜体，也没有逐段基线度量），因此 `RichText` 让所有文本段共享同一字号、
只以颜色区分，再辅以内联图标——这正是本示例用彩色操作者、彩色文件与彩色图标表达层级的原因。

## 运行

```powershell
cd examples/activity
cjpm run
```

滚动查看活动，点顶部分段按动作类型筛选；留意长路径条目会换行成两行。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot activity.bmp"
```
