/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_PROP_APP_METADATA_NAME_STRING = "SDL.app.metadata.name"
internal let SDL_PROP_APP_METADATA_VERSION_STRING = "SDL.app.metadata.version"
internal let SDL_PROP_APP_METADATA_IDENTIFIER_STRING = "SDL.app.metadata.identifier"
internal let SDL_PROP_APP_METADATA_CREATOR_STRING = "SDL.app.metadata.creator"
internal let SDL_PROP_APP_METADATA_COPYRIGHT_STRING = "SDL.app.metadata.copyright"
internal let SDL_PROP_APP_METADATA_URL_STRING = "SDL.app.metadata.url"
internal let SDL_PROP_APP_METADATA_TYPE_STRING = "SDL.app.metadata.type"

foreign {
    func SDL_SetAppMetadata(appname: CString, appversion: CString, appidentifier: CString): Bool

    func SDL_SetAppMetadataProperty(name: CString, value: CString): Bool

    func SDL_GetAppMetadataProperty(name: CString): CString
}
