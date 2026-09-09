package cui_images

import cui.*

private let INK = Color.rgb(28, 53, 62)
private let TEAL = Color.rgb(32, 107, 117)
private let PAPER = Color.rgb(250, 249, 245)
private let EDGE = Color.rgb(220, 226, 223)

func imagesView(model: ImagesModel): Unit {
    ScrollView {
        VStack(spacing: 20.vp) {
            HStack(spacing: 12.vp) {
                ImageView("assets/mark.svg").size(40.vp, 40.vp).decodeSize(120).tint(TEAL)
                VStack(spacing: 2.vp) {
                    Label("图像工作室").fontSize(26.fp).bold().foregroundColor(INK)
                    Label("山湖之间 · 静态图像与材质预览").fontSize(12.fp).muted()
                }.hug()
                Spacer()
                Label("IMAGE STUDIO  /  01").fontSize(11.fp).muted()
            }.hug()
            HStack(spacing: 22.vp) {
                preview(model)
                inspector(model)
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
            HStack {
                Label("一张图，不同表达").fontSize(18.fp).bold()
                Spacer()
                Label("共享图像资源 · 独立样式").fontSize(12.fp).muted()
            }.hug()
            treatments()
            HStack {
                Label("JPEG · PNG · SVG · GIF 静态帧 · QOI · BMP · TGA").fontSize(11.fp).muted()
                Spacer()
                Label("原始插画 / 960 × 600").fontSize(11.fp).muted()
            }.hug()
        }.crossAxisAlignment(CrossAxisAlignment.Start).hug().padding(28.vp)
    }
}

private func preview(model: ImagesModel): Unit {
    VStack(spacing: 10.vp) {
        ImageView(model.source())
            .size(580.vp, 350.vp)
            .fit(FITS[model.fit.value])
            .decodeSize(1160, 700)
            .cornerRadius(if (model.rounded.value) {
                16.vp
            } else {
                0.vp
            })
            .imageOpacity(model.opacity.value)
            .flip(if (model.mirrored.value) {
                TextureFlip.Horizontal
            } else {
                TextureFlip.None
            })
            .imageBackground(Color.rgb(231, 236, 233))
            .imageBorder(EDGE)
            .alt("晨光中的高山、松林与湖面上的小舟")
        HStack {
            Label("ALPINE LAKE").fontSize(12.fp).bold().foregroundColor(INK)
            Spacer()
            Label(FORMATS[model.format.value]).fontSize(12.fp).foregroundColor(TEAL)
        }.hug()
    }.hug().width(580.vp)
}

private func inspector(model: ImagesModel): Unit {
    VStack(spacing: 13.vp) {
        Label("画面设置").fontSize(16.fp).bold()
        Label("图像来源").fontSize(12.fp).muted()
        Dropdown(FORMATS, model.format).fillWidth()
        Label("适配方式").fontSize(12.fp).muted()
        Dropdown(["完整显示", "裁剪填满", "拉伸", "仅缩小", "原始尺寸"], model.fit).fillWidth()
        Label("图像透明度").fontSize(12.fp).muted()
        Slider(model.opacity).fillWidth()
        Switch("圆角边缘", model.rounded)
        Switch("水平镜像", model.mirrored)
        Label("切换格式与样式，观察相同画面的不同呈现。").fontSize(12.fp).muted().wrap()
    }.hug().padding(18.vp).width(256.vp).background(PAPER, 14.vp).border(EDGE, width: 1.0, radius: 14.vp)
}

private func treatments(): Unit {
    HStack(spacing: 16.vp) {
        VStack(spacing: 8.vp) {
            ImageView("assets/alpine.jpg").size(200.vp, 125.vp).fit(ImageFit.Cover).cornerRadius(12.vp)
            Label("封面 · 等比裁剪").fontSize(12.fp)
        }.hug()
        VStack(spacing: 8.vp) {
            ImageView("assets/alpine.jpg")
                .size(200.vp, 125.vp)
                .fit(ImageFit.Cover)
                .tint(Color.rgb(150, 215, 228))
                .cornerRadius(12.vp)
            Label("冷色 · 独立着色").fontSize(12.fp)
        }.hug()
        VStack(spacing: 8.vp) {
            ImageView("assets/alpine.png")
                .size(200.vp, 125.vp)
                .fit(ImageFit.Cover)
                .imageAlignment(Alignment.Trailing)
                .sourceRect(Rect(530.0, 60.0, 300.0, 300.0))
                .cornerRadius(12.vp)
            Label("局部 · 保留主体").fontSize(12.fp)
        }.hug()
        VStack(spacing: 8.vp) {
            ImageView("assets/missing.png")
                .size(200.vp, 125.vp)
                .cornerRadius(12.vp)
                .imageBackground(PAPER)
                .imageBorder(EDGE)
                .errorPlaceholder {
                    ctx, rect, _ => ctx.renderer.textCenter("暂时无法显示", rect, ctx.theme.mutedText, pointSize: 13.0)
                }
            Label("失败 · 友好占位").fontSize(12.fp)
        }.hug()
    }.hug()
}
