package cui_images

import cui.*

main(): Unit {
    let model = ImagesModel()
    let app = DesktopApp(WindowSpec("CUI 图像工作室", 940, 750), theme: Theme.light())
    app.setMinimumSize(940, 680)
    app.run {imagesView(model)}
}
