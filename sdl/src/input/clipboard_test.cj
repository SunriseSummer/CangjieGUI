/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import sdl.{CuiException}

@Test
func clipboardDataValidationRejectsUnsafeInputs(): Unit {
    expectCuiException({=> ensureClipboardDataItems([])})
    expectCuiException({=> ensureClipboardDataItems([ClipboardData("", [])])})
    expectCuiException({=> ensureClipboardDataItems([ClipboardData("text/plain\nbad", [])])})
    expectCuiException({
        => ensureClipboardDataItems(
            [
                ClipboardData("text/plain", []),
                ClipboardData("text/plain", [UInt8(1)])
            ]
        )
    })
}

@Test
func clipboardBytesCopyNativeBuffer(): Unit {
    let buffer = unsafe { LibC.malloc<UInt8>(count: 3) }
    try (bufferResource = buffer.asResource()) {
        unsafe {
            bufferResource.value.write(0, UInt8(4))
            bufferResource.value.write(1, UInt8(8))
            bufferResource.value.write(2, UInt8(15))
        }

        let bytes = clipboardBytesFromPointer(bufferResource.value, UIntNative(3))

        @Expect(bytes.size, 3)
        @Expect(bytes[0], UInt8(4))
        @Expect(bytes[1], UInt8(8))
        @Expect(bytes[2], UInt8(15))
    }
}

@Test
func clipboardMimeTypesCopyNativeList(): Unit {
    let raw = unsafe { LibC.malloc<CPointer<UInt8>>(count: 2) }
    let text = unsafe { LibC.mallocCString("text/plain") }
    let image = unsafe { LibC.mallocCString("image/png") }
    try (rawResource = raw.asResource()) {
        try (textResource = text.asResource()) {
            try (imageResource = image.asResource()) {
                unsafe {
                    rawResource.value.write(0, textResource.value.getChars())
                    rawResource.value.write(1, imageResource.value.getChars())
                }

                let mimeTypes = clipboardMimeTypesFromPointer(rawResource.value, UIntNative(2))

                @Expect(mimeTypes.size, 2)
                @Expect(mimeTypes[0], "text/plain")
                @Expect(mimeTypes[1], "image/png")
            }
        }
    }
}

@Test
func clipboardOfferCallbackReturnsRequestedBytes(): Unit {
    let offer = createClipboardOffer([ClipboardData("application/x-cui-test", [UInt8(1), UInt8(2), UInt8(3)])])
    registerClipboardOffer(offer)

    let mimeType = unsafe { LibC.mallocCString("application/x-cui-test") }
    let unknownMimeType = unsafe { LibC.mallocCString("application/x-cui-missing") }
    try {
        try (mimeTypeResource = mimeType.asResource()) {
            try (unknownMimeTypeResource = unknownMimeType.asResource()) {
                var size = UIntNative(0)
                let ptr = unsafe {
                    cuiClipboardDataCallback(offer.userdata(), mimeTypeResource.value.getChars(), inout size)
                }
                let bytes = clipboardBytesFromPointer(CPointer<UInt8>(ptr), size)

                @Expect(size, UIntNative(3))
                @Expect(bytes[0], UInt8(1))
                @Expect(bytes[1], UInt8(2))
                @Expect(bytes[2], UInt8(3))

                var missingSize = UIntNative(99)
                let missing = unsafe {
                    cuiClipboardDataCallback(
                        offer.userdata(),
                        unknownMimeTypeResource.value.getChars(),
                        inout missingSize
                    )
                }

                @Expect(missing.isNull())
                @Expect(missingSize, UIntNative(0))
            }
        }
    } finally {
        unsafe { cuiClipboardCleanupCallback(offer.userdata()) }
    }
}

private func expectCuiException(action: () -> Unit): Unit {
    try {
        action()
        @Fail("Expected CuiException.")
    } catch (e: CuiException) {
        @Expect(e.message.size > 0)
    }
}
