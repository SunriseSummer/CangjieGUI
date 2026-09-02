[cui](../../index.md) › [cui.controls](index.md) › BadgeKind

# BadgeKind

位于 `cui.controls` 包的公开枚举

`Badge` 徽标的语义配色：中性、主题强调色，或信息/成功/警告/危险四种状态色。[`Badge`](Badge.md) 按它取基色；`Neutral`、`Accent`、`Danger` 跟随主题，`Info`、`Success`、`Warning` 用固定语义色，经软化底色处理后明暗主题皆可读。

## 声明

```cangjie
public enum BadgeKind
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("BadgeKind", 520, 220))
    app.run {
        FlowRow {
            Badge("草稿", kind: BadgeKind.Neutral)
            Badge("进行中", kind: BadgeKind.Info)
            Badge("已上线", kind: BadgeKind.Success)
            Badge("即将到期", kind: BadgeKind.Warning)
            Badge("构建失败", kind: BadgeKind.Danger)
        }.spacing(10.vp).padding(24.0)
        // 运行时：窗口并排显示中性、信息、成功、警告和危险五种徽标配色。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Neutral` | 中性灰，取主题的次要文本色；适合默认、未分类的状态。 |
| `Accent` | 主题强调色，随主题切换。 |
| `Info` | 固定的信息蓝（RGB 56, 118, 214）。 |
| `Success` | 固定的成功绿（RGB 34, 158, 92）。 |
| `Warning` | 固定的警告琥珀（RGB 198, 142, 36）。 |
| `Danger` | 主题的危险色，用于失败与破坏性状态。 |

## 另请参阅

- [Badge](Badge.md) — 消费本枚举的状态标签。
