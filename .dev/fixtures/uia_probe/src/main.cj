package uia_probe

import cui.{Button, DesktopApp, State, WindowSpec}

main(): Int64 {
    let invoked = State<Bool>(false)
    let app = DesktopApp(WindowSpec("CUI UIA e2e probe", 260, 100, vsync: false, resizable: false))
    app.run {
        Button(if (invoked.value) {
            "已调用 · Invoked"
        } else {
            "调用我 · Invoke"
        }, {=> invoked.value = true}).key("uia-action")
    }
    0
}
