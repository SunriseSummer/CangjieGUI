/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui

/*
 * Umbrella package.
 *
 * CUI is split into two layers:
 *   - sdl: the SDL3 wrapper — raw FFI, geometry/color primitives, renderer,
 *     surfaces, textures, window, input, and desktop/platform integration.
 *   - cui: the declarative GUI framework — core widgets, controls, text, media,
 *     and desktop application integration, arranged as focused child packages.
 *
 * Both layers are re-exported here so applications only need `import cui.*`.
 */
public import sdl.Color
public import sdl.CuiException
public import sdl.FontSizes
public import sdl.FrameInfo
public import sdl.IconName
public import sdl.ImageFileFormat
public import sdl.Insets
public import sdl.Key
public import sdl.MouseButton
public import sdl.Pen
public import sdl.Point
public import sdl.Rect
public import sdl.Renderer
public import sdl.SdlWindow
public import sdl.Size
public import sdl.Surface
public import sdl.SurfaceStyle
public import sdl.Texture
public import sdl.TextureBlendMode
public import sdl.TextureFlip
public import sdl.TextureRenderOptions
public import sdl.UiEvent
public import sdl.WindowAspectRatio
public import sdl.WindowBorderSize
public import sdl.WindowFlash
public import sdl.WindowFlags
public import sdl.WindowPosition
public import sdl.WindowProgressState
public import sdl.WindowSpec
public import sdl.clampF32
public import sdl.drawIcon
public import sdl.imageFormatFromPath
public import sdl.sdlRevision
public import sdl.sdlVersion
public import cui.core.Axis
public import cui.core.Button
public import cui.core.ButtonRole
public import cui.core.Divider
public import cui.core.EventHandler
public import cui.core.Flexible
public import cui.core.FrameHandler
public import cui.core.HStack
public import cui.core.Icon
public import cui.core.IconButton
public import cui.core.Label
public import cui.core.Panel
public import cui.core.Spacer
public import cui.core.State
public import cui.core.TextAlign
public import cui.core.Theme
public import cui.core.UiContext
public import cui.core.VStack
public import cui.core.Widget
public import cui.core.emit
public import cui.controls.Checkbox
public import cui.controls.ListView
public import cui.controls.ProgressBar
public import cui.controls.SegmentedControl
public import cui.controls.Slider
public import cui.controls.TabView
public import cui.desktop.DesktopApp
public import cui.media.CanvasWidget
public import cui.media.ImageFit
public import cui.media.ImageView
public import cui.text.TextArea
public import cui.text.TextEditState
public import cui.text.TextField
public import sdl.dialogs.FileDialogFilter
public import sdl.dialogs.FileDialogOptions
public import sdl.dialogs.FileDialogRequest
public import sdl.dialogs.FileDialogResult
public import sdl.dialogs.FileDialogs
public import sdl.dialogs.MessageBoxButton
public import sdl.dialogs.MessageBoxButtonOrder
public import sdl.dialogs.MessageBoxColor
public import sdl.dialogs.MessageBoxColorScheme
public import sdl.dialogs.MessageBoxKind
public import sdl.dialogs.MessageBoxOptions
public import sdl.dialogs.showMessageBox
public import sdl.dialogs.showSimpleMessageBox
public import sdl.displays.DisplayGeometry
public import sdl.displays.DisplayInfo
public import sdl.displays.DisplayMode
public import sdl.displays.DisplayModes
public import sdl.displays.DisplayOrientation
public import sdl.displays.DisplayOrientations
public import sdl.displays.FullscreenModeRequest
public import sdl.displays.allDisplayInfos
public import sdl.displays.closestFullscreenDisplayMode
public import sdl.displays.displayIds
public import sdl.displays.displayInfo
public import sdl.displays.displayInfoForPoint
public import sdl.displays.displayInfoForRect
public import sdl.displays.fullscreenDisplayModes
public import sdl.displays.primaryDisplayInfo
public import sdl.input.Clipboard
public import sdl.input.ClipboardData
public import sdl.input.Cursor
public import sdl.input.KeyModifiers
public import sdl.input.Keyboard
public import sdl.input.Mouse
public import sdl.input.MouseState
public import sdl.input.SystemCursor
public import sdl.system.AppMetadata
public import sdl.system.AppMetadataProperty
public import sdl.system.AppMetadataType
public import sdl.system.ApplicationMetadata
public import sdl.system.ApplicationPaths
public import sdl.system.ClockFormat
public import sdl.system.CpuInfo
public import sdl.system.DateFormat
public import sdl.system.DateTimeLocalePreferences
public import sdl.system.DateTimeParts
public import sdl.system.FileSystem
public import sdl.system.FileSystemEntryType
public import sdl.system.HintPriority
public import sdl.system.PathInfo
public import sdl.system.PerformanceClock
public import sdl.system.PowerInfo
public import sdl.system.PowerState
public import sdl.system.SdlHint
public import sdl.system.SdlHintSetting
public import sdl.system.SdlHints
public import sdl.system.Time
public import sdl.system.UserFolder
public import sdl.system.Weekday
public import sdl.system.WindowsFileTime
public import sdl.system.cpuInfo
public import sdl.system.openUrl
public import sdl.system.platformName
public import sdl.system.powerInfo
