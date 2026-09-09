package cui_fonts

import cui.{Button, CanvasWidget, Chip, Color, ComboBox, FontRole, FontSizes, FontWeight, Fonts, HStack, Label, Length, 
    LengthUnit, LengthUnits, Panel, Slider, TextField, TextStyle, VStack}

// 普通应用首选高层字重/样式；只有字体确实提供的轴才呈现为可选高级控件。
func fontLab(model: FontsModel): Unit {
    fontPicker(model)
    liveSpecimen(model)
    designAxes(model)
    weightReference(model)
}

private func fontPicker(model: FontsModel): Unit {
    Panel {
        VStack {
            Label("1  按字体族名选择").fontWeight(FontWeight.semiBold)
            HStack {
                ComboBox(model.chosenFamily, model.familyNames.value, key: "installed-family").flex()
                Button(if (model.catalogLoaded.value) { "刷新目录" } else { "加载系统字体" }, {=> model.refresh()})
            }.spacing(8.vp)
            Label(if (model.catalogLoaded.value) { "可输入族名；未找到时仍会回退。已发现 ${model.familyNames.value.size} 个字体族。" }
                else { "直接输入字体族名即可预览；需要浏览所有字体时再加载目录。" })
                .muted()
                .fontSize(FontSizes.CAPTION)
                .wrap()
            HStack {
                Label("字重 ${Int64(model.weight.value)}").width(100.vp)
                Slider(model.weight, key: "font-weight", lower: 100.0, upper: 900.0, step: 25.0).flex()
                Chip("斜体", model.italic, key: "lab-italic")
            }.spacing(8.vp)
            HStack {
                Label("字号 ${Int64(model.size.value)} fp").width(100.vp)
                Slider(model.size, key: "font-size", lower: 12.0, upper: 40.0, step: 1.0).flex()
            }.spacing(8.vp)
        }.spacing(10.vp).hug()
    }.contentPadding(16.vp)
}

private func liveSpecimen(model: FontsModel): Unit {
    let style = model.previewStyle()
    Panel {
        VStack {
            Label("2  同一设置用于正文、输入与按钮").fontWeight(FontWeight.semiBold)
            VStack {
                Label(model.text.value).wrap()
                HStack {
                    TextField(model.text, key: "lab-input").flex()
                    Button("保存", {=> ()})
                }.spacing(8.vp).hug()
            }
                .spacing(12.vp)
                .hug()
                .textStyle(
                    TextStyle(fontFamily: model.chosenFamily.value, fontSize: Length(model.size.value, LengthUnit.Fp),
                        fontStyle: style))
            CanvasWidget(
                {
                    renderer, rect =>
                        let result = renderer.resolveFont(font: model.chosenFamily.value, style: style)
                        let inner = rect.inset(10.0)
                        renderer.pushClip(inner)
                        try {
                            if (!result.faces.isEmpty()) {
                                let face = result.faces[0]
                                let synthesis = if (face.synthesizedStyle.bold || face.synthesizedStyle.italic) {
                                    "含合成样式"
                                } else {
                                    "真实轮廓"
                                }
                                renderer.text(
                                    "实际 ${face.familyName} · 请求 ${result.requestedWeight.value} / 实际 ${face.weight.value} · ${synthesis}",
                                    inner.x, inner.y, Color.rgb(45, 65, 75), pointSize: 13.0)
                                renderer.text(
                                    "集合面 ${face.source.collectionIndex} · 实例 ${face.source.instanceIndex} · ${face.styleName}",
                                    inner.x, inner.y + 22.0, Color.rgb(65, 85, 95), pointSize: 13.0)
                                renderer.text(face.source.path, inner.x, inner.y + 44.0, Color.rgb(90, 105, 115),
                                    pointSize: 12.0)
                            }
                            if (!result.warnings.isEmpty()) {
                                renderer.text(result.warnings[0], inner.x, inner.y + 64.0, Color.rgb(120, 80, 35),
                                    pointSize: 12.0)
                            }
                        } finally {
                            renderer.popClip()
                        }
                }
            ).height(106.vp)
        }.spacing(10.vp).hug()
    }.contentPadding(16.vp)
}

private func designAxes(model: FontsModel): Unit {
    let axes = model.axes()
    Panel {
        VStack {
            Label("3  按能力启用设计轴").fontWeight(FontWeight.semiBold)
            if (!Fonts.supportsVariations() || axes.isEmpty()) {
                Label("此字体没有可用设计轴。可输入其他已安装的字体族名；无需加载完整目录。实际解析结果以上方为准。")
                    .muted()
                    .fontSize(FontSizes.CAPTION)
                    .wrap()
                ()
            } else {
                if (model.hasExtraAxes()) {
                    Chip("启用字宽 / 光学字号轴", model.useAxes, key: "enable-design-axes")
                    ()
                }
                for (axis in axes) {
                    Label(
                        "${axis.tag}: ${axisNumber(axis.minimum)} ～ ${axisNumber(axis.maximum)}，默认 ${axisNumber(axis.defaultValue)}")
                        .fontFamily(FontRole.monospace)
                        .fontSize(FontSizes.CAPTION)
                    if (axis.tag == "wdth") {
                        Label("字宽 ${axisNumber(model.widthAxis.value)}（启用后应用）")
                            .muted()
                            .fontSize(FontSizes.CAPTION)
                        Slider(model.widthAxis, key: "width-axis", lower: axis.minimum, upper: axis.maximum, step: 1.0)
                    } else if (axis.tag == "opsz") {
                        Label("光学字号 ${axisNumber(model.opticalAxis.value)}（启用后应用）")
                            .muted()
                            .fontSize(FontSizes.CAPTION)
                        Slider(model.opticalAxis, key: "optical-axis", lower: axis.minimum, upper: axis.maximum, step: 1.0)
                    }
                }
                Label("wght 由上方 fontWeight 控制；超出字体范围时会钳制并显示实际结果。opsz 需显式设置。")
                    .muted()
                    .fontSize(FontSizes.CAPTION)
                    .wrap()
                ()
            }
        }.spacing(8.vp).hug()
    }.contentPadding(16.vp)
}

private func axisNumber(value: Float32): String {
    value.toString().trimEnd("0").trimEnd(".")
}

private func weightReference(model: FontsModel): Unit {
    Panel {
        VStack {
            Label("4  相同字族，直接切换数值字重").fontWeight(FontWeight.semiBold)
            for (weight in [200, 350, 400, 600, 625, 700]) {
                Label("${weight}  AV office ffi 012345")
                    .fontFamily(model.chosenFamily.value)
                    .fontWeight(FontWeight(weight))
                    .fontSize(20.fp)
                    .italic(value: model.italic.value)
            }
            Label("变量字体支持精确字重；滑杆以 25 为步长减少拖动时反复栅格化。静态字体采用最近可用面；无需用字距补偿斜体。")
                .muted()
                .fontSize(FontSizes.CAPTION)
                .wrap()
        }.spacing(5.vp).hug()
    }.contentPadding(16.vp)
}
