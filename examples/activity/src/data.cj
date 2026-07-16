/*
 * 活动流数据：文件操作事件及其图标、动词与配色。
 *
 * 每条活动渲染为一段 `RichText`：行首是按动作着色的图标，随后是强调色的操作者、常规色的动词、动作色的
 * 文件路径与弱化色的时间。长路径会在气泡宽度内自动换行。图标、动词、配色都由动作类型派生。
 */
package cui_activity

import std.collection.ArrayList
import cui.{Color, IconName}

enum Action {
    | Created
    | Saved
    | Copied
    | Deleted
    | Opened
}

struct Activity {
    let id: Int64
    let action: Action
    let actor: String
    let file: String
    let time: String

    init(id: Int64, action: Action, actor: String, file: String, time: String) {
        this.id = id
        this.action = action
        this.actor = actor
        this.file = file
        this.time = time
    }
}

func actionIcon(action: Action): IconName {
    match (action) {
        case Created => IconName.NewDocument
        case Saved => IconName.Save
        case Copied => IconName.Copy
        case Deleted => IconName.Trash
        case Opened => IconName.OpenFolder
    }
}

func actionVerb(action: Action): String {
    match (action) {
        case Created => "新建了"
        case Saved => "保存了"
        case Copied => "复制了"
        case Deleted => "删除了"
        case Opened => "打开了"
    }
}

func actionName(action: Action): String {
    match (action) {
        case Created => "新建"
        case Saved => "保存"
        case Copied => "复制"
        case Deleted => "删除"
        case Opened => "打开"
    }
}

func actionColor(action: Action): Color {
    match (action) {
        case Created => Color.rgb(46, 160, 92)
        case Saved => Color.rgb(66, 120, 220)
        case Copied => Color.rgb(28, 150, 160)
        case Deleted => Color.rgb(210, 74, 68)
        case Opened => Color.rgb(206, 150, 40)
    }
}

private let ACTORS: Array<String> = ["林小满", "Ada", "周珩", "Kenji", "陈默"]
private let ACTIONS: Array<Action> = [Action.Created, Action.Saved, Action.Copied, Action.Opened, Action.Deleted]
private let FILES: Array<String> = [
    "report.md",
    "src/core/rich_text.cj",
    "designs/2026Q3/首页改版-终稿-v7-最终-真的最终.sketch",
    "notes.txt",
    "examples/activity/src/views.cj",
    "docs/商用差距.md",
    "build/output/very/deep/nested/path/to/some/artifact/bundle.tar.gz",
    "LICENSE",
    "assets/images/logo@3x.png",
    "src/controls/menu_bar.cj"
]
private let TIMES: Array<String> = ["09:12", "09:24", "10:03", "10:41", "11:15", "13:07", "14:22", "15:48", "16:30",
    "17:05"]

/** 生成一段确定性的活动流：动作、操作者、文件与时间各自轮转，制造长短不一、类型多样的条目。 */
func seedActivities(): Array<Activity> {
    let list = ArrayList<Activity>()
    var id: Int64 = 1
    var step = 0
    while (list.size < 60) {
        // 操作者与时间加上按整轮递增的相移：等长数组若共用同一下标，配对会恒定、整条流每 10 条重复；
        // 相移让每轮换一个配对，动作×操作者的组合得以全覆盖。
        let action = ACTIONS[step % ACTIONS.size]
        let actor = ACTORS[(step + step / ACTIONS.size) % ACTORS.size]
        let file = FILES[step % FILES.size]
        let time = TIMES[(step + step / FILES.size) % TIMES.size]
        list.add(Activity(id, action, actor, file, time))
        id += 1
        step += 1
    }
    list.toArray()
}
