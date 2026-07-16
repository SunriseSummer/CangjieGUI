/*
 * EntryRow / EntryHeaderRow：文件列表的条目行与列头行。
 *
 * 应用层自定义 Widget（同 paint 示例的 ColorSwatch）。条目行整行可点：悬停高亮、指针手型，单击文件夹
 * 进入、单击文件选中（选中行以强调浅底常显）；名称列裁剪到自身宽度，长名不会侵入右侧列。列头行与条目行
 * 共享同一组列几何常量，表头与内容天然对齐。
 */
package cui_explorer

import cui.{CursorShape, FontSizes, IconName, MouseButton, Rect, Size, UiContext, UiEvent, Widget, drawIcon, emit}

/** 行高与列几何（逻辑像素），条目行与列头行共用。 */
let ENTRY_ROW_H: Float32 = 34.0
let ENTRY_PAD_X: Float32 = 8.0 // 行内左右留白
let ENTRY_ICON_SIZE: Float32 = 20.0
let ENTRY_ICON_GAP: Float32 = 10.0
let COL_MODIFIED_W: Float32 = 110.0 // 修改日期列宽
let COL_SIZE_W: Float32 = 90.0 // 大小列宽（内容右对齐）

// 名称列的起点与三列的分界，由行矩形现算，条目行与列头行走同一套函数。
func nameColumnX(frame: Rect): Float32 {
    frame.x + ENTRY_PAD_X + ENTRY_ICON_SIZE + ENTRY_ICON_GAP
}

func modifiedColumnX(frame: Rect): Float32 {
    frame.right() - ENTRY_PAD_X - COL_SIZE_W - COL_MODIFIED_W
}

func sizeColumnRight(frame: Rect): Float32 {
    frame.right() - ENTRY_PAD_X
}

class EntryRow <: Widget {
    private let node: FsNode
    private let isSelected: Bool
    private let onActivate: () -> Unit
    private let hoverId: String
    private var frame = Rect.zero()

    /** `onActivate` 在整行任意处单击时触发（文件夹进入、文件选中，由调用方决定）。 */
    init(node: FsNode, isSelected: Bool, onActivate: () -> Unit) {
        this.node = node
        this.isSelected = isSelected
        this.onActivate = onActivate
        // 同一目录内名字唯一，悬停身份以名字区分即可（整树每帧重建，跨目录不留残留）。
        this.hoverId = "EntryRow:${node.name}"
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, ENTRY_ROW_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (isSelected) {
            ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.accentSoft)
        } else if (ctx.isHovered(hoverId)) {
            // 用悬停仲裁而非原始鼠标坐标：ScrollView 只在指针落于视口内时才下发 MouseMove，
            // 半滚出视口的行不会因指针停在列头/留白处而误亮。
            ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        let icon = if (node.isDir) {
            IconName.OpenFolder
        } else {
            IconName.NewDocument
        }
        let iconColor = if (node.isDir) {
            EXPLORER_FOLDER
        } else {
            EXPLORER_MUTED
        }
        drawIcon(ctx.renderer, icon,
            Rect(frame.x + ENTRY_PAD_X, frame.centerY() - ENTRY_ICON_SIZE / 2.0, ENTRY_ICON_SIZE, ENTRY_ICON_SIZE),
            iconColor)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        // 名称裁剪到自身列宽，长名截断而不侵入日期列。
        let nameX = nameColumnX(frame)
        let nameW = max(0.0, modifiedColumnX(frame) - nameX - ENTRY_ICON_GAP)
        ctx.renderer.pushClip(Rect(nameX, frame.y, nameW, frame.h))
        ctx.renderer.text(node.name, nameX, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
        ctx.renderer.text(node.modified, modifiedColumnX(frame), textY, ctx.theme.mutedText,
            pointSize: FontSizes.CONTROL)
        // 大小列右对齐：文件为字节数格式化，文件夹展示子项数。
        let sizeText = if (node.isDir) {
            "${node.children.size} 项"
        } else {
            formatSize(node.sizeBytes)
        }
        let sizeW = ctx.renderer.textWidth(sizeText, pointSize: FontSizes.CONTROL)
        ctx.renderer.text(sizeText, sizeColumnRight(frame) - sizeW, textY, ctx.theme.mutedText,
            pointSize: FontSizes.CONTROL)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) =>
                if (frame.contains(x, y)) {
                    ctx.claimHover(hoverId, CursorShape.Interactive)
                }
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    onActivate()
                    return true
                }
            case _ => ()
        }
        false
    }
}

// 列头行：名称 / 修改日期 / 大小，位置与条目行同一套列几何。
class EntryHeaderRow <: Widget {
    private var frame = Rect.zero()

    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, 24.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) / 2.0
        let muted = ctx.theme.mutedText
        ctx.renderer.text("名称", nameColumnX(frame), textY, muted, pointSize: FontSizes.CAPTION)
        ctx.renderer.text("修改日期", modifiedColumnX(frame), textY, muted, pointSize: FontSizes.CAPTION)
        let sizeW = ctx.renderer.textWidth("大小", pointSize: FontSizes.CAPTION)
        ctx.renderer.text("大小", sizeColumnRight(frame) - sizeW, textY, muted, pointSize: FontSizes.CAPTION)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
