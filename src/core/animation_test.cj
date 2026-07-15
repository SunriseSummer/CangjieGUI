package cui.core

import sdl.FrameInfo

/*
 * The spring eases toward its target across ticks and settles exactly onto it, so an idle
 * spring is free and a static first frame (target == start) never animates. A clamped
 * timestep keeps a long frame hitch from diverging.
 */
@Test
func springEasesTowardTargetAndSettles(): Unit {
    let spring = Spring(0.0)
    @Expect(spring.settled()) // starts at its target

    spring.target(1.0)
    @Expect(!spring.settled())

    var i = 0
    while (i < 400 && !spring.settled()) {
        spring.tick(UInt64(16))
        i += 1
    }
    @Expect(spring.settled())
    @Expect(spring.value, Float32(1.0))
    @Expect(i < 400) // converged well within the budget
}

@Test
func springRetargetsMidFlight(): Unit {
    let spring = Spring(0.0)
    spring.target(1.0)
    spring.tick(UInt64(16))
    spring.tick(UInt64(16))
    let mid = spring.value
    @Expect(mid > Float32(0.0))
    @Expect(mid < Float32(1.0))

    spring.target(0.0)
    var i = 0
    while (i < 400 && !spring.settled()) {
        spring.tick(UInt64(16))
        i += 1
    }
    @Expect(spring.value, Float32(0.0))
}

@Test
func springResetSnapsWithoutAnimating(): Unit {
    let spring = Spring(0.0)
    spring.target(1.0)
    spring.reset(0.5)
    @Expect(spring.settled())
    @Expect(spring.value, Float32(0.5))
}

// The draw-time convenience retargets and advances in one call, returning the new value; over
// enough frames it reaches the target and settles.
@Test
func springAnimateRetargetsAdvancesAndReturnsValue(): Unit {
    let spring = Spring(0.0)
    // A fresh spring starts settled; animate itself sets the target, so drive a fixed number of
    // frames rather than guarding on settled().
    let first = spring.animate(target: 1.0, deltaMs: UInt64(16))
    @Expect(first > Float32(0.0)) // moved off the start on the first frame
    @Expect(first < Float32(1.0))

    var v: Float32 = first
    for (_ in 0..400) {
        v = spring.animate(target: 1.0, deltaMs: UInt64(16))
    }
    @Expect(spring.settled())
    @Expect(v, Float32(1.0))
    @Expect(spring.value, Float32(1.0))
}

// animate(target, deltaMs) is exactly target(goal) + tick(delta) + read value — the same
// trajectory, just folded into one call.
@Test
func springAnimateMatchesTargetThenTick(): Unit {
    let viaAnimate = Spring(0.0)
    let viaSteps = Spring(0.0)
    var i = 0
    while (i < 30) {
        let a = viaAnimate.animate(target: 1.0, deltaMs: UInt64(16))
        viaSteps.target(1.0)
        viaSteps.tick(UInt64(16))
        @Expect(a, viaSteps.value)
        i += 1
    }
}

@Test
func springClampsHugeTimestepInsteadOfDiverging(): Unit {
    let spring = Spring(0.0)
    spring.target(1.0)
    spring.tick(UInt64(100000)) // a 100-second hitch
    @Expect(spring.value >= Float32(0.0))
    @Expect(spring.value <= Float32(2.0)) // bounded: the clamp prevented a blow-up
}

// The ctx form keeps frames coming while the spring is in motion, so the dirty-frame loop (档 0) does
// not idle mid-transition and freeze a switch/radio/progress animation; a settled spring asks for
// nothing, so an idle control still costs no frames.
@Test
func springCtxAnimateRequestsFrameWhileMoving(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(16), UInt64(16)) // deltaMs = 16
    let spring = Spring(0.0)

    // Already at its target: no motion, no request.
    let _ = ctx.takeFrameRequest()
    let _ = spring.animate(ctx, target: 0.0)
    @Expect(!ctx.takeFrameRequest())

    // Retargeted away: now moving, so it must ask for the next frame.
    let _ = ctx.takeFrameRequest()
    let _ = spring.animate(ctx, target: 1.0)
    @Expect(!spring.settled())
    @Expect(ctx.takeFrameRequest())

    // Drive it to rest, then it stops asking.
    var i = 0
    while (i < 400 && !spring.settled()) {
        let _ = spring.animate(ctx, target: 1.0)
        i += 1
    }
    @Expect(spring.settled())
    let _ = ctx.takeFrameRequest()
    let _ = spring.animate(ctx, target: 1.0)
    @Expect(!ctx.takeFrameRequest())
}
