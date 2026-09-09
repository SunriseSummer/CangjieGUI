/*
 * 发布说明视图层：抬头 + 类别过滤 + 版本区块列表 + 链接反馈状态条。
 *
 * 每个版本区块一张卡：版本标题行（大号版本号 + 小号日期 + 「最新」软标签，逐段字号混排）、
 * 斜体导语、逐条说明。每条说明是一段 RichText：类别图标与软底标签、加粗主题词、常规描述、
 * 灰底内联代码、弃用旧写法划除、下划线议题链接（可点击、可 Tab 聚焦）；长句在卡宽内自动换行。
 */
package cui_richtext

import cui.{CrossAxisAlignment, FontSizes, Label, LengthUnits, Panel, RichSpan, RichText, ScrollView, SegmentedControl,
    VStack, FontWeight, FontRole, TextStyle}
import std.collection.ArrayList

func richtextView(model: RichTextModel): Unit {
    VStack {
        header()
        SegmentedControl(FILTER_LABELS, model.filter, key: "cat-filter")
        ScrollView {
            VStack {
                for (section in model.sections) {
                    sectionCard(model, section)
                }
                if (model.visibleTotal() == 0) {
                    Label("没有此类条目").muted()
                }
            }.spacing(14.vp)
        }.flex()
        statusBar(model)
    }.spacing(12.vp).padding(20.vp).textStyle(TextStyle(fontFamily: FontRole.systemUI, fontSize: 15.fp))
}

private func header(): Unit {
    VStack {
        Label("发布说明").fontSize(FontSizes.TITLE).bold()
        Label("一段 RichText 拼出一条说明：图标、软底标签、加粗主题、灰底代码、划除旧写法、下划线链接")
            .muted()
            .fontSize(FontSizes.CAPTION)
            .wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func sectionCard(model: RichTextModel, section: ReleaseSection): Unit {
    let notes = model.visibleNotes(section)
    Panel {
        VStack {
            RichText(versionSpans(section), key: "ver-${section.version}")
            RichText([RichSpan.muted(section.intro).italic()], key: "intro-${section.version}").fontSize(13.0)
            for (i in 0..notes.size) {
                noteRow(model, section, notes[i])
            }
            if (notes.isEmpty()) {
                Label("该版本没有此类条目").muted().fontSize(FontSizes.CAPTION)
            }
        }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(18.vp).hug()
}

// 版本标题行：大号加粗版本号 + 小号日期，最新版本再缀一枚软底标签——同一行三种字号。
private func versionSpans(section: ReleaseSection): Array<RichSpan> {
    let spans = ArrayList<RichSpan>()
    spans.add(RichSpan.text("v${section.version}").bold().fontSize(24.0))
    spans.add(RichSpan.muted("  ${section.date}").fontSize(13.0))
    if (section.latest) {
        spans.add(RichSpan.text("  "))
        spans.add(RichSpan.text(" 最新 ", color: categoryColor(0)).highlight(categorySoft(0)).fontSize(12.0))
    }
    spans.toArray()
}

private func noteRow(model: RichTextModel, section: ReleaseSection, note: ReleaseNote): Unit {
    RichText(noteSpans(note, {=> model.openIssue(note.issue)}), key: "note-${section.version}-${note.subject}")
}

/*
 * 一条说明的片段拼装：图标 → 软底类别标签 → 加粗主题词 → 描述；随后按数据可选地接上
 * 划除的旧写法（弃用迁移）、灰底代码片段、尾句与下划线议题链接。全部片段同处一段，
 * 长句在卡宽内逐段流动换行。
 */
func noteSpans(note: ReleaseNote, onOpen: () -> Unit): Array<RichSpan> {
    let spans = ArrayList<RichSpan>()
    spans.add(RichSpan.icon(categoryIcon(note.category), color: categoryColor(note.category)))
    spans.add(RichSpan.text("  "))
    spans.add(
        RichSpan
            .text(" ${categoryName(note.category)} ", color: categoryColor(note.category))
            .highlight(categorySoft(note.category))
            .fontSize(12.0))
    spans.add(RichSpan.text("  "))
    spans.add(RichSpan.text(note.subject).fontWeight(FontWeight.semiBold))
    spans.add(RichSpan.text("：${note.desc}"))
    if (!note.oldApi.isEmpty()) {
        spans.add(RichSpan.text("，"))
        spans.add(RichSpan.muted(note.oldApi).strikethrough())
        spans.add(RichSpan.text(" 改用"))
    }
    if (!note.code.isEmpty()) {
        // 代码片段的高亮盒紧贴字形（不含内衬空格）：行尾断开时不会留下孤悬的空格高亮条。
        spans.add(RichSpan.text(" "))
        spans.add(
            RichSpan.text(note.code, color: CODE_INK).fontFamily(FontRole.monospace).highlight(CODE_BG).fontSize(13.0))
    }
    if (!note.tail.isEmpty()) {
        spans.add(RichSpan.text("，${note.tail}"))
    }
    if (!note.issue.isEmpty()) {
        spans.add(RichSpan.text("  "))
        spans.add(RichSpan.text(note.issue, color: LINK_COLOR).underline().onTap(onOpen))
    }
    spans.toArray()
}

// 底部状态条：链接点击反馈，也顺带示范小字号与大数值的混排。
private func statusBar(model: RichTextModel): Unit {
    Panel {
        RichText(statusSpans(model), key: "status")
    }.contentPadding(12.vp).hug()
}

func statusSpans(model: RichTextModel): Array<RichSpan> {
    let spans = ArrayList<RichSpan>()
    spans.add(RichSpan.muted("链接可点击、可 Tab 聚焦 · 已打开 "))
    spans.add(RichSpan.text("${model.openedCount.value}").bold().fontSize(19.0))
    spans.add(RichSpan.muted(" 次"))
    if (!model.lastIssue.value.isEmpty()) {
        spans.add(RichSpan.muted("，最近 "))
        spans.add(RichSpan.text(model.lastIssue.value).bold())
    }
    spans.toArray()
}
