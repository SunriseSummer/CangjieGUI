package cui_symbols

import cui.{CalendarDate, IconSource, State, TimeOfDay}
import cui.symbols.calendar.ICON_CALENDAR
import cui.symbols.clock.ICON_CLOCK
import cui.symbols.search.ICON_SEARCH
import cui.symbols.home.ICON_HOME
import cui.symbols.menu.ICON_MENU
import cui.symbols.more.ICON_MORE
import cui.symbols.plus.ICON_PLUS
import cui.symbols.minus.ICON_MINUS
import cui.symbols.check.ICON_CHECK
import cui.symbols.close.ICON_CLOSE
import cui.symbols.chevron_left.ICON_CHEVRON_LEFT
import cui.symbols.chevron_right.ICON_CHEVRON_RIGHT
import cui.symbols.chevron_up.ICON_CHEVRON_UP
import cui.symbols.chevron_down.ICON_CHEVRON_DOWN
import cui.symbols.arrow_left.ICON_ARROW_LEFT
import cui.symbols.arrow_right.ICON_ARROW_RIGHT
import cui.symbols.arrow_up.ICON_ARROW_UP
import cui.symbols.arrow_down.ICON_ARROW_DOWN
import cui.symbols.external_link.ICON_EXTERNAL_LINK
import cui.symbols.refresh.ICON_REFRESH
import cui.symbols.download.ICON_DOWNLOAD
import cui.symbols.upload.ICON_UPLOAD
import cui.symbols.document.ICON_DOCUMENT
import cui.symbols.folder.ICON_FOLDER
import cui.symbols.save.ICON_SAVE
import cui.symbols.copy.ICON_COPY
import cui.symbols.paste.ICON_PASTE
import cui.symbols.edit.ICON_EDIT
import cui.symbols.trash.ICON_TRASH
import cui.symbols.settings.ICON_SETTINGS
import cui.symbols.info.ICON_INFO
import cui.symbols.warning.ICON_WARNING
import cui.symbols.help.ICON_HELP
import cui.symbols.lock.ICON_LOCK
import cui.symbols.eye.ICON_EYE
import cui.symbols.user.ICON_USER
import cui.symbols.heart.ICON_HEART
import cui.symbols.star.ICON_STAR
import cui.symbols.bell.ICON_BELL
import cui.symbols.image.ICON_IMAGE

struct SymbolEntry {
    let name: String
    let label: String
    let source: IconSource
    init(name: String, label: String, source: IconSource) {
        this.name = name
        this.label = label
        this.source = source
    }
}

class SymbolsModel {
    let date = State<CalendarDate>(CalendarDate(2026, 9, 9))
    let time = State<TimeOfDay>(TimeOfDay(10, 10))
    let clicks = State<Int64>(0)
    // Only this demonstration imports the complete collection. Applications import their choices.
    let entries = [
        SymbolEntry("calendar", "日历", ICON_CALENDAR),
        SymbolEntry("clock", "时间", ICON_CLOCK),
        SymbolEntry("search", "搜索", ICON_SEARCH),
        SymbolEntry("home", "主页", ICON_HOME),
        SymbolEntry("menu", "菜单", ICON_MENU),
        SymbolEntry("more", "更多", ICON_MORE),
        SymbolEntry("plus", "添加", ICON_PLUS),
        SymbolEntry("minus", "减少", ICON_MINUS),
        SymbolEntry("check", "确认", ICON_CHECK),
        SymbolEntry("close", "关闭", ICON_CLOSE),
        SymbolEntry("chevron_left", "向左展开", ICON_CHEVRON_LEFT),
        SymbolEntry("chevron_right", "向右展开", ICON_CHEVRON_RIGHT),
        SymbolEntry("chevron_up", "向上展开", ICON_CHEVRON_UP),
        SymbolEntry("chevron_down", "向下展开", ICON_CHEVRON_DOWN),
        SymbolEntry("arrow_left", "向左", ICON_ARROW_LEFT),
        SymbolEntry("arrow_right", "向右", ICON_ARROW_RIGHT),
        SymbolEntry("arrow_up", "向上", ICON_ARROW_UP),
        SymbolEntry("arrow_down", "向下", ICON_ARROW_DOWN),
        SymbolEntry("external_link", "外部链接", ICON_EXTERNAL_LINK),
        SymbolEntry("refresh", "刷新", ICON_REFRESH),
        SymbolEntry("download", "下载", ICON_DOWNLOAD),
        SymbolEntry("upload", "上传", ICON_UPLOAD),
        SymbolEntry("document", "文档", ICON_DOCUMENT),
        SymbolEntry("folder", "文件夹", ICON_FOLDER),
        SymbolEntry("save", "保存", ICON_SAVE),
        SymbolEntry("copy", "复制", ICON_COPY),
        SymbolEntry("paste", "粘贴", ICON_PASTE),
        SymbolEntry("edit", "编辑", ICON_EDIT),
        SymbolEntry("trash", "删除", ICON_TRASH),
        SymbolEntry("settings", "设置", ICON_SETTINGS),
        SymbolEntry("info", "信息", ICON_INFO),
        SymbolEntry("warning", "警告", ICON_WARNING),
        SymbolEntry("help", "帮助", ICON_HELP),
        SymbolEntry("lock", "锁定", ICON_LOCK),
        SymbolEntry("eye", "查看", ICON_EYE),
        SymbolEntry("user", "用户", ICON_USER),
        SymbolEntry("heart", "喜爱", ICON_HEART),
        SymbolEntry("star", "收藏", ICON_STAR),
        SymbolEntry("bell", "通知", ICON_BELL),
        SymbolEntry("image", "图像", ICON_IMAGE)
    ]
}
