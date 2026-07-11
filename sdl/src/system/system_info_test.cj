/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

@Test
func powerStateFromCodeMapsSdlValues(): Unit {
    @Expect(isPowerError(powerStateFromCode(-1)))
    @Expect(isPowerUnknown(powerStateFromCode(0)))
    @Expect(isOnBattery(powerStateFromCode(1)))
    @Expect(isNoBattery(powerStateFromCode(2)))
    @Expect(isCharging(powerStateFromCode(3)))
    @Expect(isCharged(powerStateFromCode(4)))
    @Expect(isPowerUnknown(powerStateFromCode(99)))
}

@Test
func platformAndCpuInfoReturnUsefulValues(): Unit {
    let cpu = cpuInfo()

    @Expect(platformName().size > 0)
    @Expect(cpu.logicalCores > 0)
    @Expect(cpu.systemRamMb > 0)
}

private func isPowerError(state: PowerState): Bool {
    match (state) {
        case PowerState.Error => true
        case _ => false
    }
}

private func isPowerUnknown(state: PowerState): Bool {
    match (state) {
        case PowerState.Unknown => true
        case _ => false
    }
}

private func isOnBattery(state: PowerState): Bool {
    match (state) {
        case PowerState.OnBattery => true
        case _ => false
    }
}

private func isNoBattery(state: PowerState): Bool {
    match (state) {
        case PowerState.NoBattery => true
        case _ => false
    }
}

private func isCharging(state: PowerState): Bool {
    match (state) {
        case PowerState.Charging => true
        case _ => false
    }
}

private func isCharged(state: PowerState): Bool {
    match (state) {
        case PowerState.Charged => true
        case _ => false
    }
}
