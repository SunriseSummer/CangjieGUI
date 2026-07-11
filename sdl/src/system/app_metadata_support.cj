/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.{CuiException, ensureSdl, SDL_PROP_APP_METADATA_COPYRIGHT_STRING, SDL_PROP_APP_METADATA_CREATOR_STRING, 
    SDL_PROP_APP_METADATA_IDENTIFIER_STRING, SDL_PROP_APP_METADATA_NAME_STRING, SDL_PROP_APP_METADATA_TYPE_STRING, 
    SDL_PROP_APP_METADATA_URL_STRING, SDL_PROP_APP_METADATA_VERSION_STRING}

internal func appMetadataPropertyName(property: AppMetadataProperty): String {
    match (property) {
        case AppMetadataProperty.Name => SDL_PROP_APP_METADATA_NAME_STRING
        case AppMetadataProperty.Version => SDL_PROP_APP_METADATA_VERSION_STRING
        case AppMetadataProperty.Identifier => SDL_PROP_APP_METADATA_IDENTIFIER_STRING
        case AppMetadataProperty.Creator => SDL_PROP_APP_METADATA_CREATOR_STRING
        case AppMetadataProperty.Copyright => SDL_PROP_APP_METADATA_COPYRIGHT_STRING
        case AppMetadataProperty.Url => SDL_PROP_APP_METADATA_URL_STRING
        case AppMetadataProperty.ApplicationType => SDL_PROP_APP_METADATA_TYPE_STRING
        case AppMetadataProperty.CustomMetadataProperty(value) => value
    }
}

internal func appMetadataTypeValue(appType: AppMetadataType): String {
    match (appType) {
        case AppMetadataType.Application => "application"
        case AppMetadataType.Game => "game"
        case AppMetadataType.MediaPlayer => "mediaplayer"
        case AppMetadataType.CustomMetadataType(value) => value
    }
}

internal func optionalMetadataCString(value: ?String): CString {
    match (value) {
        case Some(text) => unsafe { LibC.mallocCString(text) }
        case None => CString(CPointer<UInt8>())
    }
}

internal func freeMetadataCString(value: CString): Unit {
    if (!value.isNull()) {
        unsafe { LibC.free(value) }
    }
}

internal func setOptionalMetadataProperty(property: AppMetadataProperty, value: ?String): Unit {
    match (value) {
        case Some(text) => ApplicationMetadata.set(property, text)
        case None => ()
    }
}

internal func setOptionalMetadataType(appType: ?AppMetadataType): Unit {
    match (appType) {
        case Some(value) => ApplicationMetadata.set(AppMetadataProperty.ApplicationType, appMetadataTypeValue(value))
        case None => ()
    }
}

internal func withMetadataStrings(property: AppMetadataProperty, value: String, hasValue: Bool): Unit {
    let cName = unsafe { LibC.mallocCString(appMetadataPropertyName(property)) }
    let cValue = if (hasValue) {
        unsafe { LibC.mallocCString(value) }
    } else {
        CString(CPointer<UInt8>())
    }
    try {
        ensureSdl(unsafe { SDL_SetAppMetadataProperty(cName, cValue) }, "SDL_SetAppMetadataProperty")
    } finally {
        freeMetadataCString(cName)
        freeMetadataCString(cValue)
    }
}

/**
 * Throws `CuiException` when a custom metadata property name is empty.
 */
internal func ensureMetadataName(name: String): Unit {
    if (name.size <= 0) {
        throw CuiException("Application metadata property name cannot be empty.")
    }
}
