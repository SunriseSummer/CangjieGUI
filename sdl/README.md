# Standalone SDL module

This directory is an independent Cangjie package for SDL3 and SDL3_ttf. It has no
dependency on `cui`, so it can be used for games, visualization tools, or a custom UI
stack.

Add it to a consumer's `cjpm.toml`:

```toml
[dependencies]
sdl = { path = "../CangjieGUI/sdl" }
```

Import only the packages needed by the application:

```cangjie
import sdl.{Color, FontSizes, Renderer, SdlWindow, WindowSpec}
import sdl.input.{Cursor, Keyboard, Mouse}
import sdl.system.{PerformanceClock, Time}
```

Available feature packages are `sdl.dialogs`, `sdl.displays`, `sdl.input`, and
`sdl.system`. The root `sdl` package contains geometry, rendering, surfaces, textures,
events, and windows. `sdl.ffi` is an implementation package for the SDL3_ttf backend and
is not intended as application API.

The module links SDL3 and SDL3_ttf from the repository-level `.sdl3` directory. On
Windows, keep `SDL3.dll` and `SDL3_ttf.dll` beside a distributed executable or otherwise
available on its library search path.

```powershell
cjpm build
cjpm test
```
