/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

@Test
func keyFromScancodeMapsLettersAndControls(): Unit {
    match (keyFromScancode(SDL_SCANCODE_A)) {
        case Key.Letter(value) => @Expect(value, UInt8(65))
        case _ => @Fail("A scancode should map to Key.Letter.")
    }

    match (keyFromScancode(SDL_SCANCODE_ESCAPE)) {
        case Key.Escape => @Expect(true)
        case _ => @Fail("Escape scancode should map to Key.Escape.")
    }

    match (keyFromScancode(SDL_SCANCODE_HOME)) {
        case Key.Home => @Expect(true)
        case _ => @Fail("Home scancode should map to Key.Home.")
    }
}

@Test
func buttonFromCodeMapsKnownButtons(): Unit {
    match (buttonFromCode(SDL_BUTTON_LEFT)) {
        case MouseButton.Left => @Expect(true)
        case _ => @Fail("Left button code should map to MouseButton.Left.")
    }

    match (buttonFromCode(UInt8(9))) {
        case MouseButton.RawCode(value) => @Expect(value, UInt8(9))
        case _ => @Fail("Unknown button code should map to MouseButton.RawCode.")
    }
}

@Test
func mouseEventsScaleCoordinates(): Unit {
    let event = scaleEventCoordinates(UiEvent.MouseDown(MouseButton.Left, 30.0, 45.0), 1.5)

    match (event) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            @Expect(x, Float32(20.0))
            @Expect(y, Float32(30.0))
        case _ => @Fail("Scaled event should remain a left mouse down event.")
    }
}

@Test
func dropEventsDecodeFileData(): Unit {
    let event = decodeRawDrop(SDL_EVENT_DROP_FILE, "C:/tmp/note.txt", 30.0, 45.0)

    match (event) {
        case UiEvent.DropFile(path, x, y) =>
            @Expect(path, "C:/tmp/note.txt")
            @Expect(x, Float32(30.0))
            @Expect(y, Float32(45.0))
        case _ => @Fail("Drop file event should decode with path and position.")
    }
}

@Test
func dropEventsScaleCoordinates(): Unit {
    let event = scaleEventCoordinates(UiEvent.DropText("hello", 30.0, 45.0), 1.5)

    match (event) {
        case UiEvent.DropText(value, x, y) =>
            @Expect(value, "hello")
            @Expect(x, Float32(20.0))
            @Expect(y, Float32(30.0))
        case _ => @Fail("Drop text event should scale coordinates.")
    }
}

@Test
func frameEventsKeepTimeValuesWhenScaled(): Unit {
    let event = scaleEventCoordinates(UiEvent.Frame(FrameInfo(UInt64(32), UInt64(16))), 2.0)

    match (event) {
        case UiEvent.Frame(info) =>
            @Expect(info.elapsedMs, UInt64(32))
            @Expect(info.deltaMs, UInt64(16))
        case _ => @Fail("Frame event should not be converted by coordinate scaling.")
    }
}

private func decodeRawDrop(eventType: UInt32, data: String, x: Float32, y: Float32): UiEvent {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    let cData = unsafe { LibC.mallocCString(data) }
    var decoded = UiEvent.Unknown(UInt32(0))
    try (eventResource = eventPtr.asResource()) {
        try (dataResource = cData.asResource()) {
            var drop = SdlDropEvent()
            drop.eventType = eventType
            drop.x = x
            drop.y = y
            drop.data = dataResource.value.getChars()
            unsafe { CPointer<SdlDropEvent>(eventResource.value).write(drop) }
            decoded = decodeEvent(unsafe { eventResource.value.read() })
        }
    }
    decoded
}
