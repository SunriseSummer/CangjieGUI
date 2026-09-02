[cui](../../index.md) › [cui.controls](index.md) › TimeOfDay

# TimeOfDay

位于 `cui.controls` 包的公开结构体

表示一天内的时刻，只有小时（0–23）和分钟（0–59），不含日期与时区；[`TimePicker`](TimePicker.md) 用它保存选中时间。构造时会把任意小时和分钟换算成合法的 24 小时制：总分钟数超过一天就从午夜重新开始，负数则向前回绕。因此 `TimePicker` 不会保留 24:00、10:75 这类无效时间。

## 声明

```cangjie
public struct TimeOfDay <: Equatable<TimeOfDay>
```

## 继承

- `Equatable<TimeOfDay>`（标准库 `std.core`）

## 说明

全部运算是纯整数分钟算术，与平台时钟无关；只有 `now()` 读系统时钟。值不可变，`with…`/`adding…` 系列返回调整后的新值。`compareTo` 是同一天内的平面钟面比较（总分钟差），不含跨午夜语义——23:30 晚于 00:15。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let meeting = TimeOfDay(9, 30)
    let overtime = meeting.addingMinutes(45)
    println(overtime.format())
    let lateShift = TimeOfDay(23, 30).addingHours(1)
    println(lateShift.format())
    println(lateShift.format12())
    // 构造归一化：分钟溢出进位到小时
    println("${TimeOfDay(10, 75) == TimeOfDay(11, 15)}")
    println("${meeting.compareTo(overtime)}")
    // 输出:
    // 10:15
    // 00:30
    // 12:30 AM
    // true
    // -45
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(hour: Int64, minute: Int64)`](#init) | 以时与分构造时刻，总分钟数回绕归一化进一天。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static now()`](#now) | 从系统时钟读取当前墙钟时刻。 |
| [`totalMinutes()`](#totalminutes) | 自午夜起的分钟数，0–1439。 |
| [`withHour(newHour: Int64)`](#withhour) | 返回替换小时（回绕进 0–23）、保留分钟的新时刻。 |
| [`withMinute(newMinute: Int64)`](#withminute) | 返回替换分钟（回绕，溢出进位到小时）的新时刻。 |
| [`addingMinutes(delta: Int64)`](#addingminutes) | 返回平移 `delta` 分钟、跨午夜精确回卷的新时刻。 |
| [`addingHours(delta: Int64)`](#addinghours) | 返回平移 `delta` 小时、跨午夜回卷的新时刻。 |
| [`format()`](#format) | 24 小时制 `HH:MM`，零填充。 |
| [`format12()`](#format12) | 12 小时制带上下午标记。 |
| [`compareTo(other: TimeOfDay)`](#compareto) | 早于 `other` 为负、相等为零、晚于为正。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`hour`](#hour) | 小时，0–23。 |
| [`minute`](#minute) | 分钟，0–59。 |

**运算符**

| 成员 | 说明 |
|---|---|
| [`operator ==`](#operator) | 时与分都相同则相等。 |
| [`operator !=`](#operator-1) | 相等判断的取反。 |

## 构造函数

### init

以时与分构造时刻，总分钟数回绕归一化进一天。`hour * 60 + minute` 回绕进 0–1439 后再拆回时与分，因此任何整数组合（包括负值与溢出）都得到合法时刻：`TimeOfDay(10, 75)` 即 11:15，`TimeOfDay(0, -30)` 即 23:30。

```cangjie
public init(hour: Int64, minute: Int64)
```

**参数**

- `hour`: `Int64` — 小时，可越界，参与总分钟归一化。
- `minute`: `Int64` — 分钟，可越界，参与总分钟归一化。

## 方法

### now

从系统时钟读取当前墙钟时刻。

```cangjie
public static func now(): TimeOfDay
```

**返回值** `TimeOfDay` — 当前系统时间的时与分。

**异常**

- `SdlException` — `Time.currentDateTime()`（见同版本 SDL API 参考中的 `sdl.system.Time`）读取系统实时钟或把时间戳换算为本地时间字段失败时；CUI 不捕获或改写该异常。

### totalMinutes

自午夜起的分钟数，0–1439。两个时刻的钟面先后可直接比较此值（或用 [`compareTo`](#compareto)）。

```cangjie
public func totalMinutes(): Int64
```

**返回值** `Int64` — `hour * 60 + minute`。

### withHour

返回替换小时（回绕进 0–23）、保留分钟的新时刻。

```cangjie
public func withHour(newHour: Int64): TimeOfDay
```

**参数**

- `newHour`: `Int64` — 新的小时值，可越界，回绕归一化。

**返回值** `TimeOfDay` — 分钟不变的新时刻。

### withMinute

返回替换分钟（回绕，溢出进位到小时）的新时刻。传入 0–59 之外的值按总分钟归一化：10:00 上 `withMinute(75)` 得 11:15。

```cangjie
public func withMinute(newMinute: Int64): TimeOfDay
```

**参数**

- `newMinute`: `Int64` — 新的分钟值，可越界，溢出进位到小时。

**返回值** `TimeOfDay` — 归一化后的新时刻。

### addingMinutes

返回平移 `delta` 分钟、跨午夜精确回卷的新时刻。负值向前回卷：00:10 上 `addingMinutes(-30)` 得 23:40。

```cangjie
public func addingMinutes(delta: Int64): TimeOfDay
```

**参数**

- `delta`: `Int64` — 平移的分钟数，正负均可。

**返回值** `TimeOfDay` — 回卷后的新时刻。

### addingHours

返回平移 `delta` 小时、跨午夜回卷的新时刻。等价于 `addingMinutes(delta * 60)`。

```cangjie
public func addingHours(delta: Int64): TimeOfDay
```

**参数**

- `delta`: `Int64` — 平移的小时数，正负均可。

**返回值** `TimeOfDay` — 回卷后的新时刻。

### format

24 小时制 `HH:MM`，零填充。如 `09:05`。

```cangjie
public func format(): String
```

**返回值** `String` — 恒为 5 个字符的 `HH:MM`。

### format12

12 小时制带上下午标记。小时 0 显示为 `12` 配 `AM`，12 显示为 `12` 配 `PM`，如 `9:05 AM`、`12:30 PM`。

```cangjie
public func format12(): String
```

**返回值** `String` — `H:MM AM` 或 `H:MM PM`，小时不零填充。

### compareTo

早于 `other` 为负、相等为零、晚于为正。按总分钟差计算，是同一天内的钟面比较，不含跨午夜语义。

```cangjie
public func compareTo(other: TimeOfDay): Int64
```

**参数**

- `other`: `TimeOfDay` — 比较对象。

**返回值** `Int64` — `totalMinutes() - other.totalMinutes()`，即两时刻相差的分钟数。

## 字段

### hour

小时，0–23。构造归一化保证范围。

```cangjie
public let hour: Int64
```

### minute

分钟，0–59。构造归一化保证范围。

```cangjie
public let minute: Int64
```

## 运算符

### operator==

时与分都相同则相等。

```cangjie
public operator func ==(other: TimeOfDay): Bool
```

**参数**

- `other`: `TimeOfDay` — 比较对象。

**返回值** `Bool` — `hour` 与 `minute` 都相同时为 `true`。

### operator!=

相等判断的取反。

```cangjie
public operator func !=(other: TimeOfDay): Bool
```

**参数**

- `other`: `TimeOfDay` — 比较对象。

**返回值** `Bool` — 时或分任一不同则为 `true`。

## 另请参阅

- [TimePicker](TimePicker.md) — 绑定此值类型的时间选择控件。
- [CalendarDate](CalendarDate.md) — 与之对偶的纯日期值。
