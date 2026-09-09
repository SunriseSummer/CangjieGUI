/*
 * 高亮视图层：标题 + 搜索框（TextField 绑定 query）+ 预设标签行 + 知识卡片列表 + 状态条。
 *
 * 每张卡片的标题与正文都是一条 RichText，其片段由 model.spansFor 依当前 query 切分——命中处套 <mark> 高亮。
 * 搜索框与预设标签写同一个 query State，故键入或点标签都会即时重算高亮。
 */
package cui_highlight

import cui.{Button, ButtonRole, Color, CrossAxisAlignment, FlowRow, FontSizes, HStack, Icon, IconSource}
import cui.{Label, LengthUnits, Panel, RichText, ScrollView, TextField, VStack}

func highlightView(model: SearchModel): Unit {
    VStack {
        header()
        searchBar(model)
        presetRow(model)
        ScrollView {
            VStack {
                for (i in 0..model.entries.size) {
                    entryCard(model, i)
                }
            }.spacing(10.vp)
        }.flex()
        statusBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("搜索高亮").fontSize(FontSizes.TITLE).bold()
        Label("在搜索框输入或点预设标签，命中的关键词在正文里就地以 <mark> 高亮标记，不过滤、不跳转")
            .muted()
            .fontSize(FontSizes.CAPTION)
            .wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 搜索框：ChevronRight 提示符 + 自动聚焦的单行 TextField，双向绑定 model.query。
private func searchBar(model: SearchModel): Unit {
    Panel {
        HStack {
            Icon(IconSource("assets/icons/chevron-right.svg")).foregroundColor(Color.rgb(108, 140, 255)).iconSize(18.vp)
            TextField(model.query).autofocus().flex()
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(12.vp, 8.vp).hug()
}

// 预设标签行：点一下把该词填入搜索框。
private func presetRow(model: SearchModel): Unit {
    FlowRow {
        for (term in PRESET_QUERIES) {
            // 每次迭代绑定独立文本，供闭包各自捕获。
            let label = term
            Button(label, {=> model.fill(label)}).role(ButtonRole.Normal).fontSize(FontSizes.CAPTION)
        }
    }.spacing(8.vp, 8.vp)
}

// 一张知识卡片：标题（略大）+ 正文，两者都按当前 query 高亮。
private func entryCard(model: SearchModel, index: Int64): Unit {
    let entry = model.entries[index]
    Panel {
        VStack {
            RichText(model.spansFor(entry.title), key: "title-${index}").fontSize(17.0)
            RichText(model.spansFor(entry.body), key: "body-${index}").fontSize(FontSizes.BODY)
        // Stretch both RichTexts to the card width: titles then sit on one line (a short, Start-hugged
        // RichText can wrap its last rune on a sub-pixel width mismatch), bodies wrap at the full width.
        }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Stretch)
    }.contentPadding(14.vp)
}

private func statusBar(model: SearchModel): Unit {
    Panel {
        Label(model.statusText()).fontSize(FontSizes.BODY)
    }.contentPadding(14.vp)
}
