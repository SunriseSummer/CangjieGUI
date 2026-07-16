/*
 * CUI 示例：任务优先级（拖动重排）。
 *
 * 演示 `ReorderableList` 拖放重排：按住每行左侧手柄上下拖动即改变任务顺序（顺序即优先级），拖动时其它行
 * 让开、被拖行悬浮，松手提交。行内容的复选框仍可正常勾选（点手柄拖动、点其余命中内容），二者互不干扰。
 */
package cui_tasklist

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = TaskModel()
    let app = DesktopApp(WindowSpec("CUI 任务优先级", 560, 620, scale: 1.5), theme: tasklistTheme())
    app.setMinimumSize(440, 480)
    app.run {
        tasklistView(model)
    }
    return 0
}
