# data_table：强类型数据表格

服务器监控面板展示 `Table.of`：模型保留 `Array<Server>`，`DataColumn<Server>` 提取显示与排序值，CPU 列使用自定义绘制，选中行驱动详情。

## 运行与观察

按[运行准备](../README.md#运行准备)配置环境，从 CangjieGUI 根目录执行：

```text
cd examples/data_table
cjpm run
```

点击列头排序，再次点击反向；选中一台服务器后改变排序，确认高亮仍跟随同一数据行。Tab 聚焦表格后，用上下键、Home、End 导航，选中行应滚入视口。

## 源码导航

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 装配模型、主题与窗口 |
| [data.cj](src/data.cj) | `Server`、列抽取器、CPU 单元格绘制与种子数据 |
| [model.cj](src/model.cj) | `FleetModel`、选择和详情派生 |
| [views.cj](src/views.cj) | 表格与详情栏 |
| [theme.cj](src/theme.cj) | 主题与字号 |

## 从数据到单元格

[fleetView](src/views.cj) 调用 `Table.of(model.servers, serverColumns(), model.selected)`，不需要先复制为字符串矩阵。[serverColumns](src/data.cj) 返回 `Array<DataColumn<Server>>`，每列通过抽取器产生文本，例如主机名或 CPU 百分比。

`numeric: true` 让数值列按数值排序并右对齐。CPU 列的 `cell` 回调只改变表现：负载条和文字使用同一数值；表格仍负责行底色、选中状态、单元格裁剪和事件。

选择值是传入数组的原始行索引，表头排序仅改变显示顺序。因此排序不会把选择转移给另一台服务器；应用替换、过滤或重排输入数组时，仍需自行维护选择身份。

## 练习与验收

给 `Server` 增加一项数值指标，在 `serverColumns` 增加抽取器。确认排序按数值、单元格不越界、详情仍对应选中服务器。该示例使用静态种子数据，不连接真实监控服务。

```text
cjpm test --no-progress
cjpm run --run-args "--snapshot data_table.bmp"
```

参见 [`Table`](../../docs/api/cui/controls/Table.md)、[`DataColumn`](../../docs/api/cui/controls/DataColumn.md) 和[示例学习路线](../README.md)。
