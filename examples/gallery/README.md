# gallery：作品画廊（LazyGrid 虚拟化网格）

一面 60 张卡片的作品墙，演示数据驱动的虚拟化网格 `LazyGrid`：等宽分栏、按行窗口化，只有视口附近的行
会真正构建与绘制，卡片数量再多每帧也只花一屏的成本。卡片本身是普通控件组合（色块＋标题＋副标题的
面板），网格只负责排布与虚拟化。

## 演示要点

- `LazyGrid(data, columns, itemHeight, spacing!:, columnSpacing!:) { item => ... }`：一行构建器搭出网格，数据保持强类型
- 按行虚拟化：滚动时仅构建视口附近的行，与 `LazyColumn` 同一套窗口化机制
- 行高固定（`itemHeight`）换取 O(1) 的行定位与滚动映射
- 卡片即控件：构建器里返回任意控件组合，网格不限定卡片形态

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口，装配窗口与主题 |
| [views.cj](src/views.cj) | `GalleryItem` 类型化数据、种子数据与卡片/网格视图 |

## 运行

```powershell
cjpm run
```

## 练习与验收

增加作品数量并改变列数，检查行高与可见项目布局。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
