[cui](../../index.md) › [cui.desktop](index.md) › AccessibilityFailure

# AccessibilityFailure

`cui.desktop` 包中的 public class

桌面无障碍分支被隔离时产生的结构化诊断。它保留失败来源、操作、对应语义 revision 与原始异常；框架不会把
原生桥、外部观察器或故障回调中的一个失败扩散到其它分支。

## 声明

```cangjie
public class AccessibilityFailure
```

## 属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `source` | [`AccessibilityFailureSource`](AccessibilityFailureSource.md) | 被隔离的分支。 |
| `operation` | [`AccessibilityFailureOperation`](AccessibilityFailureOperation.md) | 失败发生的边界操作。 |
| `revision` | `UInt64` | 失败更新的语义 revision；动作排空尚未收到更新时为 0。 |
| `cause` | `Exception` | 原始异常，未被字符串化或替换。 |

失败通过 [`DesktopApp.setAccessibilityFailureHandler`](DesktopApp.md#setaccessibilityfailurehandler) 立即通知，也可由
[`DesktopApp.takeAccessibilityFailures`](DesktopApp.md#takeaccessibilityfailures) 确定性取得并清空。
