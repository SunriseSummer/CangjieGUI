[cui](../../index.md) › [cui.controls](index.md) › Menu

# Menu

位于 `cui.controls` 包的公开结构体

`MenuBar` 菜单栏的一个顶级菜单描述：标题加其下拉包含的菜单项。纯数据，本身不绘制也不处理事件；[`MenuBar`](MenuBar.md) 读取它生成标题条与下拉菜单。

## 声明

```cangjie
public struct Menu
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Menu", 640, 420))
    app.run {
        let saved = rememberState<Int64>("saved") {0}
        let fileMenu = Menu(
            "文件",
            [
                MenuItem("保存", {=> saved.value = saved.value + 1}, shortcut: "Ctrl+S"),
                MenuItem.separator(),
                MenuItem("退出", {=> ()})
            ]
        )
        let bar = MenuBar([fileMenu])
        // 运行时：点击“文件”打开 Menu，选择“保存”会执行对应动作。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(title: String, items: Array<MenuItem>)`](#init) | 由标题与菜单项数组构造一个顶级菜单描述。 |

## 构造函数

### init

由标题与菜单项数组构造一个顶级菜单描述。

```cangjie
public init(title: String, items: Array<MenuItem>)
```

**参数**

- `title`: `String` — 菜单栏上显示的标题（如"文件"、"编辑"）。
- `items`: `Array<MenuItem>` — 下拉包含的菜单行，见 [`MenuItem`](MenuItem.md)；可含分隔线与禁用行。

## 另请参阅

- [MenuBar](MenuBar.md) — 消费本类型的应用菜单栏。
- [MenuItem](MenuItem.md) — 单个菜单行的描述。
