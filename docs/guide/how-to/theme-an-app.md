[CUI 指南](../index.md) › 应用主题

# 为应用建立一致主题

## 目标

使用 `Theme` 和设计令牌统一颜色、文字、间距和表面层次，同时保留控件语义角色。完成后，多个页面在浅色/深色选择下保持一致，不需要在每个按钮和面板复制颜色常量。

## 适用场景

当应用从单页扩展到设置、列表、对话框和数据工作区，开始出现重复颜色与间距时使用。若只是一个局部控件需要强调，优先使用按钮角色或局部修饰，不必为它重建整套主题。

## 准备工作

列出语义令牌：主色、危险色、成功色、背景、表面、正文、弱化文字、边框、焦点色；再列出间距、圆角和文字层级。名称描述用途，不描述某个固定十六进制值。检查项目现有主题和示例，避免创建第二套冲突命名。

## 操作步骤

### 1. 从内建主题起步

选择浅色或深色基础主题，在 `DesktopApp` 创建时传入。`Theme` 是不可变值，当前没有运行时 `setTheme` 或 copy/with API；所谓“覆盖”是构造一个完整新值并在应用启动时传入，不是运行中逐项改写。

当内建主题不能表达产品语义时，把完整构造集中在一个工厂函数中。业务页面只消费主题和角色，不复制颜色：

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

func appTheme(): Theme {
    Theme(
        bg: Color.rgb(245, 247, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(226, 230, 237),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(118, 128, 142),
        accent: Color.rgb(70, 104, 210),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(240, 243, 249),
        fieldActive: Color.rgb(226, 234, 250)
    )
}

main(): Unit {
    let app = DesktopApp(WindowSpec("主题样张", 460, 320), theme: appTheme())
    app.run {
        VStack(spacing: 12.vp) {
            Label("账户设置").bold()
            TextField(rememberState<String> {"林"})
            HStack(spacing: 8.vp) {
                Button("取消", {=> ()})
                Button("保存", {=> ()}, role: ButtonRole.Primary)
                Button("删除", {=> ()}, role: ButtonRole.Danger)
            }
        }.padding(20.vp)
    }
}
```

要比较内建深色主题，不改控件树，只把 `theme: appTheme()` 替换为 `theme: Theme.dark()`，重新启动应用。

### 2. 用角色表达动作

主要提交使用 Primary，删除使用危险语义，次要操作保持普通角色。不要在每个页面手工指定“蓝色按钮/红色按钮”；角色让主题能够统一改变外观并保留含义。

### 3. 统一表面和间距

卡片、模态、侧栏使用有限的表面层级；同级元素使用相同间距档。布局间距表达关系，主题令牌表达全局节奏。不要用随手的 13、17、23 vp 形成不可维护的视觉系统。

### 4. 检查交互状态

验证正常、悬停、按下、禁用、焦点和选中状态。深色主题特别检查弱化文字、边框和自定义图形对比。颜色不是唯一状态通道时，再辅以文字、图标或形状。

### 5. 建立样式样张

用一个独立页面展示按钮角色、文字层级、输入、面板和状态色。主题修改后先检查样张，再回归实际页面，避免只看一个幸运场景。

## 确认结果

分别以 `Theme.light()`、`Theme.dark()` 或 `appTheme()` 启动应用，打开设置表单、数据列表和模态；主要/危险动作语义一致，相同层级文字和间距一致，键盘焦点清楚可见。当前不能在同一运行中的应用热切换主题；验收是使用不同启动配置重启比较。搜索源码时，业务页面不应散落大量重复颜色常量。

## 常见错误

- 用具体颜色名当语义令牌，深色主题或品牌调整时含义失效。
- 每个页面复制一套“卡片样式”，细节逐渐分叉。
- 只检查静态画面，忽略悬停、禁用和焦点对比。
- 为所有元素加阴影和强调色，失去层级。
- 用字体缩小解决布局拥挤，破坏可读性。
- 自定义控件不读取主题，成为视觉孤岛。

## 相关 API

- [`Theme`](../../api/cui/core/Theme.md) — 应用视觉令牌与内建主题。
- [`ButtonRole`](../../api/cui/core/ButtonRole.md) 与 [`Button`](../../api/cui/core/Button.md) — 动作语义和主题外观。
- [`Panel`](../../api/cui/core/Panel.md) — 表面、边框和容器样式。
- [`Label`](../../api/cui/core/Label.md) — 文字层级与主题颜色。

## 下一步

回到[设置表单](../tutorials/settings-form.md)应用主题与按钮角色，在[任务工作台](../tutorials/task-workbench.md)统一多区域视觉，再用[键盘与焦点](keyboard-and-focus.md)检查焦点状态是否在主题变化后仍然可见。
