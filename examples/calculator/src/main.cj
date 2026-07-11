/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
/*
 * CUI example: a desktop calculator.
 *
 * What it demonstrates:
 *  - a uniform keypad grid built from `Flexible` cells — every key stretches to an
 *    equal column, and the zero key spans two columns with `Flexible(weight: 2.0)`
 *  - view state derived from the model each frame (the pending-operation line)
 *  - per-key styling: one style function maps key labels to reusable SurfaceStyles
 *  - a mode switch (Std/Sci) that adds a keypad row with plain `if` control flow
 */
package cui_calculator

import std.math.abs
import std.math.sqrt
import cui.Button
import cui.ButtonRole
import cui.Color
import cui.DesktopApp
import cui.Flexible
import cui.FontSizes
import cui.HStack
import cui.Icon
import cui.IconName
import cui.Insets
import cui.Label
import cui.Panel
import cui.SegmentedControl
import cui.Spacer
import cui.State
import cui.SurfaceStyle
import cui.TextAlign
import cui.Theme
import cui.VStack
import cui.WindowSpec

class CalcModel {
    var display = "0"
    var stored: Float64 = 0.0
    var op = ""
    var resetDisplay = true
    var error = false
    let mode = State<Int64>(0)
}

main(): Int64 {
    let model = CalcModel()
    let app = DesktopApp(WindowSpec("CUI 计算器", 480, 600, resizable: false, scale: 1.5), theme: calculatorTheme())
    app.run {
        calculatorView(model)
    }
    return 0
}

// ---------------------------------------------------------------------------- view --

func calculatorView(model: CalcModel): Unit {
    VStack(spacing: 10.0, padding: Insets(16.0)) {
        HStack(flexible: false) {
            Icon(IconName.Calculator, color: Some(Color.rgb(106, 168, 255)))
            Label("计算器", fontSize: FontSizes.TITLE)
            Spacer()
            SegmentedControl(["标准", "科学"], model.mode)
        }
        displayPanel(model)
        if (model.mode.value == 1) {
            keypadRow(model, ["sqrt", "x^2", "1/x", "pi"])
        }
        keypadRow(model, ["AC", "+/-", "%", "/"])
        keypadRow(model, ["7", "8", "9", "*"])
        keypadRow(model, ["4", "5", "6", "-"])
        keypadRow(model, ["1", "2", "3", "+"])
        HStack(spacing: 10.0) {
            calcKey(model, "0", weight: 2.0)
            calcKey(model, ".")
            calcKey(model, "=")
        }
    }
}

func displayPanel(model: CalcModel): Unit {
    Panel(padding: Insets(16.0, 18.0, 16.0, 18.0), style: Some(displaySurface()), flexible: false) {
        VStack(spacing: 6.0, flexible: false) {
            Label(pendingText(model), muted: true, align: TextAlign.Trailing, fontSize: FontSizes.CAPTION)
            Label(model.display, align: TextAlign.Trailing, color: Some(Color.rgb(248, 250, 252)),
                fontSize: FontSizes.DISPLAY)
        }
    }
}

// The small line above the result: the stored operand and pending operator, or a
// blank placeholder so the display height never jumps.
func pendingText(model: CalcModel): String {
    if (model.op == "") {
        " "
    } else {
        "${formatValue(model.stored)} ${model.op}"
    }
}

func keypadRow(model: CalcModel, keys: Array<String>): Unit {
    HStack(spacing: 10.0) {
        for (key in keys) {
            calcKey(model, key)
        }
    }
}

// One key = one flexible grid cell. Equal weights make equal columns; the zero key
// passes weight 2.0 and spans exactly two columns of the rows above it.
func calcKey(model: CalcModel, label: String, weight!: Float32 = 1.0): Unit {
    Flexible(weight: weight) {
        Button(label, {=> press(model, label)}, role: keyRole(label), style: keyStyle(label), fontSize: FontSizes.TITLE)
    }
}

// -------------------------------------------------------------------------- styles --

func calculatorTheme(): Theme {
    Theme(
        Color.rgb(23, 25, 31),
        Color.rgb(31, 35, 44),
        Color.rgb(72, 78, 92),
        Color.rgb(246, 248, 252),
        Color.rgb(159, 168, 184),
        Color.rgb(106, 168, 255),
        Color.rgb(10, 20, 34),
        Color.rgb(255, 117, 117),
        Color.rgb(40, 45, 56),
        Color.rgb(47, 58, 76),
        panelRaised: Color.rgb(45, 51, 64),
        accentSoft: Color.rgb(39, 66, 104),
        shadow: Color.rgba(0, 0, 0, 84),
        radius: 18.0,
        controlRadius: 14.0
    )
}

func displaySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(16, 19, 25),
        border: Color.rgb(61, 70, 86),
        radius: 18.0,
        borderWidth: 1.0,
        shadow: Color.rgba(0, 0, 0, 70),
        shadowOffsetY: 3.0
    )
}

func keyRole(label: String): ButtonRole {
    if (label == "=") {
        ButtonRole.Primary
    } else {
        ButtonRole.Normal
    }
}

// Digits keep the theme's normal button look; the two accent groups get their own
// reusable styles. Returning ?SurfaceStyle keeps the mapping in one obvious place.
func keyStyle(label: String): ?SurfaceStyle {
    if (isOperator(label)) {
        Some(operatorKeySurface())
    } else if (isFunctionKey(label)) {
        Some(functionKeySurface())
    } else {
        None<SurfaceStyle>
    }
}

func operatorKeySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 159, 67),
        border: Color.rgb(255, 178, 104),
        radius: 14.0,
        borderWidth: 1.0,
        shadow: Color.rgba(255, 159, 67, 30),
        shadowOffsetY: 2.0
    )
}

func functionKeySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(61, 68, 82),
        border: Color.rgb(82, 92, 110),
        radius: 14.0,
        borderWidth: 1.0,
        shadow: Color.rgba(0, 0, 0, 36),
        shadowOffsetY: 1.0
    )
}

func isOperator(label: String): Bool {
    label == "+" || label == "-" || label == "*" || label == "/"
}

func isFunctionKey(label: String): Bool {
    label == "AC" || label == "+/-" || label == "%" || label == "sqrt" || label == "x^2" || label == "1/x" || label ==
        "pi"
}

// --------------------------------------------------------------------------- logic --

func press(model: CalcModel, label: String): Unit {
    if (label == "AC") {
        clear(model)
    } else if (label == "+/-") {
        model.display = formatValue(-currentValue(model))
    } else if (label == "%") {
        model.display = formatValue(currentValue(model) / 100.0)
    } else if (label == "sqrt") {
        squareRoot(model)
    } else if (label == "x^2") {
        square(model)
    } else if (label == "1/x") {
        reciprocal(model)
    } else if (label == "pi") {
        model.display = formatValue(3.141592653589793)
        model.resetDisplay = true
    } else if (label == "=") {
        finish(model)
    } else if (isOperator(label)) {
        choose(model, label)
    } else {
        append(model, label)
    }
}

func squareRoot(model: CalcModel): Unit {
    let value = currentValue(model)
    if (value < 0.0) {
        fail(model)
        return
    }
    model.display = formatValue(sqrt(value))
    model.resetDisplay = true
}

func square(model: CalcModel): Unit {
    let value = currentValue(model)
    model.display = formatValue(value * value)
    model.resetDisplay = true
}

func reciprocal(model: CalcModel): Unit {
    let value = currentValue(model)
    if (abs(value) < 0.000001) {
        fail(model)
        return
    }
    model.display = formatValue(1.0 / value)
    model.resetDisplay = true
}

func fail(model: CalcModel): Unit {
    model.display = "ERROR"
    model.error = true
    model.op = ""
}

func clear(model: CalcModel): Unit {
    model.display = "0"
    model.stored = 0.0
    model.op = ""
    model.resetDisplay = true
    model.error = false
}

func append(model: CalcModel, label: String): Unit {
    if (model.error) {
        clear(model)
    }
    if (label == "." && model.display.contains(".")) {
        return
    }
    if (model.resetDisplay || model.display == "0") {
        model.display = if (label == ".") {
            "0."
        } else {
            label
        }
        model.resetDisplay = false
    } else if (model.display.size < 16) {
        model.display = model.display + label
    }
}

func choose(model: CalcModel, op: String): Unit {
    if (model.op != "" && !model.resetDisplay) {
        finish(model)
    } else {
        model.stored = currentValue(model)
    }
    model.op = op
    model.resetDisplay = true
}

func finish(model: CalcModel): Unit {
    if (model.op == "") {
        return
    }
    let rhs = currentValue(model)
    if (model.op == "/" && abs(rhs) < 0.000001) {
        fail(model)
        return
    }
    let result = if (model.op == "+") {
        model.stored + rhs
    } else if (model.op == "-") {
        model.stored - rhs
    } else if (model.op == "*") {
        model.stored * rhs
    } else {
        model.stored / rhs
    }
    model.stored = result
    model.display = formatValue(result)
    model.op = ""
    model.resetDisplay = true
}

func currentValue(model: CalcModel): Float64 {
    parseDisplay(model.display)
}

func formatValue(value: Float64): String {
    if (isWholeNumber(value)) {
        "${Int64(value)}"
    } else {
        "${value}"
    }
}

func isWholeNumber(value: Float64): Bool {
    let rounded = Int64(value)
    abs(value - Float64(rounded)) < 0.000001
}

// ------------------------------------------------------------------------- parsing --

class NumberParser {
    var value: Float64 = 0.0
    var scale: Float64 = 1.0
    var hasDigit = false
    var fractional = false

    func accept(byte: UInt8): Bool {
        if (byte == UInt8(46) && !fractional) {
            fractional = true
            return true
        }
        if (byte < UInt8(48) || byte > UInt8(57)) {
            return false
        }

        hasDigit = true
        let digit = Float64(Int64(byte) - 48)
        if (fractional) {
            scale *= 10.0
            value += digit / scale
        } else {
            value = value * 10.0 + digit
        }
        true
    }
}

func parseDisplay(text: String): Float64 {
    if (text.size == 0 || text == "ERROR") {
        return 0.0
    }

    var i: Int64 = 0
    var negative = false
    if (text[0] == UInt8(45)) {
        negative = true
        i = 1
    }

    let parser = NumberParser()
    while (i < text.size) {
        if (!parser.accept(text[i])) {
            return 0.0
        }
        i += 1
    }

    if (!parser.hasDigit) {
        return 0.0
    }
    if (negative) {
        -parser.value
    } else {
        parser.value
    }
}
