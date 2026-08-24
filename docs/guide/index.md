# CUI 使用指南

CUI 是运行在 SDL3 上的仓颉声明式桌面界面框架。你在构建函数中描述当前数据对应的界面，框架负责布局、绘制、焦点和事件循环。本指南按用户要完成的工作组织，不按源码包罗列控件；查询构造签名、默认值和全部成员时，请使用独立的 [CUI API 参考](../api/index.md)。

## 这套指南怎么用

第一次使用，请沿“从这里开始”完成首窗口和设置表单；已有项目可从“按任务查找”直接进入具体结果。页面中的 `role=complete` 是可放进空项目的完整程序；`role=patch` 明确依赖所链接的基页；concept 的片段用于比较和追踪，不应误当成独立程序。

验证也分层记录：构建通过只说明语法和链接成立，`--snapshot` 实际运行说明稳定 GUI 初始帧可生成，事件测试或人工步骤才说明键盘、Modal、拖动、文件对话框等交互成立。总体验证状态见[验证报告](_verification.md)。

想先确认环境是否可用，也可以直接打开[第一个窗口](getting-started/first-window.md)查看最小运行路径，再回到下节按顺序学习。

## 从这里开始

如果你还没有 CUI 项目，从[创建第一个 CUI 窗口](getting-started/first-window.md)开始。你会建立路径依赖、准备 SDL 运行库，并运行一个可点击、可关闭的计数器。前置知识只需要会使用 `cjpm`、认识仓颉函数和 class；预计 15 分钟。如果窗口无法启动，先不要继续抄更多界面代码，直接使用[通用排障](troubleshooting/common-problems.md)的动态库分支。

首窗口不是“能编译就算完成”。继续之前逐项确认：`cjpm build` 退出码为 0；窗口能显示计数和按钮；点击按钮后计数确实增加；关闭按钮能结束进程。如果构建通过但看不到窗口，检查 SDL 动态库和运行目录；窗口出现但点击无效，则从事件与状态分支排查。把这四项结果都观察到，再进入声明式构建概念。

首窗口成功后，用约 20 分钟阅读[声明式构建与应用生命周期](concepts/composition-and-lifecycle.md)和[状态、绑定与派生值](concepts/state-and-binding.md)。这两页解释为什么应用对象只创建一次、构建函数可以重复执行，以及事实为什么必须由稳定状态持有。它们是后续表单、列表、浮层和动画共同的前提，不熟悉声明式 GUI 时不要跳过。

接着用约 30 分钟完成[设置表单](tutorials/settings-form.md)。你将把输入、校验、提交和结果提示接到同一份事实，再用鼠标和键盘检查完整路径。到这里约 65 分钟，你已经具备独立查任务页的基础；要做多区域真实应用，继续[应用结构](concepts/app-architecture.md)和[任务工作台](tutorials/task-workbench.md)。

表单的完成条件也不是只看到输入框：空姓名应出现姓名错误，未同意条款应出现条款错误，填写完整后应显示成功结果；用 Tab、空格和回车走一遍时，结果必须与鼠标操作一致。三条路径都成立后，新项目读者可沿“真实应用”学习路径继续；已有项目的读者可直接到“按任务查找”，根据要交付的可观察结果选择页面。

## 学习路径

### 1. 首次成功：空项目到可靠表单

[第一个窗口](getting-started/first-window.md) → [构建生命周期](concepts/composition-and-lifecycle.md) → [状态与绑定](concepts/state-and-binding.md) → [设置表单](tutorials/settings-form.md)。适合第一次使用 CUI 的应用开发者，约 65 分钟；结束时能运行窗口、定位状态所有权并完成带校验反馈的表单。

### 2. 真实应用：单页到可维护工作台

[应用结构](concepts/app-architecture.md) → [任务工作台](tutorials/task-workbench.md) → [修饰器与单位](concepts/modifiers-and-units.md) → [应用主题](how-to/theme-an-app.md)。约 70 分钟；结束时模型、动作、界面和测试边界清楚，并能把单文件基线拆成多文件工程。

### 3. 数据导航：布局到大数据

[布局与滚动](concepts/layout-and-scrolling.md) → [选择布局](how-to/choose-layout.md) → [稳定身份列表](how-to/data-list.md) → [虚拟化大列表](how-to/virtualize-large-data.md) → [表格主从界面](how-to/table-master-detail.md) → [树形导航](how-to/tree-and-navigation.md)。约 100 分钟；结束时能处理缩放、筛选、重排、千级数据和层级选择。

### 4. 文本与浮层：编辑到安全快捷键

[焦点、事件与浮层](concepts/focus-events-and-overlays.md) → [Modal 与 Toast](how-to/modal-and-toast.md) → [键盘与焦点](how-to/keyboard-and-focus.md) → [文本与菜单](how-to/text-editing-and-menus.md)。约 60 分钟；结束时鼠标、菜单和快捷键复用同一动作，Modal 打开时背景快捷键不会改写模型。

### 5. 桌面交付：异步集成到发布

[文件与后台任务](how-to/desktop-files-and-background.md) → [快照与性能记录](how-to/snapshot-and-profile.md) → [通用排障](troubleshooting/common-problems.md) → [打包桌面应用](how-to/package-desktop-app.md)。约 70 分钟；结束时能安全回收后台结果、区分验证证据，并在干净目录启动交付物。

### 6. 组件进阶：媒体、动画与性能边界

[资源与媒体](concepts/resources-and-media.md) → [媒体预览面板](tutorials/media-dashboard.md) → [自绘控件](how-to/custom-canvas.md) → [动画与帧预算](concepts/animation-and-frame-budget.md) → [逐帧动画](how-to/animate-with-frames.md) → [保留子树与帧级测试](how-to/retain-and-test.md) → [快照与性能记录](how-to/snapshot-and-profile.md) → [媒体性能排障](troubleshooting/media-performance.md)。约 125 分钟；适合组件作者，结束时能解释资源所有权、事件边界、续帧停止条件、保留缓存契约和性能证据。

## 按任务查找

### 启动项目并搭好应用骨架

先解决“应用怎样启动、数据放在哪里、页面怎样拆分”这类基础问题。完成这些任务后，你应该能运行真实窗口，并说清状态、视图和测试各自负责什么。

| 你的任务 | 从这里进入 | 完成后的可观察结果 |
|---|---|---|
| 安装依赖并打开首窗口 | [创建第一个窗口](getting-started/first-window.md) | 窗口能启动；按钮会更新计数；关闭按钮能正常退出进程 |
| 构建带校验和结果提示的表单 | [设置表单](tutorials/settings-form.md) | 空姓名、未同意条款和提交成功三条路径都能重复操作并得到不同提示 |
| 选择 State、Binding 或派生值 | [状态与绑定](concepts/state-and-binding.md) | 修改输入后派生提示同步更新，且同一份数据只在一个 `State` 中写入 |
| 组织多文件真实任务工作台 | [任务工作台](tutorials/task-workbench.md) | 模型、动作和视图分文件；筛选与保存逻辑可脱离窗口单独测试 |
| 判断修饰器顺序和尺寸单位 | [修饰器与单位](concepts/modifiers-and-units.md) | 交换背景与内边距的顺序前，就能判断颜色区域和鼠标命中范围怎样变化 |

### 布局并浏览动态数据

当窗口开始承载列表、表格或树时，从这里选择容器并维护稳定的业务身份。验收重点不是“画出来了”，而是窗口变化、筛选和重排之后，用户仍能找到原来的内容。

| 你的任务 | 从这里进入 | 完成后的可观察结果 |
|---|---|---|
| 选择栈、网格、滚动或分栏 | [选择布局](how-to/choose-layout.md) | 三种窗口尺寸下主要区域仍可达 |
| 让筛选和重排不改变业务身份 | [稳定身份列表](how-to/data-list.md) | 选中一条记录后再筛选或重排，选择仍跟随业务 `id`，不会跳到同一行号的新记录 |
| 只构建千级列表的可见行 | [虚拟化大列表](how-to/virtualize-large-data.md) | 滚动到数百行后窗口仍连续响应，构建计数只覆盖视口附近的条目 |
| 在过滤、删除后保持表格详情 | [表格主从界面](how-to/table-master-detail.md) | 排序、过滤或删除后，详情仍显示同一业务 `id`；对象消失时才清空选择 |
| 创建可键盘导航的层级树 | [树形导航](how-to/tree-and-navigation.md) | 展开、方向键选择和右侧详情都按稳定路径 `id` 工作 |

### 完成交互、编辑和视觉反馈

这些任务处理鼠标、键盘、浮层、文本编辑和主题之间的边界。完成后，危险动作会被拦住确认，普通反馈不会挡住工作，全局快捷键也不会误伤正在编辑或被 Modal 遮住的内容。

| 你的任务 | 从这里进入 | 完成后的可观察结果 |
|---|---|---|
| 为危险动作加确认、普通结果加通知 | [Modal 与 Toast](how-to/modal-and-toast.md) | 删除先确认，反馈自动消失 |
| 让全局快捷键遵守 Modal 边界 | [键盘与焦点](how-to/keyboard-and-focus.md) | Modal 打开时按 Delete，背景选择和 `pendingId` 都不改变 |
| 组合多行编辑、菜单和快捷动作 | [文本与菜单](how-to/text-editing-and-menus.md) | 文本框保留光标移动等标准按键，菜单和快捷键调用同一个保存动作 |
| 统一颜色、间距和动作角色 | [应用主题](how-to/theme-an-app.md) | 启动后多个页面读取同一组颜色、间距和动作角色令牌，切换令牌即可统一改变外观 |

### 接入桌面能力、媒体并交付应用

从异步文件操作到媒体资源、动画、快照和打包，这一组覆盖应用离开纯界面演示之后的完整闭环。每项任务都要求留下可复现的运行、资源或诊断证据。

| 你的任务 | 从这里进入 | 完成后的可观察结果 |
|---|---|---|
| 异步打开或保存桌面文件 | [文件与后台任务](how-to/desktop-files-and-background.md) | 对话框期间窗口保持响应 |
| 把后台成功或失败送回 UI | [文件与后台任务](how-to/desktop-files-and-background.md) | 成功值和错误值都经信箱返回，并只在 UI 帧中更新界面状态 |
| 生成并显示确定媒体预览 | [媒体预览面板](tutorials/media-dashboard.md) | 生成的 BMP 能显示并生成稳定快照，退出后临时输入文件被清理 |
| 判断图片缓存与资源所有权 | [资源与媒体](concepts/resources-and-media.md) | 同一路径复用缓存；托管资源随控件释放；临时资源在退出前显式清理 |
| 编写不会吞掉相邻事件的画布 | [自绘控件](how-to/custom-canvas.md) | 画布范围内的指针事件被消费，范围外的事件继续交给相邻控件 |
| 驱动并停止动画续帧 | [逐帧动画](how-to/animate-with-frames.md) | 动画到达目标后 `settled()` 返回真，后续帧不再调用 `animate` |
| 跳过昂贵静态区的重复构建/布局 | [保留子树与帧级测试](how-to/retain-and-test.md) | revision 命中时缓存计数增加，输入变化时准确失效；同帧事件状态可由无头宿主断言 |
| 生成 BMP 并读取帧证据 | [快照与性能记录](how-to/snapshot-and-profile.md) | BMP 文件可打开，并能把视觉结果、交互状态和各阶段耗时分开记录 |
| 打包可在干净目录启动的应用 | [打包桌面应用](how-to/package-desktop-app.md) | 仅复制可执行文件、SDL 运行库和资源到干净目录后，应用仍能启动并完成冒烟操作 |
| 排查启动、状态、布局和浮层 | [通用排障](troubleshooting/common-problems.md) | 每个症状都能经过“复现—观察—修复—确认”走到一个可观察的通过条件 |

图片、动画和帧耗时属于独立的进阶排障入口，见[媒体与性能排障](troubleshooting/media-performance.md)。

## 核心概念

八个概念页组成后续任务的判断框架：生命周期回答“何时重建”，状态回答“事实由谁持有”，应用结构回答“谁能修改”，布局回答“空间怎样分配”，修饰器回答“包装顺序产生什么结果”，事件与浮层回答“输入先交给谁”，资源回答“谁负责复用或关闭”，动画回答“何时请求下一帧”。不必一次背完；遇到任务页中的取舍时回到对应概念页即可。

- [声明式构建与应用生命周期](concepts/composition-and-lifecycle.md)
- [状态、绑定与派生值](concepts/state-and-binding.md)
- [模型、动作与界面边界](concepts/app-architecture.md)
- [布局约束、滚动与虚拟化](concepts/layout-and-scrolling.md)
- [尺寸单位与修饰器顺序](concepts/modifiers-and-units.md)
- [焦点、事件与浮层](concepts/focus-events-and-overlays.md)
- [媒体缓存与资源所有权](concepts/resources-and-media.md)
- [动画状态与帧预算](concepts/animation-and-frame-budget.md)

## API 参考

需要精确签名时进入 [CUI API 参考](../api/index.md)。应用生命周期查 [DesktopApp](../api/cui/desktop/DesktopApp.md)，状态查 [State](../api/cui/core/State.md)，布局查 [VStack](../api/cui/core/VStack.md) 和 [Grid](../api/cui/core/Grid.md)，媒体查 [ImageView](../api/cui/media/ImageView.md)。指南解释选择和任务路径，API 参考负责成员清单与声明。

## 排查问题

编译或启动失败、状态重置、身份错位、内容溢出、Modal 背景误响应，从[通用排障](troubleshooting/common-problems.md)开始。图片空白、首次解码慢、动画不停或长帧，从[媒体与性能排障](troubleshooting/media-performance.md)开始。每个分支都要求先复现和观察，再应用修复并确认结果。

## 文档验证

任务覆盖、示例构建、GUI 快照、继承补丁回放、声明证据和仍需人工检查的边界见[验证报告](_verification.md)。
