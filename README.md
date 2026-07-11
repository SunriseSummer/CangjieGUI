# CUI: Cangjie Declarative UI Framework

CUI is a Cangjie desktop GUI framework built on SDL3 and SDL3_ttf. The repository contains
two sibling modules with a one-way dependency:

- **`sdl`** — a reusable SDL3/SDL3_ttf module for graphics, windows, input, dialogs,
  displays, filesystem, time, and platform integration. It can be consumed without CUI,
  which is useful for games and custom renderers.
- **`cui`** — the declarative GUI module. Its focused child packages are `cui.core`,
  `cui.controls`, `cui.text`, `cui.media`, and `cui.desktop`; the root `cui` package
  re-exports the application-facing API.

The dependency direction is strictly `cui -> sdl`; the SDL module never imports GUI code.

<table>
    <tr>
        <td>
            <img src="https://github.com/user-attachments/assets/0fb6c314-467f-4b8d-b7aa-63f510c3131b" />
        </td>
        <td>
            <img src="https://github.com/user-attachments/assets/64292a58-7fcc-4e60-b827-1daa3269db26" />
        </td>
    </tr>
    <tr>
        <td>
            <img src="https://github.com/user-attachments/assets/f4dcdab4-2a34-4882-96d3-e20728d99409" />
        </td>
        <td>
            <img src="https://github.com/user-attachments/assets/8afb89c4-2618-4b6c-88a8-dfaa13356f2b" />
        </td>
    </tr>
</table>

## Declarative UI

Views are written with trailing-lambda builder blocks. A widget declared inside a
container's block becomes its child — no arrays, no manual wiring:

```cangjie
let display = State<String>("Hello")
let app = DesktopApp(WindowSpec("Demo", 720, 480))

app.run {
    VStack(spacing: 12.0, padding: Insets(16.0)) {
        Panel(flexible: false) {
            HStack {
                Label("Demo")
                Spacer()
                Button("Close", {=> println(display.value)}, role: ButtonRole.Primary)
            }
        }
        TextArea("body", display)
    }
}
```

Ordinary control flow works directly inside a block, which is where this style pays off:

```cangjie
VStack {
    for (row in keypad) {
        HStack {
            for (key in row) {
                calcButton(key, model)
            }
        }
    }
    if (mode.value == Scientific) {
        scientificRow(model)
    }
}
```

Reusable components are just functions that return `Unit` and declare widgets; call them
inside a block and their widgets land in the right place. To insert a widget value you
are holding (for example a retained image), call `emit(widget)`.

### Layout

Containers fill the space their parent offers and split it among flexible children. Pass
`flexible: false` to a `VStack`, `HStack`, or `Panel` to make it hug its content instead —
the idiom for compact toolbars and headers above a filling content area:

```cangjie
VStack {
    Panel(flexible: false) {      // toolbar: as tall as its buttons
        HStack { /* controls */ }
    }
    TextArea("body", text)        // fills the remaining height
}
```

Wrap any widget in `Flexible` to opt it into the space-sharing pass. Equal weights make
equal columns — the way to build aligned grids — and a heavier cell spans several columns
exactly, gaps included:

```cangjie
HStack(spacing: 10.0) {
    Flexible(weight: 2.0) { Button("0", onZero) }   // spans two columns of the row above
    Flexible { Button(".", onDot) }
    Flexible { Button("=", onEquals) }
}
```

An empty `Flexible {}` reserves a blank cell, which keeps a grid's column rhythm through
missing entries (see the calendar example's leading and trailing week cells).

### Styling

Applications keep the default modern light/dark themes or pass their own `Theme`, and can
override any control with a per-instance `SurfaceStyle`:

```cangjie
let app = DesktopApp(WindowSpec("Styled", 720, 480), theme: Theme.dark())
let operator = SurfaceStyle(Color.rgb(255, 159, 67), border: Color.rgb(255, 178, 104), radius: 14.0)

app.run {
    VStack(padding: Insets(16.0)) {
        Panel {
            Label("Result", align: TextAlign.Trailing)
        }
        HStack {
            IconButton(IconName.Save, label: Some("Save"), style: Some(operator)) {
                => println("save")
            }
            Divider(axis: Axis.Vertical)
            Button("=", {=> println("equals")}, role: ButtonRole.Primary)
        }
    }
}
```

Examples live in `examples`. Each depends on the local `cui` package and doubles as a
smoke test and a best-practice teaching case: `calculator`, `notepad`, `paint`, `calendar`,
and `process_manager`.

## Rendering

Shapes are rasterized as GPU triangle meshes with analytic anti-aliasing: every fill and
stroke is tessellated from its exact float outline and given a thin fringe of vertices that
fades to transparent (the feathered-edge technique used by vector UI renderers), so rounded
corners, circles, and diagonal strokes have smooth, defect-free silhouettes at any size —
no scanline stairs, no seams, and translucent colours stay uniform because each shape is a
single non-overlapping mesh. On top of that, the whole frame is supersampled 2x into an
offscreen target and resolved with linear filtering, which also smooths content drawn with
the raw line/rect primitives.

The primitive set is built for that pipeline: `fillRoundedRect` and `fillCircle` fills, and
a `Pen` (stroke width plus colour) driving round-capped `strokeLine` and ring-stroked
`strokeRect` / `strokeRoundedRect` / `strokeCircle` — the vector icon set draws with these.
Soft drop shadows and focus glows are single-pass gradient halos via `fillRoundedRectSoft`,
so falloff is a smooth ramp with no banding. `Renderer.captureBmp` and the
`--snapshot <path.bmp>` runtime flag render a settled frame to a BMP for headless visual
tests and documentation thumbnails.

Text is rendered by SDL3_ttf from the current platform's UI font. Windows prefers
`Microsoft YaHei UI` (`msyh.ttc`) and falls back to Segoe UI; macOS and Linux use their
corresponding system UI or Noto/DejaVu candidates. Fonts are cached by point size, measured
with real glyph metrics, and drawn as UTF-8 text, so Chinese and Latin text share the same
high-resolution rendering path.

## Project layout and build

```text
CangjieGUI/
├── cjpm.toml             # cui module; depends on ./sdl
├── src/                  # cui, cui.core, controls, text, media, desktop
├── sdl/
│   ├── cjpm.toml         # standalone sdl module
│   └── src/              # sdl plus dialogs/displays/input/system/ffi
├── examples/
└── .sdl3/                # SDL3 + SDL3_ttf import libraries and runtime DLLs
```

On Windows, `.sdl3` contains both cjpm link names (`libSDL3.dll`,
`libSDL3_ttf.dll`) and runtime names (`SDL3.dll`, `SDL3_ttf.dll`), together with their
MinGW import libraries. Build and test each module independently:

```powershell
cd sdl
cjpm build
cjpm test

cd ..
cjpm build
cjpm test
```

To use only the low-level module, declare `sdl = { path = ".../sdl" }` in the consumer's
`[dependencies]`. See [`sdl/README.md`](sdl/README.md) for package-level imports. Native
executables distributed outside `cjpm run` must ship `SDL3.dll` and `SDL3_ttf.dll` beside
the executable (or on the process library search path).

## Widgets and infrastructure

The catalog covers labels with alignment/color options, buttons and icon buttons with role
and per-instance `SurfaceStyle`, vector `Icon` drawing, dividers, text field, scrollable
text area, checkbox, scrollable list view, canvas, image view (with optional fixed sizing),
slider, progress bar, segmented control, tab view (which re-lays its incoming page out the
moment the selection changes, so a mid-frame switch never draws a stale page), `Panel`
containers, `EventHandler`/`FrameHandler` wrappers, `VStack`/`HStack` trailing-lambda
builders, `Flexible` weights, `Spacer`, and shared `State<T>` bindings. Applications can
also grow the catalog themselves — the `paint` example defines its own `ColorSwatch` widget
by implementing the four `Widget` hooks and calling `emit(this)`.

Long-running work belongs on worker threads: run it with `spawn` and hand results back
through a mutex-guarded mailbox that the frame loop polls (the `process_manager` example
shows the pattern). The UI thread itself should never block.

The image path includes SDL3 surfaces, BMP/PNG loading, texture creation, blend/color
modulation, and retained `Resource` ownership through `DesktopApp.manage`. Desktop helpers
expose application metadata through `ApplicationMetadata`, startup/runtime SDL hints through
`SdlHints`, platform/CPU/memory/power and application paths through `ApplicationPaths`,
filesystem operations through `FileSystem`, realtime date/time through `Time`,
high-resolution counters through `PerformanceClock`, keyboard modifier state, frame timing
through `FrameInfo`, display geometry/modes and multi-display enumeration, window runtime
queries, cursor/system cursors, URL opening, clipboard access through `Clipboard`,
asynchronous native file dialogs through `FileDialogs`/`FileDialogRequest`, and native
message boxes. `DesktopApp` accepts optional `metadata`, `hints`, and `theme` constructor
arguments so startup configuration is applied before SDL initializes video.

Text editing widgets use `TextEditState` for UTF-8-safe insertion, backspace/delete, cursor
normalization, Home/End, and line up/down movement. `TextField` and `TextArea` accept an
optional `State<Int64>` cursor binding for persistent cursor ownership across view rebuilds.
`TextArea(editable: false)` keeps scrolling and cursor movement enabled while ignoring text
mutation, which is useful for log viewers and command output panes.
