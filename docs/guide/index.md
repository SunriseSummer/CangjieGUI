# CUI 使用指南

本指南先建立运行模型，再按具体任务讲解控件和桌面能力。初次使用按“入门路线”阅读；已有目标时直接查“任务手册”。精确签名、默认值和异常以 [API 参考](../api/index.md)为准。

## 入门路线

1. [创建第一个窗口](getting-started/first-window.md)：完成可运行的计数器，认识 `DesktopApp`、`State`、布局和事件。
2. [声明式构建与生命周期](concepts/composition-and-lifecycle.md)：理解构建函数为什么会再次执行，数据和副作用应该放在哪里。
3. [状态、绑定与派生值](concepts/state-and-binding.md)：建立单一事实来源，正确选择 `State`、`Binding` 和 `DerivedState`。
4. [设置表单教程](tutorials/settings-form.md)：把输入、校验、提交和反馈组合成完整界面。
5. [模型、动作与界面边界](concepts/app-architecture.md)：让业务规则脱离窗口独立测试，并安全接入后台工作。

完成这条路线后，再按应用类型选择后续教程：

- 数据型应用：[任务工作台](tutorials/task-workbench.md)
- 图片和自绘界面：[媒体预览面板](tutorials/media-dashboard.md)
- 自定义基础组件：[实现 Widget](how-to/custom-widget.md)

## 核心知识体系

| 主题 | 核心问题 |
|---|---|
| [构建与生命周期](concepts/composition-and-lifecycle.md) | 哪些代码可以重复执行，哪些资源必须显式管理？ |
| [状态与绑定](concepts/state-and-binding.md) | 事实存在哪里，谁可以修改，哪些值应该派生？ |
| [应用结构](concepts/app-architecture.md) | 模型、动作、视图和外部系统如何分工？ |
| [布局与滚动](concepts/layout-and-scrolling.md) | 父级约束、子级尺寸、滚动和虚拟化如何配合？ |
| [尺寸与修饰器](concepts/modifiers-and-units.md) | `px`、`vp`、`fp` 怎样选择，链式顺序为何重要？ |
| [焦点、事件与浮层](concepts/focus-events-and-overlays.md) | 指针、键盘、快捷键、模态框和菜单如何路由？ |
| [动画与帧预算](concepts/animation-and-frame-budget.md) | 何时请求下一帧，怎样避免静止界面持续刷新？ |
| [媒体与资源](concepts/resources-and-media.md) | 图片缓存、文件和长期资源由谁创建、关闭？ |

可以把它们记成一条主线：

> 状态变化 → 相关声明重新构建 → 必要的布局和绘制执行 → 事件继续修改状态。

CUI 会自动记录状态读取并跳过未受影响的工作。应用代码仍应保持构建函数轻量、状态所有权明确、动态项目身份稳定。

## 任务手册

### 布局与数据展示

- [选择布局容器](how-to/choose-layout.md)
- [构建稳定身份的数据列表](how-to/data-list.md)
- [虚拟化大数据](how-to/virtualize-large-data.md)
- [构建树形导航](how-to/tree-and-navigation.md)
- [构建表格与详情面板](how-to/table-master-detail.md)

### 输入与交互

- [组合文本编辑、菜单与快捷动作](how-to/text-editing-and-menus.md)
- [统一鼠标、Tab 和快捷键](how-to/keyboard-and-focus.md)
- [使用模态确认和 Toast](how-to/modal-and-toast.md)
- [建立一致主题](how-to/theme-an-app.md)

### 自定义组件、绘制与动画

- [实现完整自定义 Widget](how-to/custom-widget.md)
- [编写自绘 CanvasWidget](how-to/custom-canvas.md)
- [驱动会停止的逐帧动画](how-to/animate-with-frames.md)
- [验证增量更新与帧行为](how-to/retain-and-test.md)

`CanvasWidget` 适合只需要自由绘制和指针回调的场景；直接实现 `Widget` 可以同时控制测量、布局、绘制、事件、焦点、语义和容器行为。

### 桌面集成与交付

- [在后台工作并把结果送回界面](how-to/desktop-files-and-background.md)
- [生成快照并分析帧耗时](how-to/snapshot-and-profile.md)
- [打包桌面应用](how-to/package-desktop-app.md)

## 排错

- [按症状排查常见问题](troubleshooting/common-problems.md)
- [排查图片、动画和帧卡顿](troubleshooting/media-performance.md)

## API 快速入口

- [核心组件与状态](../api/cui/core/index.md)
- [成品控件](../api/cui/controls/index.md)
- [文本编辑](../api/cui/text/index.md)
- [图片与自绘](../api/cui/media/index.md)
- [桌面应用](../api/cui/desktop/index.md)
- [组件测试](../api/cui/testing/index.md)

## 文档质量

[文档验证说明](_verification.md)列出公开面、链接、代码示例、包测试和桌面端到端测试的门禁。完整仓颉示例会被自动提取并编译；API 页面与源码公开声明同步检查。
