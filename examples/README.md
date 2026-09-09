# CUI 示例与学习路线

每个目录都是独立的仓颉可执行项目，通过相对路径依赖仓库根目录的 `cui`。

## 示例画廊

| |
|---|
| **cangcui** · 苍翠画卷 <br>![cangcui](.images/cangcui.png) |

| | | |
|---|---|---|
| **calculator** · 计算器<br>![calculator](.images/calculator.png) | **calendar** · 日历<br>![calendar](.images/calendar.png) | **notepad** · 记事本<br>![notepad](.images/notepad.png) |
| **paint** · 画板<br>![paint](.images/paint.png) | **process_manager** · 进程管理器<br>![process_manager](.images/process_manager.png) | **planner** · 专注规划台<br>![planner](.images/planner.png) |
| **data_board** · 产品看板<br>![data_board](.images/data_board.png) | **command_palette** · 命令面板<br>![command_palette](.images/command_palette.png) | **notes** · 主从式笔记<br>![notes](.images/notes.png) |
| **data_table** · 数据表格<br>![data_table](.images/data_table.png) | **contacts** · 通讯录 CRM<br>![contacts](.images/contacts.png) | **workbench** · 分栏工作台<br>![workbench](.images/workbench.png) |
| **file_explorer** · 文件浏览器（目录树）<br>![file_explorer](.images/file_explorer.png) | **booking** · 酒店预订<br>![booking](.images/booking.png) | **editor** · 写作空间<br>![editor](.images/editor.png) |
| **timeline** · 横向日期时间轴<br>![timeline](.images/timeline.png) | **chat** · 聊天（变高虚拟列表）<br>![chat](.images/chat.png) | **gallery** · 作品画廊（虚拟化网格）<br>![gallery](.images/gallery.png) |
| **settings** · 设置面板（折叠分区）<br>![settings](.images/settings.png) | **tasklist** · 任务优先级（拖动重排）<br>![tasklist](.images/tasklist.png) | **notify** · 通知 Toast<br>![notify](.images/notify.png) |
| **wizard** · 账户设置向导（步骤条）<br>![wizard](.images/wizard.png) | **catalog** · 商品目录（分页）<br>![catalog](.images/catalog.png) | **scheduler** · 会议排期（时间选择）<br>![scheduler](.images/scheduler.png) |
| **watchlist** · 观影清单（评分）<br>![watchlist](.images/watchlist.png) | **explorer** · 文件浏览器（面包屑）<br>![explorer](.images/explorer.png) | **tracker** · 问题追踪（徽标过滤）<br>![tracker](.images/tracker.png) |
| **goals** · 每日目标（环形进度）<br>![goals](.images/goals.png) | **mail** · 邮件客户端<br>![mail](.images/mail.png) | **pomodoro** · 番茄钟<br>![pomodoro](.images/pomodoro.png) |
| **typography** · 字体样式样张<br>![typography](.images/typography.png) | **fonts** · 字体实验室<br>![fonts](.images/fonts.png) | **wenkai** · 霞鹜文楷样本册<br>![wenkai](.images/wenkai.png) |
| **richtext** · 发布说明（富文本合集）<br>![richtext](.images/richtext.png) | **motion** · 缓动实验室<br>![motion](.images/motion.png) | **cards** · 样式卡片<br>![cards](.images/cards.png) |
| **disclosure** · 折叠问答<br>![disclosure](.images/disclosure.png) | **shadows** · 多重阴影<br>![shadows](.images/shadows.png) | **gradients** · 线性渐变<br>![gradients](.images/gradients.png) |
| **stats** · 数据看板（字号混排）<br>![stats](.images/stats.png) | **links** · 可点击链接<br>![links](.images/links.png) | **highlight** · 搜索高亮<br>![highlight](.images/highlight.png) |
| **styleguide** · 设计令牌<br>![styleguide](.images/styleguide.png) | **skeleton** · 骨架屏<br>![skeleton](.images/skeleton.png) | **stagger** · 交错入场<br>![stagger](.images/stagger.png) |
| **images** · 图像工作室<br>![images](.images/images.png) | **icons** · 图标工坊<br>![icons](.images/icons.png) | **symbols** · 预置图标图鉴<br>![symbols](.images/symbols.png) |
| **corners** · 逐角圆角<br>![corners](.images/corners.png) | **dashed** · 虚线边框<br>![dashed](.images/dashed.png) | |

## 学习路线

| 阶段 | 示例 | 验收重点 |
|---|---|---|
| 入门 | [calculator](calculator/README.md) → [booking](booking/README.md) | 一次输入只修改一份事实，派生结果与画面一致 |
| 应用结构 | [notes](notes/README.md) → [workbench](workbench/README.md) | 按业务身份编辑，模型与视图职责清晰 |
| 数据界面 | [data_table](data_table/README.md) → [contacts](contacts/README.md) → [chat](chat/README.md) | 排序、筛选、删除和滚动后仍操作正确对象 |
| 桌面交付 | [editor](editor/README.md) → [notepad](notepad/README.md) → [process_manager](process_manager/README.md) | 关闭确认、文件失败和后台结果可解释 |
| 媒体与扩展 | [images](images/README.md) → [icons](icons/README.md) → [paint](paint/README.md) | 资源可加载、失败可恢复、事件边界正确 |

配合[技术体系地图](../docs/guide/concepts/technology-map.md)阅读。每次练习只改一个行为，先构建，再检查输入、状态与画面。

## 按任务查找

### 状态、表单与应用结构

| 示例 | 主要知识 |
|---|---|
| [calculator](calculator/README.md) | 枚举动作、状态更新、等权布局 |
| [booking](booking/README.md) | 日期、校验与多来源派生 |
| [data_board](data_board/README.md) | 派生计数、筛选与稳定项目身份 |
| [settings](settings/README.md) | 折叠分区、模型状态与控件绑定 |
| [wizard](wizard/README.md) | 分步表单与导航校验 |
| [notes](notes/README.md) | 主从选择、字段绑定与删除确认 |
| [workbench](workbench/README.md) | 嵌套分栏、文档绑定与派生大纲 |
| [editor](editor/README.md) | 编辑命令、会话检查点与关闭确认 |
| [notepad](notepad/README.md) | UTF-8 文件、异步对话框与失败保留 |

### 列表、表格与导航

| 示例 | 主要知识 |
|---|---|
| [calendar](calendar/README.md) | 日期导航、网格与生成图片 |
| [catalog](catalog/README.md) | 分类过滤与分页 |
| [contacts](contacts/README.md) | 强类型业务数据、草稿表单与嵌套浮层 |
| [data_table](data_table/README.md) | 强类型 DataColumn、排序与自绘单元格 |
| [file_explorer](file_explorer/README.md) | TreeView、路径身份与详情索引 |
| [explorer](explorer/README.md) | 面包屑与模拟目录导航 |
| [mail](mail/README.md) | 过滤、已读与归档状态 |
| [chat](chat/README.md) | 变高虚拟列表与滚动定位 |
| [timeline](timeline/README.md) | 横向虚拟列表与日期定位 |
| [gallery](gallery/README.md) | 按行虚拟化的强类型网格 |
| [tasklist](tasklist/README.md) | 拖动重排与按 id 绑定 |
| [tracker](tracker/README.md) | 状态徽标与过滤绑定 |
| [watchlist](watchlist/README.md) | 评分绑定与派生统计 |
| [command_palette](command_palette/README.md) | 搜索焦点与应用级键盘路由 |
| [scheduler](scheduler/README.md) | 时间选择与日程排序 |
| [planner](planner/README.md) | 页面身份、网格与滚动组合 |

### 字体与媒体

| 示例 | 主要知识 |
|---|---|
| [typography](typography/README.md) | 字体样式、继承与局部覆盖 |
| [fonts](fonts/README.md) | 系统族名、数值字重与解析诊断 |
| [wenkai](wenkai/README.md) | 随附字体与静态多字重 |
| [richtext](richtext/README.md) | 混排、基线、断行与链接 |
| [images](images/README.md) | 文件／内存图像、适配与失败占位 |
| [icons](icons/README.md) | 模板／原色图标、DPI 规格与无障碍 |
| [symbols](symbols/README.md) | 单图标子包与预置资源 |
| [links](links/README.md) | 富文本链接与键盘激活 |
| [highlight](highlight/README.md) | 文本匹配与片段高亮 |
| [stats](stats/README.md) | 混合字号与保留绘制示范 |

### 样式与自绘

| 示例 | 主要知识 |
|---|---|
| [cards](cards/README.md) | 背景、阴影与边框顺序 |
| [corners](corners/README.md) | 逐角圆角与气泡造型 |
| [dashed](dashed/README.md) | 连续虚线边框 |
| [gradients](gradients/README.md) | 线性渐变与方向 |
| [shadows](shadows/README.md) | 单层与多层阴影 |
| [styleguide](styleguide/README.md) | 设计令牌的定义与使用 |
| [paint](paint/README.md) | 画布局部坐标与拖拽事件边界 |
| [cangcui](cangcui/README.md) | 程序化风景与自定义 Widget |

### 动画、反馈与后台工作

| 示例 | 主要知识 |
|---|---|
| [motion](motion/README.md) | Easing 与 Animator |
| [stagger](stagger/README.md) | 动画延迟与声明身份 |
| [skeleton](skeleton/README.md) | 共享 Pulse 与条件续帧 |
| [disclosure](disclosure/README.md) | Reveal 与可交互自定义行 |
| [goals](goals/README.md) | 进度值、目标与派生汇总 |
| [notify](notify/README.md) | Toast 与帧驱动生命周期 |
| [pomodoro](pomodoro/README.md) | 阶段计时与条件帧订阅 |
| [process_manager](process_manager/README.md) | 后台邮箱、CSV 与系统信息 |

