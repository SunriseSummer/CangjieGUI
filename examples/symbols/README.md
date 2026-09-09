# 日常的形状 · 预置图标图鉴

完整展示 CUI 的 40 枚原创源码图标。资源由 `cui.symbols.<name>` 按需提供，本示例为了图鉴展示显式导入全部图标。
源码见 [model.cj](src/model.cj)、[views.cj](src/views.cj)，API 与体积边界见[预置图标指南](../../docs/guide/how-to/preset-icons.md)。

![全部 40 枚预置图标](../.images/symbols.png)

```text
cd examples/symbols
cjpm run
```

- 图鉴：导航、增删确认、文件操作、日期时间、状态与常见对象。
- 尺寸：16／20／24／32／48 vp 使用同一份资源，由显示尺寸和 DPI 决定栅格化尺寸。
- 样式：浅色与深色背景、不同前景色、40% 透明度。
- 交互：带文字和无障碍名称的喜欢按钮；恢复日历与时钟图形的 DatePicker、TimePicker。
- 图标没有随应用发布的文件，也不依赖操作系统图标字体。

最小窗口为 1180 × 1100 逻辑像素，完整图鉴可以同屏比较。40% 透明度只用于展示层次；正式按钮禁用时使用 `.enabled(false)`，
保持视觉状态、事件与无障碍状态一致。每个纯图标操作都应提供其用途的可访问名称；装饰图案无需逐个朗读。

验证：`python .dev/cli.py test examples symbols --action test --snapshot --retained-diff --tolerance 0`。

预置资源现在是公开只读值，例如导入 `cui.symbols.clock.ICON_CLOCK` 后直接使用 `Icon(ICON_CLOCK)`。
不再调用 `clockIcon()`；其余常量同样使用 `ICON_` 前缀和大写下划线名称。

## 练习与验收

在独立小应用只导入一枚图标，按指南检查其直接与间接依赖。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
