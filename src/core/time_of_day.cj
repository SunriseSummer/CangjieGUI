package cui.core

import sdl.system.Time

/**
 * A time of day — hour (0–23) and minute (0–59) — with no date or zone. It is the value a `TimePicker`
 * binds to. Construction always normalizes into a valid 24-hour time: the total minutes since midnight
 * wrap into 0–1439, so arithmetic that crosses midnight rolls cleanly and a `TimePicker` can never
 * produce (or be seeded with) an impossible time such as 24:00 or 10:75.
 *
 * All arithmetic is pure integer minute math independent of the platform clock; only `now()` reads the
 * system clock.
 */
public struct TimeOfDay <: Equatable<TimeOfDay> {
    public let hour: Int64
    public let minute: Int64

    public init(hour: Int64, minute: Int64) {
        let total = wrapMinutes(hour * 60 + minute)
        this.hour = total / 60
        this.minute = total % 60
    }

    /** The current wall-clock time from the system clock. Throws `CuiException` if it cannot be read. */
    public static func now(): TimeOfDay {
        let t = Time.currentDateTime()
        TimeOfDay(Int64(t.hour), Int64(t.minute))
    }

    /** Minutes since midnight, 0–1439. */
    public func totalMinutes(): Int64 {
        hour * 60 + minute
    }

    /** This time with the hour replaced (wrapped into 0–23), keeping the minute. */
    public func withHour(newHour: Int64): TimeOfDay {
        TimeOfDay(newHour, minute)
    }

    /** This time with the minute replaced (wrapped, carrying into the hour), keeping the hour otherwise. */
    public func withMinute(newMinute: Int64): TimeOfDay {
        TimeOfDay(hour, newMinute)
    }

    /** This time shifted by `delta` minutes, wrapping across midnight exactly. */
    public func addingMinutes(delta: Int64): TimeOfDay {
        // init normalizes hour*60 + minute, so seeding hour 0 with the new total is enough.
        TimeOfDay(0, totalMinutes() + delta)
    }

    /** This time shifted by `delta` hours, wrapping across midnight. */
    public func addingHours(delta: Int64): TimeOfDay {
        addingMinutes(delta * 60)
    }

    /** 24-hour `HH:MM`, zero-padded, e.g. `09:05`. */
    public func format(): String {
        "${padTwo(hour)}:${padTwo(minute)}"
    }

    /** 12-hour clock with meridiem, e.g. `9:05 AM`, `12:30 PM`. */
    public func format12(): String {
        let meridiem = if (hour < 12) {
            "AM"
        } else {
            "PM"
        }
        let base = hour % 12
        let display = if (base == 0) {
            12
        } else {
            base
        }
        "${display}:${padTwo(minute)} ${meridiem}"
    }

    /** Negative when this time precedes `other`, zero when equal, positive when it follows. */
    public func compareTo(other: TimeOfDay): Int64 {
        totalMinutes() - other.totalMinutes()
    }

    public operator func ==(other: TimeOfDay): Bool {
        hour == other.hour && minute == other.minute
    }

    public operator func !=(other: TimeOfDay): Bool {
        !(this == other)
    }
}

// Non-negative modulo into a single day's minutes (0–1439), so negative deltas wrap backward correctly.
private func wrapMinutes(total: Int64): Int64 {
    (total % 1440 + 1440) % 1440
}

private func padTwo(value: Int64): String {
    if (value >= 0 && value < 10) {
        "0${value}"
    } else {
        "${value}"
    }
}
