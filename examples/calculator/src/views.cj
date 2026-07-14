/*
 * 计算器视图层：均匀键盘网格 + 双行显示屏。
 *
 *  - 每个键都是等权 Flexible 单元；“0”以 weight 2.0 精确横跨上方两列
 *  - 键面角色与样式由 CalcKey 一处映射，新增按键时编译器强制补全
 *  - 尺寸一律使用 vp/fp 单位
 */
package cui_calculator

import cui.{Button, ButtonRole, Color, FontSizes, HStack, Icon, IconName, Label, LengthUnits, Panel, SegmentedControl,
    Spacer, SurfaceStyle, TextAlign, VStack}

func calculatorView(model: CalcModel): Unit {
    VStack {
        HStack {
            Icon(IconName.Calculator).foregroundColor(Color.rgb(106, 168, 255))
            Label("计算器").fontSize(FontSizes.TITLE)
            Spacer()
            SegmentedControl(["标准", "科学"], model.mode)
        }.hug()
        displayPanel(model)
        if (model.mode.value == 1) {
            keypadRow(model, scientificRow())
        }
        for (row in standardRows()) {
            keypadRow(model, row)
        }
        HStack {
            calcKey(model, CalcKey.Digit("0"), weight: 2.0)
            calcKey(model, CalcKey.Dot)
            calcKey(model, CalcKey.Equals)
        }.spacing(10.vp)
    }.spacing(10.vp).padding(16.vp)
}

func displayPanel(model: CalcModel): Unit {
    Panel {
        VStack {
            Label(pendingText(model)).muted().textAlign(TextAlign.Trailing).fontSize(FontSizes.CAPTION)
            Label(model.display)
                .textAlign(TextAlign.Trailing)
                .foregroundColor(Color.rgb(248, 250, 252))
                .fontSize(FontSizes.DISPLAY)
        }.spacing(6.vp).hug()
    }.contentPadding(18.vp, 16.vp).style(displaySurface()).hug()
}

// 结果上方的小字行：已存操作数与待定运算符；空占位保证显示屏高度稳定。
func pendingText(model: CalcModel): String {
    match (model.pending) {
        case Some(op) => "${formatValue(model.stored)} ${opSymbol(op)}"
        case None => " "
    }
}

func keypadRow(model: CalcModel, keys: Array<CalcKey>): Unit {
    HStack {
        for (key in keys) {
            calcKey(model, key)
        }
    }.spacing(10.vp)
}

// 一个键 = 一个弹性网格单元。等权成等列；“0”键传 weight 2.0，恰好横跨两列。
func calcKey(model: CalcModel, key: CalcKey, weight!: Float32 = 1.0): Unit {
    let button = Button(key.caption(), {=> press(model, key)}).role(keyRole(key)).fontSize(FontSizes.TITLE)
    match (keyStyle(key)) {
        case Some(style) => button.style(style)
        case None => ()
    }
    let _ = button.flex(weight)
}

func keyRole(key: CalcKey): ButtonRole {
    match (key) {
        case CalcKey.Equals => ButtonRole.Primary
        case _ => ButtonRole.Normal
    }
}

// 数字键保持主题常规键面；运算符与函数键各用一套可复用样式。映射集中在此一处。
func keyStyle(key: CalcKey): ?SurfaceStyle {
    match (key) {
        case CalcKey.Op(_) => Some(operatorKeySurface())
        case CalcKey.AllClear | CalcKey.Negate | CalcKey.Percent => Some(functionKeySurface())
        case CalcKey.SquareRoot | CalcKey.Square | CalcKey.Reciprocal | CalcKey.Pi => Some(functionKeySurface())
        case _ => None<SurfaceStyle>
    }
}
