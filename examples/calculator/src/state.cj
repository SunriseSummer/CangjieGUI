/*
 * 计算器的数据模型与按键词汇表。
 *
 * 按键与运算符都是枚举：match 穷尽保证新增按键时编译器强制补全每一处分支，
 * 不存在字符串拼写错漏的空间。
 */
package cui_calculator

import cui.State

/* 数值边界：显示位数上限、整数吸附阈值与整数显示范围。除零判定用精确的 == 0.0。 */
struct Limit {
    static let DIGITS: Int64 = 15
    static let PERCENT: Float64 = 100.0
    static let INTEGER_EPSILON: Float64 = 0.000001
    /* 超出 Int64 精确范围的值保持浮点显示，避免转换溢出。 */
    static let INTEGER_RANGE: Float64 = 1.0e15
}

struct DisplayText {
    static let ZERO: String = "0"
    static let ERROR: String = "ERROR"
}

let PI_VALUE: Float64 = 3.141592653589793

enum CalcOp {
    | Add
    | Subtract
    | Multiply
    | Divide
}

enum CalcKey {
    | Digit(String)
    | Dot
    | Op(CalcOp)
    | Equals
    | AllClear
    | Negate
    | Percent
    | SquareRoot
    | Square
    | Reciprocal
    | Pi

    func caption(): String {
        match (this) {
            case Digit(text) => text
            case Dot => "."
            case Op(op) => opSymbol(op)
            case Equals => "="
            case AllClear => "AC"
            case Negate => "+/-"
            case Percent => "%"
            case SquareRoot => "√x"
            case Square => "x²"
            case Reciprocal => "1/x"
            case Pi => "π"
        }
    }
}

func opSymbol(op: CalcOp): String {
    match (op) {
        case CalcOp.Add => "+"
        case CalcOp.Subtract => "−"
        case CalcOp.Multiply => "×"
        case CalcOp.Divide => "÷"
    }
}

class CalcModel {
    let display = State<String>(DisplayText.ZERO)
    var stored: Float64 = 0.0
    let pending = State<?CalcOp>(None)
    var resetDisplay = true
    var error = false
    let mode = State<Int64>(0)
}

/* 键盘区行定义：视图按行渲染，科学模式在标准行之上多一行函数键。 */
func scientificRow(): Array<CalcKey> {
    [CalcKey.SquareRoot, CalcKey.Square, CalcKey.Reciprocal, CalcKey.Pi]
}

func standardRows(): Array<Array<CalcKey>> {
    [
        [CalcKey.AllClear, CalcKey.Negate, CalcKey.Percent, CalcKey.Op(CalcOp.Divide)],
        [CalcKey.Digit("7"), CalcKey.Digit("8"), CalcKey.Digit("9"), CalcKey.Op(CalcOp.Multiply)],
        [CalcKey.Digit("4"), CalcKey.Digit("5"), CalcKey.Digit("6"), CalcKey.Op(CalcOp.Subtract)],
        [CalcKey.Digit("1"), CalcKey.Digit("2"), CalcKey.Digit("3"), CalcKey.Op(CalcOp.Add)]
    ]
}
