/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.{CuiException, SDL_PROP_APP_METADATA_COPYRIGHT_STRING, SDL_PROP_APP_METADATA_CREATOR_STRING, 
    SDL_PROP_APP_METADATA_IDENTIFIER_STRING, SDL_PROP_APP_METADATA_NAME_STRING, SDL_PROP_APP_METADATA_TYPE_STRING, 
    SDL_PROP_APP_METADATA_URL_STRING, SDL_PROP_APP_METADATA_VERSION_STRING}

@Test
func appMetadataPropertyNamesMapSdlValues(): Unit {
    @Expect(appMetadataPropertyName(AppMetadataProperty.Name), SDL_PROP_APP_METADATA_NAME_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.Version), SDL_PROP_APP_METADATA_VERSION_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.Identifier), SDL_PROP_APP_METADATA_IDENTIFIER_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.Creator), SDL_PROP_APP_METADATA_CREATOR_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.Copyright), SDL_PROP_APP_METADATA_COPYRIGHT_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.Url), SDL_PROP_APP_METADATA_URL_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.ApplicationType), SDL_PROP_APP_METADATA_TYPE_STRING)
    @Expect(appMetadataPropertyName(AppMetadataProperty.CustomMetadataProperty("cui.test")), "cui.test")
}

@Test
func appMetadataTypeValuesMapSdlValues(): Unit {
    @Expect(appMetadataTypeValue(AppMetadataType.Application), "application")
    @Expect(appMetadataTypeValue(AppMetadataType.Game), "game")
    @Expect(appMetadataTypeValue(AppMetadataType.MediaPlayer), "mediaplayer")
    @Expect(appMetadataTypeValue(AppMetadataType.CustomMetadataType("utility")), "utility")
}

@Test
func appMetadataRejectsEmptyCustomProperty(): Unit {
    @Expect(metadataSetFails(AppMetadataProperty.CustomMetadataProperty("")))
}

private func metadataSetFails(property: AppMetadataProperty): Bool {
    try {
        ApplicationMetadata.set(property, "value")
        false
    } catch (e: CuiException) {
        true
    }
}
