[cui](../../index.md) › [cui.controls](index.md) › MenuItem

# MenuItem

位于 `cui.controls` 包的公开结构体

菜单中的一个条目：标签、选中时执行的动作、可选的右对齐快捷键提示与可用标记。被 [`ContextMenu`](ContextMenu.md) 与 [`MenuBar`](MenuBar.md) 共用；[`separator`](#separator) 生成组间分隔线。

## 声明

```cangjie
public struct MenuItem
```

## 说明

`shortcut` 只是显示在行右侧的提示文本，菜单宿主不会替应用注册全局按键——快捷键的实际响应仍由应用自己处理键盘事件实现。`enabled` 为 `false` 的行变暗显示，键盘高亮与点击都跳过它；分隔线同样既不高亮也不执行。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("MenuItem", 640, 420))
    app.run {
        let saved = rememberState<Int64>("saved") {0}
        let bar = MenuBar(
            [
                Menu(
                    "文件",
                    [
                        MenuItem("保存", {=> saved.value = saved.value + 1}, shortcut: "Ctrl+S"),
                        MenuItem.separator(),
                        MenuItem("另存为…", {=> ()}, enabled: false)
                    ]
                )
            ]
        )
        Label("保存动作执行 ${saved.value} 次").padding(24.0)
        // 运行时：打开“文件”菜单后可执行“保存”，禁用的“另存为”不可选择。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(label: String, action: () -> Unit, shortcut!: String, enabled!: Bool)`](#init) | 由标签与动作构造菜单条目，可带快捷键提示与可用标记。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static separator()`](#separator) | 生成组间的非交互分隔线。 |

## 构造函数

### init

由标签与动作构造菜单条目，可带快捷键提示与可用标记。

```cangjie
public init(label: String, action: () -> Unit, shortcut!: String = "", enabled!: Bool = true)
```

**参数**

- `label`: `String` — 行内显示的文本。
- `action`: `() -> Unit` — 该行被选中时执行的动作；菜单先关闭再执行，动作因此可以打开自己的浮层。
- `shortcut!`: `String` — 右对齐的快捷键提示文本（如 `"Ctrl+S"`），仅展示、不注册按键。默认空串（不显示）。
- `enabled!`: `Bool` — 可用标记；`false` 时变暗且不可选。默认 `true`。

## 方法

### separator

生成组间的非交互分隔线。分隔线画为一条细线，键盘高亮与点击都跳过它。

```cangjie
public static func separator(): MenuItem
```

**返回值** `MenuItem` — 分隔线条目。

## 另请参阅

- [Menu](Menu.md) — 顶级菜单的描述。
- [MenuBar](MenuBar.md) — 应用菜单栏宿主。
- [ContextMenu](ContextMenu.md) — 右键菜单宿主。
