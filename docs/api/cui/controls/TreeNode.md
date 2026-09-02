[cui](../../index.md) › [cui.controls](index.md) › TreeNode

# TreeNode

位于 `cui.controls` 包的公开类

[`TreeView`](TreeView.md) 的一个节点：稳定的 `id`、显示用的 `label`、可选的前置 `icon` 与子节点数组，纯数据、构造后不可变。id 必须全树唯一——视图以它为键记录展开与选中，重复的 id 会让两个节点如同一个节点般联动展开与选中。

## 声明

```cangjie
public class TreeNode
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let src = TreeNode(
        "src",
        "src",
        icon: IconName.OpenFolder,
        children: [
            TreeNode("src/app.cj", "app.cj", icon: IconName.NewDocument),
            TreeNode("src/util", "util", children: [TreeNode("src/util/io.cj", "io.cj")])
        ]
    )
    println("${src.label} 直接子节点 ${src.children.size} 个")
    println("孙节点 ${src.children[1].children[0].id}")
    // 输出:
    // src 直接子节点 2 个
    // 孙节点 src/util/io.cj
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(id: String, label: String, children!: Array<TreeNode> = [], icon!: ?IconName = None)`](#init) | 以标识与标签构造节点，子节点与图标可选。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`id`](#id) | 全树唯一的稳定标识，展开与选中以它为键。 |
| [`label`](#label) | 行内显示的文本。 |
| [`icon`](#icon) | 标签前的可选图标。 |
| [`children`](#children) | 子节点数组，空数组即叶子。 |

## 构造函数

### init

以标识与标签构造节点，子节点与图标可选。

```cangjie
public init(id: String, label: String, children!: Array<TreeNode> = [], icon!: ?IconName = None)
```

**参数**

- `id`: `String` — 全树唯一的稳定标识；文件路径、数据主键都是合适的选择。
- `label`: `String` — 行内显示的文本。
- `children!`: `Array<TreeNode>` — 子节点，按数组顺序展示；默认 `[]` 即叶子节点。
- `icon!`: `?IconName` — 标签前的图标（sdl `IconName`，语义权威：sdl 模块文档）；默认 `None` 不画图标。

## 字段

### id

全树唯一的稳定标识，展开与选中以它为键。选中即把此值写入 [`TreeView`](TreeView.md) 的 `selected` 绑定。

```cangjie
public let id: String
```

### label

行内显示的文本。

```cangjie
public let label: String
```

### icon

标签前的可选图标。`None` 时行内容直接从标签开始。

```cangjie
public let icon: ?IconName
```

### children

子节点数组，空数组即叶子。有子节点的行显示展开箭头，可展开/折叠。

```cangjie
public let children: Array<TreeNode>
```

## 另请参阅

- [TreeView](TreeView.md) — 消费节点树的层级列表控件。
