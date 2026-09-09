package cui_icons

import cui.*
import cui.symbols.copy.ICON_COPY
import cui.symbols.refresh.ICON_REFRESH
import cui.symbols.save.ICON_SAVE
import cui.symbols.trash.ICON_TRASH

func iconsView(model: IconsModel): Unit {
    ScrollView {
        VStack(spacing: 22.vp) {
            HStack(spacing: 14.vp) {
                Icon("assets/icons/orbit.svg")
                    .renderingMode(IconRenderingMode.Original)
                    .iconSize(48.vp)
                    .alt("山海工作室")
                VStack(spacing: 3.vp) {
                    Label("图标工坊").fontSize(28.fp).bold().foregroundColor(INK)
                    Label("形状有秩序，细节有温度。让每一个动作清晰可见。").fontSize(12.fp).muted()
                }.hug()
                Spacer()
                Label("ICON ATELIER   /   02").fontSize(11.fp).foregroundColor(TEAL)
            }.hug()
            HStack(spacing: 20.vp) {
                opticalSizes();
                colorModes(model)
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
            HStack(spacing: 20.vp) {
                densityVariants(model);
                actions(model)
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
            HStack(spacing: 20.vp) {
                inlineAndTree(model);
                details(model)
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
            HStack {
                Label("原创示例资产 · 圆头线条 / 透明底色 / 留白一致").fontSize(11.fp).muted()
                Spacer()
                Label("SVG  ·  PNG  ·  内存资源").fontSize(11.fp).foregroundColor(TEAL)
            }.hug()
        }.crossAxisAlignment(CrossAxisAlignment.Start).hug().padding(28.vp)
    }
}

private func caption(number: String, title: String, note: String): Unit {
    HStack(spacing: 10.vp) {
        Label(number).fontSize(11.fp).foregroundColor(TEAL)
        Label(title).fontSize(17.fp).bold().foregroundColor(INK)
    }.hug()
    Label(note).fontSize(11.fp).muted()
}

private func opticalSizes(): Unit {
    VStack(spacing: 12.vp) {
        caption("01", "尺寸与节奏", "小尺寸精简轮廓，大尺寸保持呼吸感。")
        HStack(spacing: 30.vp) {
            for (size in [16, 20, 24, 32, 48]) {
                VStack(spacing: 12.vp) {
                    Icon(asset(if (size == 16) {
                        "search-16"
                    } else {
                        "search"
                    })).iconSize(Length(Float32(size), LengthUnit.Vp)).foregroundColor(INK).height(54.vp)
                    Label("${size} vp").fontSize(11.fp).muted()
                }.hug()
            }
        }.hug().padding(8.vp)
        Label("16 vp 使用独立光学校正稿，其余尺寸使用同一 SVG。").fontSize(11.fp).foregroundColor(TEAL)
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(20.vp)
        .width(492.vp)
        .background(PAPER, 16.vp)
        .border(LINE, width: 1.0, radius: 16.vp)
}

private func colorModes(model: IconsModel): Unit {
    let ink = if (model.dark.value) {
        Color.rgb(237, 242, 227)
    } else {
        INK
    }
    let background = if (model.dark.value) {
        INK
    } else {
        Color.rgb(237, 240, 230)
    }
    VStack(spacing: 12.vp) {
        caption("02", "原色与主题色", "品牌保留自己的颜色，动作跟随界面语气。")
        HStack(spacing: 28.vp) {
            Icon("assets/icons/orbit.svg").renderingMode(IconRenderingMode.Original).iconSize(48.vp)
            Icon(asset("spark")).iconSize(32.vp).foregroundColor(ink)
            Icon(asset("moon")).iconSize(32.vp).foregroundColor(ink)
            Icon(asset("check")).iconSize(32.vp).foregroundColor(ink)
            Icon(asset("arrow-up-right")).iconSize(24.vp).foregroundColor(ink)
        }.hug().padding(14.vp).background(background, 12.vp)
        Switch("深色预览", model.dark)
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(20.vp)
        .width(492.vp)
        .background(PAPER, 16.vp)
        .border(LINE, width: 1.0, radius: 16.vp)
}

private func densityVariants(model: IconsModel): Unit {
    VStack(spacing: 12.vp) {
        caption("03", "每一块屏幕都清晰", "位图准备多个密度，像素画使用最近邻采样。")
        HStack(spacing: 24.vp) {
            Icon(model.brand).iconSize(24.vp)
            Icon(model.brand).iconSize(32.vp)
            Icon(model.brand).iconSize(48.vp)
            Spacer()
            Icon("assets/icons/pixel-16.png", style: IconStyle(size: 48.vp, sampling: TextureScaleMode.Nearest))
                .renderingMode(IconRenderingMode.Original)
        }.hug().padding(10.vp)
        Label("PNG：24 / 48 / 72 / 96 px    ·    像素画：16 px → 48 vp").fontSize(11.fp).foregroundColor(TEAL)
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(20.vp)
        .width(492.vp)
        .background(PAPER, 16.vp)
        .border(LINE, width: 1.0, radius: 16.vp)
}

private func actions(model: IconsModel): Unit {
    VStack(spacing: 12.vp) {
        caption("04", "从观看到行动", "预置源码图标按需导入，按钮提供可朗读的名称。")
        HStack(spacing: 10.vp) {
            IconButton(ICON_SAVE, label: "保存", role: ButtonRole.Primary) {=> model.clicks.value += 1}
            IconButton(ICON_COPY, onClick: {=> model.clicks.value += 1}).accessibilityLabel("复制")
            IconButton(ICON_REFRESH, onClick: {=> model.clicks.value += 1}).accessibilityLabel("刷新").iconSize(24.vp)
            IconButton(ICON_TRASH, onClick: {=> ()}).accessibilityLabel("删除").enabled(false)
        }.hug()
        Label("已操作 ${model.clicks.value} 次    ·    Tab 移动焦点，空格或回车触发")
            .fontSize(11.fp)
            .foregroundColor(TEAL)
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(20.vp)
        .width(492.vp)
        .background(PAPER, 16.vp)
        .border(LINE, width: 1.0, radius: 16.vp)
}

private func inlineAndTree(model: IconsModel): Unit {
    VStack(spacing: 10.vp) {
        caption("05", "融入信息", "同一份资源，在文字与树形导航中保持一致。")
        RichText(
            [RichSpan.icon(asset("check"), color: Some(TEAL)), RichSpan.text("  所有更改已保存"),
                RichSpan.muted(" · 刚刚")]).fontSize(13.fp)
        TreeView(
            [
                TreeNode(
                    "design",
                    "设计资源",
                    icon: Some(asset("folder")),
                    children: [
                        TreeNode("brand", "品牌标记", icon: Some(model.brand)),
                        TreeNode("notes", "使用说明", icon: Some(asset("document")))
                    ]
                )
            ],
            model.selection,
            initiallyExpanded: ["design"]
        ).height(98.vp).width(444.vp)
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(20.vp)
        .width(492.vp)
        .background(PAPER, 16.vp)
        .border(LINE, width: 1.0, radius: 16.vp)
}

private func details(model: IconsModel): Unit {
    VStack(spacing: 12.vp) {
        caption("06", "细节有分寸", "显隐有层次，方向可调整，缺失资源有回退。")
        HStack(spacing: 25.vp) {
            Icon(model.memory).iconSize(32.vp).foregroundColor(TEAL)
            Icon(model.memory).iconSize(32.vp).foregroundColor(TEAL).iconOpacity(0.4)
            Icon(asset("arrow-up-right"), style: IconStyle(size: 32.vp, color: Some(TEAL), flip: TextureFlip.Horizontal))
            Icon("assets/intentionally-unavailable.svg").fallback(model.memory).iconSize(32.vp).foregroundColor(TEAL)
        }.hug().padding(12.vp)
        Label("内存资源      40% 透明度      水平镜像      应用提供回退").fontSize(11.fp).foregroundColor(TEAL)
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(20.vp)
        .width(492.vp)
        .background(PAPER, 16.vp)
        .border(LINE, width: 1.0, radius: 16.vp)
}
