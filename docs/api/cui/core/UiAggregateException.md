[cui](../../index.md) › [cui.core](index.md) › UiAggregateException

# UiAggregateException

同一 UI 操作发生多个异常时，保留每个原始异常对象。用于运行与关停、构建回滚、资源清理、事件收尾以及状态通知失败；继承标准库 `Exception`。

## 声明

```cangjie
public class UiAggregateException <: Exception
```

只有一个异常时框架直接重抛原对象，原有针对具体类型的 `catch` 仍然适用。多个异常时抛出本类型：`primary` 是首先发生的错误，`failures` 按发生顺序列出原始异常，可分别读取 `message`、`getStackTrace()` 或调用 `printStackTrace()`。框架汇总嵌套事务时展开其异常列表。

聚合不意味着业务操作回滚成功。已提交的状态通知仍会继续送达，资源关闭失败仍需要调用方处理；框架会尝试后续清理阶段，不因先前异常跳过它们。

## 构造函数

### init

```cangjie
public init(failures: Array<Exception>)
```

复制输入列表，至少需要两个异常，否则抛出 `IllegalArgumentException`。消息包含各个异常的说明。通常由框架生成，应用不必自行构造。

## 属性

### primary

```cangjie
public prop primary: Exception
```

列表中的第一个原始异常对象。

### failures

```cangjie
public prop failures: Array<Exception>
```

返回列表副本，修改数组不会改变聚合异常持有的列表；数组元素仍是原始异常对象。

## 示例

```cangjie verify
package docexample

import cui.{DesktopApp, Label, UiAggregateException, WindowSpec}

main(): Unit {
    let app = DesktopApp(WindowSpec("异常诊断", 640, 420))
    try {
        app.run { Label("关闭窗口结束示例") }
    } catch (error: UiAggregateException) {
        for (failure in error.failures) { failure.printStackTrace() }
    }
}
```

迁移说明：先前同时发生多个失败时可能只收到一个错误，或收到拼接消息的 `IllegalStateException`；现在应使用本类型读取完整原因，避免只按单一异常类型捕获复合失败。
