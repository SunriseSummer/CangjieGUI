/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

@Test
func windowSpecNormalizesInvalidScale(): Unit {
    let spec = WindowSpec("Scale", 100, 100, scale: -2.0)

    @Expect(spec.scale, Float32(1.0))
    @Expect(scaledDimension(10, 1.5), Int32(15))
}

@Test
func windowFlagsFromRawMapsKnownBits(): Unit {
    let raw = SDL_WINDOW_FULLSCREEN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_MOUSE_RELATIVE_MODE | SDL_WINDOW_NOT_FOCUSABLE

    let flags = windowFlagsFromRaw(raw)

    @Expect(flags.raw, raw)
    @Expect(flags.fullscreen)
    @Expect(flags.resizable)
    @Expect(flags.relativeMouseMode)
    @Expect(flags.notFocusable)
    @Expect(!flags.hidden)
    @Expect(!flags.vulkan)
}

@Test
func windowSizeFromPixelsUsesNormalizedScale(): Unit {
    let scaled = windowSizeFromPixels(300, 180, 2.0)
    let fallback = windowSizeFromPixels(300, 180, 0.0)

    @Expect(scaled.w, 150.0)
    @Expect(scaled.h, 90.0)
    @Expect(fallback.w, 300.0)
    @Expect(fallback.h, 180.0)
}

@Test
func windowProgressStateFromCodeMapsSdlValues(): Unit {
    @Expect(isNoProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_NONE)))
    @Expect(isIndeterminate(windowProgressStateFromCode(SDL_PROGRESS_STATE_INDETERMINATE)))
    @Expect(isNormalProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_NORMAL)))
    @Expect(isPausedProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_PAUSED)))
    @Expect(isErrorProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_ERROR)))
    @Expect(isUnknownProgress(windowProgressStateFromCode(SDL_PROGRESS_STATE_INVALID)))
    @Expect(isUnknownProgress(windowProgressStateFromCode(99)))
}

@Test
func windowProgressStateCodeMapsPublicEnum(): Unit {
    @Expect(windowProgressStateCode(WindowProgressState.Inactive), SDL_PROGRESS_STATE_NONE)
    @Expect(windowProgressStateCode(WindowProgressState.Indeterminate), SDL_PROGRESS_STATE_INDETERMINATE)
    @Expect(windowProgressStateCode(WindowProgressState.Normal), SDL_PROGRESS_STATE_NORMAL)
    @Expect(windowProgressStateCode(WindowProgressState.Paused), SDL_PROGRESS_STATE_PAUSED)
    @Expect(windowProgressStateCode(WindowProgressState.Error), SDL_PROGRESS_STATE_ERROR)
}

private func isNoProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Inactive => true
            case _ => false
        }
        case None => false
    }
}

private func isIndeterminate(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Indeterminate => true
            case _ => false
        }
        case None => false
    }
}

private func isNormalProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Normal => true
            case _ => false
        }
        case None => false
    }
}

private func isPausedProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Paused => true
            case _ => false
        }
        case None => false
    }
}

private func isErrorProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(value) => match (value) {
            case WindowProgressState.Error => true
            case _ => false
        }
        case None => false
    }
}

private func isUnknownProgress(state: ?WindowProgressState): Bool {
    match (state) {
        case Some(_) => false
        case None => true
    }
}
