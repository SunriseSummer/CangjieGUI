[cui](../../index.md) › [cui.controls](index.md) › CalendarDate

# CalendarDate

`cui.controls` 包中的 public struct

一个日历日——年、月（1–12）、日（1–31），不含时刻与时区。它是 [`DatePicker`](DatePicker.md) 绑定的值类型；构造时会把月份限制在 1–12，并把日期限制在该月的有效天数内，所以下游代码不会见到 2 月 30 日这类无效日期。

## 声明

```cangjie
public struct CalendarDate <: Equatable<CalendarDate>
```

## 继承

- `Equatable<CalendarDate>`（标准库 `std.core`）

## 说明

日历算术（闰年、每月天数、星期、跨月和跨年进位）按常用公历规则计算，不读取系统时钟，因此同一输入总会得到同一结果；只有 [`today`](#today) 会读取系统时间。这里的公历规则也用于公历正式采用前的年份，年份可以为负。所有运算方法都返回新值，不会修改原对象。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let checkIn = CalendarDate(2026, 7, 19)
    let checkOut = checkIn.addingDays(13)
    println(checkOut.iso())
    println(checkIn.daysInMonth())
    // 非法输入被限制：2026 年不是闰年，2 月 30 日落到 2 月 28 日
    println(CalendarDate(2026, 2, 30).iso())
    // 输出:
    // 2026-08-01
    // 31
    // 2026-02-28
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(year: Int64, month: Int64, day: Int64)`](#init) | 由年、月、日构造；月份和日期超出有效范围时取最近的有效值，因此结果始终是合法日期。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static today()`](#today) | 从系统时钟读取今天的日期。 |
| [`daysInMonth()`](#daysinmonth) | 返回本月的天数，并自动处理闰年二月。 |
| [`weekdayIndex()`](#weekdayindex) | 本日期的星期：0 = 周日 到 6 = 周六。 |
| [`firstWeekdayIndex()`](#firstweekdayindex) | 本月 1 号的星期：0 = 周日 到 6 = 周六。 |
| [`withDay(newDay: Int64)`](#withday) | 替换“日”分量；超出本月范围时取最近的有效日期，年月不变。 |
| [`addingMonths(delta: Int64)`](#addingmonths) | 平移 `delta` 个整月；日限制在目标月的长度。 |
| [`addingDays(delta: Int64)`](#addingdays) | 平移 `delta` 个整天，跨月跨年精确进位。 |
| [`iso()`](#iso) | ISO-8601 的 `YYYY-MM-DD`，零填充。 |
| [`compareTo(other: CalendarDate)`](#compareto) | 早于 `other` 为负、相等为零、晚于为正。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`year`](#year) | 年份，按同一套公历规则计算，也支持负数。 |
| [`month`](#month) | 月份，1–12。 |
| [`day`](#day) | 日期，1 到当月天数。 |

**运算符**

| 成员 | 说明 |
|---|---|
| [`operator ==`](#operator) | 年、月、日全部相等则相等。 |
| [`operator !=`](#operator-1) | 相等判断的取反。 |

## 构造函数

### init

由年、月、日构造；月份和日期超出有效范围时取最近的有效值，因此结果始终是合法日期。

```cangjie
public init(year: Int64, month: Int64, day: Int64)
```

**参数**

- `year`: `Int64` — 年份，不限制。
- `month`: `Int64` — 月份；小于 1 时取 1，大于 12 时取 12。
- `day`: `Int64` — 日期；超出当月有效范围时取最近的有效日期（如 2026-02-30 会变为 2026-02-28）。

## 方法

### today

从系统时钟读取今天的日期。

```cangjie
public static func today(): CalendarDate
```

**返回值** `CalendarDate` — 本地时区的当前日期。

**异常**

- `SdlException` — `Time.currentDateTime()`（见同版本 SDL API 参考中的 `sdl.system.Time`）读取系统实时钟或把时间戳换算为本地日历字段失败时；CUI 不捕获或改写该异常。

### daysInMonth

返回本月的天数，并自动处理闰年二月。

```cangjie
public func daysInMonth(): Int64
```

**返回值** `Int64` — 28 到 31。

### weekdayIndex

本日期的星期：0 = 周日 到 6 = 周六。

```cangjie
public func weekdayIndex(): Int64
```

**返回值** `Int64` — 0–6。

### firstWeekdayIndex

本月 1 号的星期：0 = 周日 到 6 = 周六。月历网格的首行偏移即由它得出。

```cangjie
public func firstWeekdayIndex(): Int64
```

**返回值** `Int64` — 0–6。

### withDay

替换“日”分量；超出本月范围时取最近的有效日期，年月不变。

```cangjie
public func withDay(newDay: Int64): CalendarDate
```

**参数**

- `newDay`: `Int64` — 新的日期；小于 1 时取 1，超过当月天数时取该月最后一天。

**返回值** `CalendarDate` — 替换后的新日期。

### addingMonths

平移 `delta` 个整月；日限制在目标月的长度。例如 1 月 31 日加一个月落到 2 月 28/29 日。

```cangjie
public func addingMonths(delta: Int64): CalendarDate
```

**参数**

- `delta`: `Int64` — 平移的月数，可为负；跨年自动进位。

**返回值** `CalendarDate` — 平移后的新日期。

### addingDays

平移 `delta` 个整天，跨月跨年精确进位。

```cangjie
public func addingDays(delta: Int64): CalendarDate
```

**参数**

- `delta`: `Int64` — 平移的天数，可为负。

**返回值** `CalendarDate` — 平移后的新日期。

### iso

ISO-8601 的 `YYYY-MM-DD`，零填充。

```cangjie
public func iso(): String
```

**返回值** `String` — 如 `2026-08-01`；负数年份按原样带符号输出。

### compareTo

早于 `other` 为负、相等为零、晚于为正。差值即两日期相隔的天数。

```cangjie
public func compareTo(other: CalendarDate): Int64
```

**参数**

- `other`: `CalendarDate` — 比较对象。

**返回值** `Int64` — 本日期减 `other` 的天数差。

## 字段

### year

年份，按同一套公历规则计算，也支持负数。计算不会因历史上采用公历的日期不同而改变。

```cangjie
public let year: Int64
```

### month

月份，1–12。构造时已限制在这个范围内。

```cangjie
public let month: Int64
```

### day

日期，1 到当月天数。构造时已限制在这个范围内。

```cangjie
public let day: Int64
```

## 运算符

### operator==

年、月、日全部相等则相等。

```cangjie
public operator func ==(other: CalendarDate): Bool
```

**参数**

- `other`: `CalendarDate` — 比较对象。

**返回值** `Bool` — 三个分量全部相同时为 `true`。

### operator!=

相等判断的取反。

```cangjie
public operator func !=(other: CalendarDate): Bool
```

**参数**

- `other`: `CalendarDate` — 比较对象。

**返回值** `Bool` — 任一分量不同时为 `true`。

## 另请参阅

- [DatePicker](DatePicker.md) — 绑定本类型的日期选择控件。
- [TimeOfDay](TimeOfDay.md) — 与本类型互补的一天内时刻值。
