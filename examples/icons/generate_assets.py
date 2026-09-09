"""Reproduce application-owned demonstration artwork; framework presets live in src/symbols.

SVG generation uses only Python's standard library. --rasters additionally uses the installed
SDL3_image to produce the committed PNG density variants; it needs no window or optional codecs.
"""
from pathlib import Path
import argparse
import ctypes
import os
import re

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(__file__).resolve().parent / 'assets' / 'icons'
# Original 24-unit line artwork. Rounded terminals, generous counterspace and a consistent 1.7 stroke.
PATHS = {
    'document': '<path d="M7 3.5h7l4 4v13H6V3.5h1m7 0v5h4M9 12h6m-6 4h6"/>',
    'folder': '<path d="M3.5 8V5.5h6l2 2H20v3M3.5 9.5H21l-2.5 10H5z"/>',
    'save': '<path d="M5 3.5h12l3.5 3.5v13H3.5V5zM8 3.5v6h8v-6M7.5 20v-7h9v7"/>',
    'save-as': '<path d="M11 20H3.5V5L5 3.5h12l3.5 3.5V11M8 3.5v6h8v-6M13 19l6.5-6.5 2 2L15 21l-3 1z"/>',
    'copy': '<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M5 16H3.5v-13H15V5"/>',
    'paste': '<rect x="4.5" y="5" width="15" height="16" rx="2"/><rect x="8" y="3" width="8" height="4" rx="1"/><path d="M8 12h8m-8 4h6"/>',
    'refresh': '<path d="M19.5 8A8 8 0 0 0 5 6l-2 4m0-5v5h5m-3.5 6A8 8 0 0 0 19 18l2-4m0 5v-5h-5"/>',
    'trash': '<path d="M3.5 6.5h17M9 6V3.5h6V6M6 7l1 13.5h10L18 7M10 10v7m4-7v7"/>',
    'brush': '<path d="M9.5 14.5L18 3l3 3-11.5 8.5M5 14c3-1 5 1 4 3-1 3-5 4-7 2 3 0 1-4 3-5z"/>',
    'calendar': '<rect x="3.5" y="5" width="17" height="16" rx="2"/><path d="M7.5 3v5m9-5v5M4 10h16M8 14h2m4 0h2m-8 3h2"/>',
    'clock': '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2"/>',
    'process': '<path d="M4 20V11m5 9V4m6 16v-7m5 7V8"/>',
    'calculator': '<rect x="5" y="2.5" width="14" height="19" rx="2"/><path d="M8 6h8v4H8zM8 14h1m6 0h1m-8 4h1m6 0h1"/>',
    'chevron-left': '<path d="M14.5 5l-7 7 7 7"/>',
    'chevron-right': '<path d="M9.5 5l7 7-7 7"/>',
    'search': '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5l5 5"/>',
    'arrow-up-right': '<path d="M5 19L19 5M8 5h11v11"/>',
    'spark': '<path d="M12 2.5l2.6 6.9 6.9 2.6-6.9 2.6-2.6 6.9-2.6-6.9-6.9-2.6 6.9-2.6z"/>',
    'check': '<path d="M5 12l4.5 4.5L19 7"/>',
    'moon': '<path d="M19.5 15A8.5 8.5 0 0 1 9 4.5 8.5 8.5 0 1 0 19.5 15z"/>',
}
OLD = dict(zip(
    ['NewDocument','OpenFolder','Save','SaveAs','Copy','Paste','Refresh','Trash','Brush','Calendar','Clock','Process','Calculator','ChevronLeft','ChevronRight'],
    ['document','folder','save','save-as','copy','paste','refresh','trash','brush','calendar','clock','process','calculator','chevron-left','chevron-right']))

def svg(name):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
            '<g fill="none" stroke="#142f38" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'
            + PATHS[name] + '</g></svg>\n')

def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8', newline='\n')

def generate():
    for name in PATHS:
        save(ASSETS/f'{name}.svg', svg(name))
    # Optical size: a simpler, grid-aligned 16px search drawing, not a scaled 24px path.
    save(ASSETS/'search-16.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><g fill="none" stroke="#142f38" stroke-width="1.5" stroke-linecap="round"><circle cx="6.5" cy="6.5" r="4"/><path d="M9.5 9.5l4 4"/></g></svg>\n')
    save(ASSETS/'orbit.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect x="4" y="4" width="88" height="88" rx="25" fill="#163e48"/><circle cx="50" cy="40" r="22" fill="#f4b76a"/><path d="M12 64C31 36 53 39 85 61v16a15 15 0 0 1-15 15H28A24 24 0 0 1 12 68z" fill="#78b5ac"/><path d="M14 77C39 53 65 58 88 72v4a16 16 0 0 1-16 16H28A24 24 0 0 1 14 77z" fill="#f2e8d5"/><circle cx="73" cy="25" r="4" fill="#fff4d8"/></svg>\n')
    # Pixel artwork is purposefully unfiltered and made of whole-pixel rectangles.
    save(ASSETS/'pixel.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><path fill="#163e48" d="M6 1h4v3h3v3h2v4h-3v3H4v-3H1V7h2V4h3z"/><path fill="#f4b76a" d="M6 4h4v3h3v3H3V7h3z"/><path fill="#f2e8d5" d="M5 10h6v2H5z"/></svg>\n')

def migrate():
    for example in (ROOT/'examples').iterdir():
        if not (example/'src').is_dir():
            continue
        required = set()
        for p in (example/'src').rglob('*.cj'):
            content = p.read_text(encoding='utf-8')
            if 'IconName' in content or 'drawIcon' in content:
                def replacement(match):
                    name = OLD[match[1]]
                    required.add(name)
                    return f'IconSource("assets/icons/{name}.svg")'
                content = re.sub(r'IconName\.(\w+)', replacement, content)
                content = content.replace('IconName', 'IconSource').replace('drawIcon(ctx.renderer,', 'paintIcon(ctx,').replace('drawIcon,', 'paintIcon,')
                save(p, content)
            required.update(re.findall(r'assets/icons/([\w-]+)\.svg', content))
        for name in required:
            if name in PATHS:
                save(example/'assets/icons'/f'{name}.svg', svg(name))

def rasters(directory):
    dll_scope = os.add_dll_directory(str(directory)) if os.name == 'nt' else None
    try:
        core = ctypes.CDLL(str(directory/('SDL3.dll' if os.name=='nt' else 'libSDL3.so')))
        img = ctypes.CDLL(str(directory/('SDL3_image.dll' if os.name=='nt' else 'libSDL3_image.so')))
        core.SDL_IOFromFile.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        core.SDL_IOFromFile.restype = ctypes.c_void_p
        img.IMG_LoadSizedSVG_IO.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
        img.IMG_LoadSizedSVG_IO.restype = ctypes.c_void_p
        core.SDL_CloseIO.argtypes = [ctypes.c_void_p]
        core.SDL_CloseIO.restype = ctypes.c_bool
        core.SDL_SavePNG.argtypes = [ctypes.c_void_p,ctypes.c_char_p]
        core.SDL_SavePNG.restype = ctypes.c_bool
        core.SDL_DestroySurface.argtypes = [ctypes.c_void_p]
        core.SDL_GetError.restype = ctypes.c_char_p
        for name, sizes in [('orbit',[24,48,72,96,144,192]),('pixel',[16])]:
            for size in sizes:
                stream = core.SDL_IOFromFile(os.fsencode(ASSETS/f'{name}.svg'), b'rb')
                if not stream: raise RuntimeError(core.SDL_GetError())
                surface = img.IMG_LoadSizedSVG_IO(stream,size,size)
                core.SDL_CloseIO(stream)
                if not surface: raise RuntimeError(core.SDL_GetError())
                try:
                    if not core.SDL_SavePNG(surface,os.fsencode(ASSETS/f'{name}-{size}.png')):
                        raise RuntimeError(core.SDL_GetError())
                finally:
                    core.SDL_DestroySurface(surface)
    finally:
        if dll_scope: dll_scope.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--migrate',action='store_true',help='migrate old example sources and copy their artwork')
    parser.add_argument('--rasters',type=Path,help='directory containing SDL3 and SDL3_image')
    args=parser.parse_args()
    generate()
    if args.migrate: migrate()
    if args.rasters: rasters(args.rasters.resolve())
