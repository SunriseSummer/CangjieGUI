#!/usr/bin/env python3
"""示例快照的像素级工具：BMP 读取、逐像素对比、PNG 转换与基线看护。

CUI 示例经 `cjpm run --run-args "--snapshot x.bmp"` 输出未压缩 BMP 快照；本工具用纯标准库
处理它们，跨平台可用（Windows/macOS/Linux 均无需 Pillow/ImageMagick）。

用法：
    python .dev/cli.py snapshot convert a.bmp a.png
    python .dev/cli.py snapshot diff a.bmp b.bmp --out d.png --tolerance 2
    python .dev/cli.py snapshot check --baseline dir shots...
    python .dev/cli.py snapshot update --baseline dir shots...

diff 输出差异像素数、最大通道差与差异包围盒；--out 生成差异热图（相同处压暗原图、
差异处标红）。--tolerance N 允许每通道不超过 N 的差值（吸收抗锯齿抖动）。
check/update 以文件名（不含目录）为键，构成最小的快照基线看护流程。
"""

import argparse
import shutil
import struct
import sys
import zlib
from pathlib import Path


def read_bmp(path):
    """读取未压缩 24/32 位 BMP，返回 (width, height, rows)，rows 为自顶向下的 RGB 元组行。"""
    data = Path(path).read_bytes()
    if len(data) < 54:
        raise ValueError(f"{path}: BMP 文件过短（{len(data)} 字节）")
    if data[:2] != b"BM":
        raise ValueError(f"{path}: 不是 BMP 文件")
    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    header_size = struct.unpack_from("<I", data, 14)[0]
    if header_size < 40:
        raise ValueError(f"{path}: 不支持的 DIB 头（{header_size} 字节）")
    width, height = struct.unpack_from("<ii", data, 18)
    planes, bpp = struct.unpack_from("<HH", data, 26)
    compression = struct.unpack_from("<I", data, 30)[0]
    if width <= 0 or height == 0:
        raise ValueError(f"{path}: 非法 BMP 尺寸 {width}x{height}")
    if planes != 1:
        raise ValueError(f"{path}: 非法 BMP planes={planes}")
    if bpp not in (24, 32) or compression not in (0, 3) or (bpp == 24 and compression != 0):
        raise ValueError(f"{path}: 仅支持未压缩 24/32 位 BMP（bpp={bpp}, compression={compression}）")
    top_down = height < 0
    height = abs(height)
    stride = (width * (bpp // 8) + 3) & ~3
    step = bpp // 8
    if pixel_offset < 14 + header_size:
        raise ValueError(f"{path}: 像素偏移 {pixel_offset} 落在 BMP 头内部")
    required = pixel_offset + height * stride
    if required > len(data):
        raise ValueError(f"{path}: 像素数据被截断（需要 {required} 字节，实际 {len(data)}）")
    rows = []
    for row in range(height):
        src_row = row if top_down else height - 1 - row
        base = pixel_offset + src_row * stride
        line = []
        for col in range(width):
            i = base + col * step
            b, g, r = data[i], data[i + 1], data[i + 2]
            line.append((r, g, b))
        rows.append(line)
    return width, height, rows


def write_png(path, width, height, rows):
    """把自顶向下的 RGB 行写成无滤波的 8 位 PNG。"""
    if width <= 0 or height <= 0 or len(rows) != height or any(len(row) != width for row in rows):
        raise ValueError("PNG 像素矩阵尺寸不一致")
    raw = bytearray()
    for line in rows:
        raw.append(0)
        for (r, g, b) in line:
            raw += bytes((r, g, b))

    def chunk(tag, payload):
        body = tag + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def load_image(path):
    p = str(path)
    if p.lower().endswith(".bmp"):
        return read_bmp(path)
    raise ValueError(f"{path}: 仅支持读取 BMP（快照原始格式）")


def diff_images(a_path, b_path, out=None, tolerance=0):
    """对比两张快照；返回 (差异像素数, 最大通道差, 包围盒或 None)。尺寸不同视为完全差异。"""
    if not 0 <= tolerance <= 255:
        raise ValueError(f"容差必须在 0..255，实际为 {tolerance}")
    aw, ah, arows = load_image(a_path)
    bw, bh, brows = load_image(b_path)
    if (aw, ah) != (bw, bh):
        print(f"尺寸不同：{a_path} 为 {aw}x{ah}，{b_path} 为 {bw}x{bh}")
        width = max(aw, bw)
        height = max(ah, bh)
        return max(aw * ah, bw * bh), 255, (0, 0, width - 1, height - 1)
    differing = 0
    max_delta = 0
    bbox = None
    heat = [] if out else None
    for y in range(ah):
        arow, brow = arows[y], brows[y]
        heat_line = [] if out else None
        for x in range(aw):
            (r1, g1, b1), (r2, g2, b2) = arow[x], brow[x]
            delta = max(abs(r1 - r2), abs(g1 - g2), abs(b1 - b2))
            if delta > tolerance:
                differing += 1
                if delta > max_delta:
                    max_delta = delta
                bbox = (x, y, x, y) if bbox is None else (
                    min(bbox[0], x), min(bbox[1], y), max(bbox[2], x), max(bbox[3], y))
                if heat_line is not None:
                    heat_line.append((255, 40, 40))
            elif heat_line is not None:
                heat_line.append((r1 // 3, g1 // 3, b1 // 3))
        if heat is not None:
            heat.append(heat_line)
    if out and differing:
        write_png(out, aw, ah, heat)
        print(f"差异热图已写入 {out}")
    return differing, max_delta, bbox


def cmd_convert(args):
    w, h, rows = load_image(args.src)
    write_png(args.dst, w, h, rows)
    print(f"{args.src} ({w}x{h}) -> {args.dst}")
    return 0


def cmd_diff(args):
    differing, max_delta, bbox = diff_images(args.a, args.b, out=args.out, tolerance=args.tolerance)
    if differing == 0:
        print(f"逐像素一致（容差 {args.tolerance}）。")
        return 0
    print(f"差异像素 {differing} 个，最大通道差 {max_delta}，包围盒 {bbox}。")
    return 1


def cmd_check(args):
    base = Path(args.baseline)
    failed = 0
    for shot in args.shots:
        ref = base / Path(shot).name
        if not ref.exists():
            print(f"[MISS] {shot}: 基线中无 {ref.name}（用 update 建立）")
            failed += 1
            continue
        differing, max_delta, bbox = diff_images(ref, shot, tolerance=args.tolerance)
        if differing:
            print(f"[DIFF] {shot}: {differing} 像素偏离基线（最大通道差 {max_delta}，包围盒 {bbox}）")
            failed += 1
        else:
            print(f"[OK]   {shot}")
    return 1 if failed else 0


def cmd_update(args):
    base = Path(args.baseline)
    base.mkdir(parents=True, exist_ok=True)
    for shot in args.shots:
        shutil.copyfile(shot, base / Path(shot).name)
        print(f"基线已更新：{base / Path(shot).name}")
    return 0


def channel_tolerance(value):
    parsed = int(value)
    if not 0 <= parsed <= 255:
        raise argparse.ArgumentTypeError("容差必须在 0..255")
    return parsed


def main(argv=None):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="CUI 快照像素工具")
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("convert", help="BMP 转 PNG")
    c.add_argument("src")
    c.add_argument("dst")
    c.set_defaults(fn=cmd_convert)

    d = sub.add_parser("diff", help="两张快照逐像素对比")
    d.add_argument("a")
    d.add_argument("b")
    d.add_argument("--out", help="差异热图 PNG 输出路径")
    d.add_argument("--tolerance", type=channel_tolerance, default=0)
    d.set_defaults(fn=cmd_diff)

    k = sub.add_parser("check", help="与基线目录对比")
    k.add_argument("shots", nargs="+")
    k.add_argument("--baseline", required=True)
    k.add_argument("--tolerance", type=channel_tolerance, default=0)
    k.set_defaults(fn=cmd_check)

    u = sub.add_parser("update", help="把快照写入基线目录")
    u.add_argument("shots", nargs="+")
    u.add_argument("--baseline", required=True)
    u.set_defaults(fn=cmd_update)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
