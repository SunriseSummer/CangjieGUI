/*
 * CUI 示例：骨架屏。
 *
 * 演示 `Pulse`（循环/往复动画原语）：加载中以骨架行占位，底色在基色与亮色间往复呼吸；全部行共享一个
 * Pulse（按帧去重、同步呼吸），内容就位后切换为真实列表、界面回到零帧空闲。综合演示循环动画 + 自定义
 * 动画微件 + 加载态切换。
 */
package cui_skeleton

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = SkeletonModel()
    let app = DesktopApp(WindowSpec("CUI 骨架屏", 620, 600, scale: 1.0), theme: skeletonTheme())
    app.setMinimumSize(520, 460)
    app.run {
        skeletonView(model)
    }
    return 0
}
