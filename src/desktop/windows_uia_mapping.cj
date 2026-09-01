package cui.desktop

import cui.core.{SemanticsAction, SemanticsChange, SemanticsRole}

private let UIA_ACTION_ACTIVATE: UInt32 = UInt32(1) << 0
private let UIA_ACTION_FOCUS: UInt32 = UInt32(1) << 1
private let UIA_ACTION_INCREMENT: UInt32 = UInt32(1) << 2
private let UIA_ACTION_DECREMENT: UInt32 = UInt32(1) << 3
private let UIA_ACTION_SET_VALUE: UInt32 = UInt32(1) << 4
private let UIA_CHANGE_ADDED: Int32 = 1
internal let UIA_CHANGE_REMOVED: Int32 = 2
private let UIA_CHANGE_UPDATED: Int32 = 3
private let UIA_CHANGE_MOVED: Int32 = 4
private let UIA_CHANGE_FOCUS: Int32 = 5
private let UIA_ROLE_GENERIC: Int32 = 0
private let UIA_ROLE_TEXT: Int32 = 1
private let UIA_ROLE_BUTTON: Int32 = 2
private let UIA_ROLE_TEXT_FIELD: Int32 = 3
private let UIA_ROLE_CHECKBOX: Int32 = 4
private let UIA_ROLE_SWITCH: Int32 = 5
private let UIA_ROLE_SLIDER: Int32 = 6
private let UIA_ROLE_LIST: Int32 = 7
private let UIA_ROLE_LIST_ITEM: Int32 = 8
private let UIA_ROLE_IMAGE: Int32 = 9
private let UIA_ROLE_DIALOG: Int32 = 10
private let UIA_ROLE_MENU: Int32 = 11
private let UIA_ROLE_MENU_ITEM: Int32 = 12

internal func semanticRoleCode(role: SemanticsRole): Int32 {
    match (role) {
        case SemanticsRole.Generic => UIA_ROLE_GENERIC
        case SemanticsRole.Text => UIA_ROLE_TEXT
        case SemanticsRole.Button => UIA_ROLE_BUTTON
        case SemanticsRole.TextField => UIA_ROLE_TEXT_FIELD
        case SemanticsRole.Checkbox => UIA_ROLE_CHECKBOX
        case SemanticsRole.Switch => UIA_ROLE_SWITCH
        case SemanticsRole.Slider => UIA_ROLE_SLIDER
        case SemanticsRole.List => UIA_ROLE_LIST
        case SemanticsRole.ListItem => UIA_ROLE_LIST_ITEM
        case SemanticsRole.Image => UIA_ROLE_IMAGE
        case SemanticsRole.Dialog => UIA_ROLE_DIALOG
        case SemanticsRole.Menu => UIA_ROLE_MENU
        case SemanticsRole.MenuItem => UIA_ROLE_MENU_ITEM
    }
}

internal func optionalBoolCode(value: ?Bool): Int32 {
    match (value) {
        case Some(true) => 1
        case Some(false) => 0
        case None => -1
    }
}

internal func semanticsActionMask(actions: Array<SemanticsAction>): UInt32 {
    var result = UInt32(0)
    for (action in actions) {
        match (action) {
            case SemanticsAction.Activate => result |= UIA_ACTION_ACTIVATE
            case SemanticsAction.Focus => result |= UIA_ACTION_FOCUS
            case SemanticsAction.Increment => result |= UIA_ACTION_INCREMENT
            case SemanticsAction.Decrement => result |= UIA_ACTION_DECREMENT
            case SemanticsAction.SetValue(_) => result |= UIA_ACTION_SET_VALUE
        }
    }
    result
}

internal func nativeChange(change: SemanticsChange): (String, Int32) {
    match (change) {
        case SemanticsChange.Added(id) => (id, UIA_CHANGE_ADDED)
        case SemanticsChange.Removed(id) => (id, UIA_CHANGE_REMOVED)
        case SemanticsChange.Updated(id) => (id, UIA_CHANGE_UPDATED)
        case SemanticsChange.Moved(id, _, _) => (id, UIA_CHANGE_MOVED)
        case SemanticsChange.FocusChanged(_, id) => (id, UIA_CHANGE_FOCUS)
    }
}
