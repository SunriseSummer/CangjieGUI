/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.displays

import sdl.{SDL_ORIENTATION_LANDSCAPE, SDL_ORIENTATION_LANDSCAPE_FLIPPED, SDL_ORIENTATION_PORTRAIT, 
    SDL_ORIENTATION_PORTRAIT_FLIPPED, SDL_ORIENTATION_UNKNOWN, SdlDisplayMode}

@Test
func displayOrientationFromCodeMapsSdlValues(): Unit {
    @Expect(isUnknownOrientation(displayOrientationFromCode(SDL_ORIENTATION_UNKNOWN)))
    @Expect(isLandscape(displayOrientationFromCode(SDL_ORIENTATION_LANDSCAPE)))
    @Expect(isLandscapeFlipped(displayOrientationFromCode(SDL_ORIENTATION_LANDSCAPE_FLIPPED)))
    @Expect(isPortrait(displayOrientationFromCode(SDL_ORIENTATION_PORTRAIT)))
    @Expect(isPortraitFlipped(displayOrientationFromCode(SDL_ORIENTATION_PORTRAIT_FLIPPED)))
    @Expect(isUnknownOrientation(displayOrientationFromCode(99)))
}

@Test
func displayModeFromRawPreservesPublicFields(): Unit {
    var raw = SdlDisplayMode()
    raw.w = 1920
    raw.h = 1080
    raw.pixelDensity = 2.0
    raw.refreshRate = 60.0

    let mode = displayModeFromRaw(raw)

    @Expect(mode.width, 1920)
    @Expect(mode.height, 1080)
    @Expect(mode.pixelDensity, 2.0)
    @Expect(mode.refreshRate, 60.0)
}

@Test
func displayModeFromRawNormalizesInvalidPixelDensity(): Unit {
    var raw = SdlDisplayMode()
    raw.w = 800
    raw.h = 600
    raw.pixelDensity = 0.0

    let mode = displayModeFromRaw(raw)

    @Expect(mode.pixelDensity, 1.0)
}

@Test
func fullscreenModeRequestKeepsSafeDefaults(): Unit {
    let request = FullscreenModeRequest(1280, 720)

    @Expect(request.width, 1280)
    @Expect(request.height, 720)
    @Expect(request.refreshRate, 0.0)
    @Expect(request.includeHighDensityModes)
}

@Test
func displayIdsFromPointerCopiesReturnedIds(): Unit {
    let ids = unsafe { LibC.malloc<UInt32>(count: 2) }
    try (resource = ids.asResource()) {
        unsafe {
            resource.value.write(0, UInt32(11))
            resource.value.write(1, UInt32(22))
        }

        let values = displayIdsFromPointer(resource.value, 2)

        @Expect(values.size, Int64(2))
        @Expect(values[0], UInt32(11))
        @Expect(values[1], UInt32(22))
    }
}

@Test
func displayModesFromPointersSkipsNullEntries(): Unit {
    let first = unsafe { LibC.malloc<SdlDisplayMode>() }
    let list = unsafe { LibC.malloc<CPointer<SdlDisplayMode>>(count: 2) }
    try (firstResource = first.asResource()) {
        try (listResource = list.asResource()) {
            var raw = SdlDisplayMode()
            raw.w = 2560
            raw.h = 1440
            raw.pixelDensity = 1.25
            raw.refreshRate = 144.0
            unsafe {
                firstResource.value.write(raw)
                listResource.value.write(0, firstResource.value)
                listResource.value.write(1, CPointer<SdlDisplayMode>())
            }

            let modes = displayModesFromPointers(listResource.value, 2)

            @Expect(modes.size, Int64(1))
            @Expect(modes[0].width, 2560)
            @Expect(modes[0].height, 1440)
            @Expect(modes[0].refreshRate, 144.0)
        }
    }
}

private func isUnknownOrientation(orientation: DisplayOrientation): Bool {
    match (orientation) {
        case DisplayOrientation.Unknown => true
        case _ => false
    }
}

private func isLandscape(orientation: DisplayOrientation): Bool {
    match (orientation) {
        case DisplayOrientation.Landscape => true
        case _ => false
    }
}

private func isLandscapeFlipped(orientation: DisplayOrientation): Bool {
    match (orientation) {
        case DisplayOrientation.LandscapeFlipped => true
        case _ => false
    }
}

private func isPortrait(orientation: DisplayOrientation): Bool {
    match (orientation) {
        case DisplayOrientation.Portrait => true
        case _ => false
    }
}

private func isPortraitFlipped(orientation: DisplayOrientation): Bool {
    match (orientation) {
        case DisplayOrientation.PortraitFlipped => true
        case _ => false
    }
}
