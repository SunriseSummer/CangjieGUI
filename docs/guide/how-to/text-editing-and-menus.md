<!-- kind: how-to; audience: desktop-app-developer -->

# 组合多行编辑、菜单与快捷动作

## 目标

建立一个保留标准文本按键的编辑页：菜单触发保存动作，`TextArea` 自己处理选择、撤销和粘贴，全局快捷键只调用同一业务动作。完成约需 15 分钟。

## 适用场景

记事本、脚本编辑器、备注页和带长文本的表单。若只输入单行名称或搜索词，用 `TextField` 更合适。

## 准备工作

列出文件、新建、打开、保存等业务动作，先为每个动作写一次启用条件和状态变化。确认哪些按键已经由 `TextArea` 内建处理，哪些才是真正的应用级动作。若页面还使用 Modal，准备一个可查询的 `confirming` 状态，供根级快捷键在动作入口守卫。

## 操作步骤

### 1. 先写一次业务动作

保存动作应由模型提供，菜单点击、工具栏按钮和 Ctrl+S 都调用它。菜单项的 `shortcut` 是显示给用户的提示，不会自动安装应用级快捷键。

### 2. 让编辑器保留标准按键

不要在根部捕获方向键、Home/End、Ctrl+A/C/X/V/Z/Y。`TextArea` 已实现光标、选择、剪贴板与撤销；重复处理会让同一次按键执行两遍或抢走文本输入。

### 3. 运行菜单与编辑器

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

func save(saved: State<Int64>): Unit {
    saved.value = saved.value + 1
}

main(): Unit {
    let app = DesktopApp(WindowSpec("编辑器", 700, 460))
    app.run {
        let draft = rememberState<String>("draft") {"会议纪要\n\n- 待办事项"}
        let saved = rememberState<Int64>("saved") {0}
        EventHandler(onEvent: {ctx, event =>
            match (event) {
                case UiEvent.KeyDown(Key.Letter(code), _) =>
                    if (code == UInt8(83) && ctx.eventModifiers().command) {
                        save(saved)
                        true
                    } else {
                        false
                    }
                case _ => false
            }
        }) {
            VStack(spacing: 0.vp) {
                MenuBar(
                    [
                        Menu(
                            "文件",
                            [
                                MenuItem("保存", {=> save(saved)}, shortcut: "Ctrl+S"),
                                MenuItem.separator(),
                                MenuItem("退出", {=> ()}, enabled: false)
                            ]
                        ),
                        Menu("帮助", [MenuItem("关于", {=> ()})])
                    ]
                )
                TextArea(draft).autofocus().flex()
                Label("字符数 ${draft.value.size} · 已保存 ${saved.value} 次").muted().padding(10.vp)
            }
        }
    }
}
```

### 4. 只补真正全局的按键

`UiEvent.KeyDown` 的第二个载荷是 repeat `Bool`，不是修饰键。桌面宿主会先取空 SDL 队列再派发，稍后查询 `Keyboard.modifiers()` 可能已经看到 KeyUp 后的全局状态。完整程序使用 `ctx.eventModifiers()` 读取随当前事件保存的修饰键快照；`command` 在 Ctrl 或 GUI(Command) 任一按下时为真。

关键是只消费确认命中的组合键，并把其他事件继续交给子树。若 Modal 已打开，根级处理器还必须先检查模态状态，详见[键盘与焦点](keyboard-and-focus.md)。纯逻辑测试使用 `WidgetTestHost.frameRecords` 注入带 modifiers 的 `UiEventRecord`，不要依赖测试机器的当前键盘状态。

## 确认结果

输入多行文字，使用 Shift+方向键选择，再撤销和重做，编辑行为应保持正常。用菜单执行“保存”，计数增加但文本和焦点不丢失。加入上下文感知 `EventHandler` 后，Ctrl/Cmd+S 与菜单调用同一动作；普通 `S` 仍进入编辑器。

接着测试输入法组合、Windows CRLF 粘贴和只读模式复制。若外部加载新文档并接管光标状态，光标与选区锚点要一起更新。打开菜单后按 Tab，应关闭菜单并把遍历交还全局焦点，而不是把用户困在下拉层。

## 常见错误

- 以为菜单的快捷键文字会自动注册事件。
- 把 `KeyDown` 的 repeat `Bool` 当成 modifiers，或在延迟派发时查询全局 `Keyboard.modifiers()`。
- 用字符下标修改 `TextArea` 光标：其光标与锚点使用 UTF-8 字节偏移。
- 外部移动光标却不同时移动锚点：下一次输入会替换意外选区。
- 捕获所有 Ctrl 组合键并返回 `true`：复制、粘贴与撤销失效。

## 相关 API

[TextArea](../../api/cui/text/TextArea.md)、[MenuBar](../../api/cui/controls/MenuBar.md)、[MenuItem](../../api/cui/controls/MenuItem.md)、[EventHandler](../../api/cui/core/EventHandler.md)、[UiContext](../../api/cui/core/UiContext.md#eventmetadata-eventmodifiers) 与 [WidgetTestHost](../../api/cui/testing/WidgetTestHost.md)。

## 下一步

接入真实打开/保存流程时继续[桌面文件与后台任务](desktop-files-and-background.md)。
