/*
 * 通知示例的类型名称与文案（纯函数）。
 */
package cui_notify

import cui.ToastKind

func messageFor(kind: ToastKind, n: Int64): String {
    match (kind) {
        case ToastKind.Success => "操作成功完成（第 ${n} 条）"
        case ToastKind.Info => "这是一条信息提示（第 ${n} 条）"
        case ToastKind.Warning => "磁盘空间偏低，请及时清理（第 ${n} 条）"
        case ToastKind.Error => "操作失败，请稍后重试（第 ${n} 条）"
    }
}
