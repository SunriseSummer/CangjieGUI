/*
 * 邮件客户端入口：组装模型与窗口。
 */
package cui_mail

import cui.{DesktopApp, WindowSpec}

main(): Unit {
    let model = MailModel()
    let app = DesktopApp(WindowSpec("CUI 邮件客户端", 860, 620, scale: 1.0), theme: mailTheme())
    app.run {
        mailView(model)
    }
}
