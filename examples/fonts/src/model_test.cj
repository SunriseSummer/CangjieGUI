package cui_fonts

import cui.{WidgetTestHost, Rect}

@Test
func modelLeavesFullCatalogForExplicitLoading(): Unit {
    let model = FontsModel()
    @Expect(!model.catalogLoaded.value)
    @Expect(model.installed.value.isEmpty())
    @Expect(model.familyNames.value.size, Int64(4))
    @Expect(model.chosenFamily.value, "system-ui")
}

@Test
func previewInputRowKeepsNaturalHeightAcrossFontSizeChanges(): Unit {
    for (scale in [Float32(1.0), Float32(1.5)]) {
        let host = WidgetTestHost(fontScale: scale)
        let model = FontsModel(discover: false)
        for (size in [Float32(12.0), Float32(24.0), Float32(40.0), Float32(20.0)]) {
            model.size.value = size
            let _ = host.frame(Rect(0.0, 0.0, 840.0, 880.0), body: {=> fontsView(model)})
            var found = false
            for (node in host.context.semanticsSnapshot()) {
                if (node.properties.label == "保存") {
                    found = true
                    let height = host.context.renderer.textHeight(pointSize: size * scale, style: model.previewStyle(),
                        font: model.chosenFamily.value)
                    @Expect(node.bounds.h >= height + 12.0)
                }
            }
            @Expect(found)
        }
        host.reset()
    }
}

@Test
func faceNameMapsSelectionToFamily(): Unit {
    let faces = TYPEFACES
    // The shipped list leads with the system default (no family), then named faces.
    @Expect(faceName(faces, 0).isNone())
    @Expect(faceName(faces, 1).getOrThrow(), "serif")
    @Expect(faceName(faces, 2).getOrThrow(), "monospace")
    // Out-of-range selections fall back to the system default (None).
    @Expect(faceName(faces, -1).isNone())
    @Expect(faceName(faces, 99).isNone())
}

@Test
func typefacesCoverSystemSerifMono(): Unit {
    @Expect(TYPEFACES.size, 3)
    @Expect(TYPEFACES[0].family.isNone())
    // Platform roles no longer require guessed absolute font paths.
    @Expect(TYPEFACES[1].family.getOrThrow(), "serif")
    @Expect(TYPEFACES[2].family.getOrThrow(), "monospace")
}

@Test
func modelSelectionDrivesCurrentFace(): Unit {
    let model = FontsModel(discover: false)
    // Ships selecting the serif face.
    @Expect(model.currentFace().getOrThrow(), "serif")
    @Expect(model.labels().size, 3)
    // Switching selection flows through to the current face.
    model.selected.value = 0
    @Expect(model.currentFace().isNone())
    model.selected.value = 2
    @Expect(model.currentFace().getOrThrow(), "monospace")
}
