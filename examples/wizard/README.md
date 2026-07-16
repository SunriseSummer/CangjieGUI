# wizard：账户设置向导（步骤条）

一个四步账户设置流程，集中演示 `StepIndicator` 步骤条：进度可视、可点已完成步跳回，配合分步表单、必填校验
与上一步/下一步导航，全从单一状态派生。

## 演示要点

- `StepIndicator` 一排编号节点由连接线相连：已完成的步打勾并连线高亮、当前步高亮、未来步置灰
- 步骤条以展示为主，`current` 由底部“上一步/下一步”按钮驱动；传 `onSelect` 后点已完成的步节点可跳回
- 每一步有各自的必填校验（`stepValid`）：账户需邮箱、资料需显示名称；未通过时“下一步”自动禁用并显示提示
- 中部按当前步渲染不同表单（`TextField`/`SegmentedControl`/`Switch`），末步汇总确认已填信息
- 单一数据源：各步字段与当前步都在 model，步骤条、表单、导航按钮启用态皆由其派生
- `goTo` 只允许跳到下标 ≤ 当前步（不许跳到未来），与 `StepIndicator` 的可点范围一致

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 步骤名、主题选项、前进按钮文案 |
| [model.cj](src/model.cj) | `WizardModel`：当前步、各步字段、逐步校验、步进导航 |
| [views.cj](src/views.cj) | 步骤条、各步表单、导航栏 |
| [theme.cj](src/theme.cj) | 浅色主题与校验提示色 |

## 关键实现

### 步骤条与导航共享同一个 `current`

`StepIndicator` 只读 `current` 画进度，导航按钮改 `current`，二者共享同一状态，天然同步：

```cangjie
StepIndicator(model.steps, model.step.value, onSelect: {i => model.goTo(i)})
// 底部：Button("下一步", {=> model.next()}).enabled(model.canAdvance())
```

`onSelect` 的可点范围（下标 ≤ current）与 `goTo` 的允许范围一致，故点步节点只会跳回已完成的步。

### 逐步校验驱动按钮启用态

每一步定义自己的必填校验，`canAdvance()` 据此决定“下一步”是否可用，未通过时同时显示红色提示：

```cangjie
func stepValid(i: Int64): Bool {
    match (i) {
        case 0 => !email.value.trimAscii().isEmpty()   // 账户：邮箱必填
        case 1 => !displayName.value.trimAscii().isEmpty() // 资料：显示名称必填
        case _ => true
    }
}
```

## 运行

```powershell
cd examples/wizard
cjpm run
```

填写邮箱后“下一步”变为可用，逐步前进；点顶部已完成的步骤圆点可跳回。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot wizard.bmp"
```
