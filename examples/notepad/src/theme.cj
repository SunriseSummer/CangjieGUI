/*
 * 记事本的应用元数据、SDL 提示项、青绿主题与表面样式。
 * 集中在一个文件里，视图层只管取用，不关心具体色值。
 */
package cui_notepad

import cui.{AppMetadata, AppMetadataType, Color, LengthUnits, SdlHint, SdlHintSetting, SurfaceStyle, Theme}

// Application typography and repeated layout values; the view only composes these roles.
let NOTEPAD_TITLE = 22.fp
let NOTEPAD_DOCUMENT_TITLE = 15.fp
let NOTEPAD_CAPTION = 11.fp
let NOTEPAD_COMMAND = 12.fp
let NOTEPAD_PRIMARY = 13.fp
let NOTEPAD_LINE_HEIGHT = 28.fp
let NOTEPAD_ICON = 24.vp
let NOTEPAD_GAP = 12.vp
let NOTEPAD_PAGE_INSET = 20.vp
let NOTEPAD_CARD_INSET = 16.vp
let NOTEPAD_SECTION_GAP = 14.vp
let NOTEPAD_ACCENT = Color.rgb(34, 132, 127)

func notepadPaper(): SurfaceStyle {
    SurfaceStyle(Color.rgb(255, 255, 255), borderWidth: 0.0)
}

func notepadMetadata(): AppMetadata {
    var metadata = AppMetadata(
        name: Some("CUI Notepad"),
        version: Some("0.1.0"),
        identifier: Some("dev.cui.examples.notepad")
    )
    metadata.creator = Some("CUI Examples")
    metadata.appType = Some(AppMetadataType.Application)
    metadata
}

func notepadHints(): Array<SdlHintSetting> {
    [
        SdlHintSetting(SdlHint.AppName, "CUI Notepad"),
        SdlHintSetting(SdlHint.AppId, "dev.cui.examples.notepad"),
        SdlHintSetting(SdlHint.WindowsCloseOnAltF4, "1")
    ]
}

func notepadTheme(): Theme {
    Theme(
        bg: Color.rgb(238, 244, 248),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(201, 213, 222),
        text: Color.rgb(25, 34, 43),
        mutedText: Color.rgb(92, 106, 119),
        accent: Color.rgb(34, 132, 127),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(196, 59, 76),
        field: Color.rgb(227, 236, 239),
        fieldActive: Color.rgb(229, 245, 243),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(214, 241, 238),
        shadow: Color.rgba(0, 0, 0, 0),
        radius: 16.0,
        smallRadius: 3.0,
        controlRadius: 6.0,
        borderWidth: 0.0
    )
}

func toolbarSurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 255, 255),
        border: Color.rgb(220, 230, 235),
        radius: 16.0,
        borderWidth: 1.0,
        shadow: Color.rgba(20, 44, 56, 12),
        shadowOffsetY: 2.0
    )
}

/**
 * “新建”确认条的暖色警示表面：与常规白色面板拉开视觉差，
 * 提醒用户接下来的操作会丢弃未保存内容。
 */
func confirmBarSurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 248, 236),
        border: Color.rgb(238, 205, 160),
        radius: 12.0,
        borderWidth: 1.0
    )
}
