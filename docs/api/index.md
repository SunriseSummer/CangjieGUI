# API 参考

应用通常只需：

```cangjie
import cui.*
```

`cui` 会重新导出 CUI 各子包和配套 SDL 模块。只有在编写库、缩小导入范围或查找符号定义位置时，才需要直接导入子包。

## 按任务选择入口

| 任务 | 入口 |
|---|---|
| 启动桌面应用 | [`DesktopApp`](cui/desktop/DesktopApp.md) |
| 声明组件与布局 | [`cui.core`](cui/core/index.md) |
| 使用成品控件 | [`cui.controls`](cui/controls/index.md) |
| 编辑文本 | [`cui.text`](cui/text/index.md) |
| 显示图片或自由绘制 | [`cui.media`](cui/media/index.md) |
| 编写帧级测试 | [`cui.testing`](cui/testing/index.md) |
| 查询统一导出的全部符号 | [`cui`](cui/index.md) |

## 包

| 包 | 职责 |
|---|---|
| [`cui`](cui/index.md) | 应用的统一导入入口。 |
| [`cui.core`](cui/core/index.md) | 组件协议、布局、状态、事件、主题、动画和自定义组件基础设施。 |
| [`cui.controls`](cui/controls/index.md) | 选择、导航、数据展示、菜单、模态框和通知等成品控件。 |
| [`cui.text`](cui/text/index.md) | 单行、多行和带建议列表的文本编辑控件。 |
| [`cui.media`](cui/media/index.md) | 图片、图像缓存和自由绘制。 |
| [`cui.desktop`](cui/desktop/index.md) | 窗口、按需帧循环、跨线程投递、资源管理和桌面集成。 |
| [`cui.testing`](cui/testing/index.md) | 不依赖真实窗口的确定性组件帧测试。 |

## 阅读约定

每个类型页面先说明用途和约束，再列声明、成员、参数、返回值与异常。代码块分为两类：

- 带 `verify` 标记的完整程序会由文档门禁实际编译。
- API 声明块由公开面检查与源码对照，不能代替完整程序直接运行。
