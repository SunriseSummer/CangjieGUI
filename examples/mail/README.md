# mail：邮件客户端（SplitView 双栏 + 自绘列表行 + 搜索过滤）

一只桌面收件箱：左栏邮件列表（未读加粗带圆点、选中高亮、点击选中），右栏阅读窗
（主题、发件人混排元信息、未读徽标与操作、逐段正文）；顶部搜索按发件人/主题/预览过滤，
计数行实时显示总数与未读数。

## 演示要点

- `SplitView` 左列表右阅读的经典双栏，分隔条可拖动
- 自绘 `MailRow` 两行式列表行：未读加粗（`FontStyle(bold: true)` 直达渲染层真粗体）+ 强调色圆点，
  时间右对齐，发件人与主题各自 `pushClip` 裁剪到列宽截断；选中/悬停底色沿用 explorer 的 EntryRow 惯例
- 阅读即已读：`select` 顺手把邮件移入已读集合；「标为未读」逆操作、「归档」从列表移除并把选中
  顺延到相邻一封（空列表则清空选中）——集合更新沿用「复制 + 增删 + 整体重赋」惯例
- `RichText` 混排元信息（加粗发件人 + 弱化地址、加粗计数 + 弱化单位）；`Badge` 标注未读
- `TextField` 搜索双向绑定 `State<String>`，`matchesQuery` 纯函数过滤（空词全命中）

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Mail` 数据与确定性收件箱（正文按段落存放） |
| [model.cj](src/model.cj) | 搜索/选中/已读/归档状态与可见集派生 |
| [row.cj](src/row.cj) | `MailRow` 自绘两行列表行 |
| [views.cj](src/views.cj) | 工具栏、列表栏、阅读栏 |
| [theme.cj](src/theme.cj) | 信笺蓝商务浅色主题 |

## 运行

```powershell
cd examples/mail
cjpm run
```

点列表行阅读（未读圆点随之消失），搜索框键入即过滤；「归档」把邮件移出列表并顺延选中。
支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot mail.bmp"
```

## 练习与验收

归档当前邮件直至为空，确认选择顺延和未读计数正确。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
