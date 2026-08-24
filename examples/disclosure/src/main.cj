/*
 * CUI 示例：折叠问答。
 *
 * 演示 `Reveal` 动画折叠容器：一份 FAQ，点问题标题即展开/收起答案——答案由 `Reveal` 包裹，切换时用
 * `Animator` 缓动自身高度，内容裁剪着从顶部滑入滑出，其下条目随之平滑让位。综合演示声明式过渡动画 +
 * 集合状态 + 派生查询。
 */
package cui_disclosure

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = DisclosureModel()
    let app = DesktopApp(WindowSpec("CUI 折叠问答", 620, 640, scale: 1.0), theme: disclosureTheme())
    app.setMinimumSize(520, 520)
    app.run {
        disclosureView(model)
    }
    return 0
}
