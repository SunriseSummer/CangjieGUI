package cui.core

import sdl.{Fonts, Insets}

extend UiContext {
    /** Positive physical-pixel scale used to resolve px lengths. */
    public mut prop displayScale: Float32 {
        get() {
            displayScaleValue
        }
        set(value) {
            let normalized = normalizedUiScale(value, 0.001)
            if (displayScaleValue != normalized) {
                displayScaleValue = normalized
                advanceUiEnvironment()
            }
        }
    }

    /** Positive user text scale used to resolve fp lengths. */
    public mut prop fontScale: Float32 {
        get() {
            fontScaleValue
        }
        set(value) {
            let normalized = normalizedUiScale(value, 0.1)
            if (fontScaleValue != normalized) {
                fontScaleValue = normalized
                advanceUiEnvironment()
            }
        }
    }

    internal func advanceUiEnvironment(): Unit {
        uiEnvironmentGeneration = allocateUiEnvironmentGeneration()
    }

    /*
     * Opaque key shared by retained measure/layout caches. Font registration is sampled once at
     * the frame boundary so every phase in one transaction observes the same UI environment.
     */
    protected func uiEnvironmentKey(): UiEnvironmentKey {
        if (uiEnvironmentNeedsFontRefresh) {
            uiEnvironmentNeedsFontRefresh = false
            let fontRevision = Fonts.revision()
            if (observedFontRegistryRevision != fontRevision) {
                observedFontRegistryRevision = fontRevision
                advanceUiEnvironment()
            }
        }
        let scale = renderer.textMeasurementScale()
        let family = match (renderer.effectiveFontFamily()) {
            case Some(name) => name
            case None => ""
        }
        UiEnvironmentKey(uiEnvironmentGeneration, rasterScaleX: scale.w.toBits(), rasterScaleY: scale.h.toBits(),
            fontRevision: Fonts.revision(), fontFamily: family, textSize: textSize().toBits(),
            textStyle: effectiveFontStyle().ttfFlags(), fontWeight: effectiveFontStyle().weight.value,
            fontVariations: effectiveFontStyle().variations.key())
    }

    /** Converts a unit-carrying length into logical (virtual) pixels. */
    public func resolve(length: Length): Float32 {
        match (length.unit) {
            case LengthUnit.Vp => length.value
            case LengthUnit.Px => length.value / displayScale
            case LengthUnit.Fp => length.value * fontScale
        }
    }

    /** Converts unit-carrying edge insets into logical-pixel insets. */
    public func resolve(insets: LengthInsets): Insets {
        Insets(
            max(0.0, resolve(insets.top)),
            max(0.0, resolve(insets.right)),
            max(0.0, resolve(insets.bottom)),
            max(0.0, resolve(insets.left))
        )
    }
}

private func normalizedUiScale(value: Float32, minimum: Float32): Float32 {
    if (value.isNaN() || value.isInf()) {
        1.0
    } else {
        max(minimum, value)
    }
}
