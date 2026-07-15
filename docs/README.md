# CUI 文档中心

本目录提供 CUI 声明式 GUI 框架的使用指南、API 参考和架构说明。阅读顺序可根据使用目标选择：

1. [快速入门](getting-started.md)：完成依赖配置、首个窗口和项目运行。
2. [CUI 使用指南](user-guide.md)：掌握视图构建、状态、布局、样式、事件、文本和资源管理。
3. [CUI API 参考](api-reference.md)：按包和功能查阅公开类型、构造参数与方法。
4. [架构与设计说明](architecture.md)：理解包边界、帧调度与脏帧跳过、渲染管线和线程模型。

底层窗口、渲染、输入和系统 API 由独立 `sdl` 模块提供，参见
[SDL 文档中心](../sdl/docs/README.md)。

## 适用范围

文档对应当前仓库的 `0.2.0` API 与仓颉工具链 `1.0.5`。示例默认以 Windows 为主要验证平台，
字体后端同时配置了 macOS 与 Linux 的常见系统字体候选路径。

## API 边界

应用层建议从 `cui` 根包显式导入所需成员。`cui.core`、`cui.controls`、`cui.text`、`cui.media`、
`cui.desktop` 的应用级 API 均由根包重新导出。`protected`、`internal`、`private` 声明以及
`sdl.text` 不属于稳定的应用接口。
