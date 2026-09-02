[cui](../../index.md) › [cui.core](index.md) › ButtonRole

# ButtonRole

位于 `cui.core` 包的公开枚举

按钮的语义角色：常规、主要或危险，决定主题为按钮生成的表面配色。[`Button`](Button.md) 与 [`IconButton`](IconButton.md) 的 `role` 参数接受它，[`Theme.buttonSurface`](Theme.md#buttonsurface) 把它翻译成实际的填充、边框与阴影。

## 声明

```cangjie
public enum ButtonRole
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ButtonRole", 640, 420))
    app.run {
        HStack(spacing: 12.vp) {
            Button("稍后", {=> ()}, role: ButtonRole.Normal)
            Button("继续", {=> ()}, role: ButtonRole.Primary)
            Button("删除", {=> ()}, role: ButtonRole.Danger)
        }.padding(24.0)
        // 运行时：窗口并列展示普通、主要和危险按钮的语义化表面样式。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Normal` | 常规动作——浮起面板底色加面板边框，页面上的默认按钮外观。 |
| `Primary` | 主要动作——强调色填充、强调前景文字，一个界面通常只给一个。 |
| `Danger` | 危险动作（删除、不可恢复的操作）——危险色填充、强调前景文字。 |

## 另请参阅

- [Button](Button.md) — 构造参数与 `role` 方法接受本类型。
- [IconButton](IconButton.md) — 图标按钮的同名角色配置。
- [Theme.buttonSurface](Theme.md#buttonsurface) — 把角色翻译成表面样式。
