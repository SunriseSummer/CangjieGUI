/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.desktop

@Test
func tickDeltaGuardsAgainstClockReset(): Unit {
    @Expect(tickDelta(UInt64(10), UInt64(25)), UInt64(15))
    @Expect(tickDelta(UInt64(25), UInt64(10)), UInt64(0))
}
