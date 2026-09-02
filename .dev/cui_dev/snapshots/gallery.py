#!/usr/bin/env python3
"""为 examples/ 下全部示例生成画廊截图（examples/.images/<name>.png）。

逐个示例执行 `cjpm run --skip-build --run-args "--snapshot <tmp>.bmp"`（二进制缺失时退回
带构建的 `cjpm run`），把快照写为 PNG。默认上限 1800px——当前全部示例窗口都在其内，
即保持原生分辨率；更宽的画面按整数因子做面积平均降采样。

用法：
    python .dev/cli.py gallery                         # 全部示例
    python .dev/cli.py gallery mail richtext           # 只重拍指定示例
    python .dev/cli.py gallery --max-width 900         # 需要小图时显式收紧

退出码非零表示有示例拍摄失败；失败清单在输出末尾。
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from cui_dev.common.paths import REPOSITORY_ROOT
from cui_dev.snapshots.images import read_bmp, write_png


ROOT = REPOSITORY_ROOT
EXAMPLES = ROOT / "examples"
IMAGES = EXAMPLES / ".images"


def downscale(width, height, rows, max_width):
    """整数因子的面积平均降采样；已在上限内时原样返回。"""
    factor = 1
    while width // (factor + 1) >= 1 and width / factor > max_width:
        factor += 1
    if factor == 1:
        return width, height, rows
    out_w = width // factor
    out_h = height // factor
    out = []
    for oy in range(out_h):
        line = []
        for ox in range(out_w):
            r = g = b = 0
            for dy in range(factor):
                row = rows[oy * factor + dy]
                for dx in range(factor):
                    pr, pg, pb = row[ox * factor + dx]
                    r += pr
                    g += pg
                    b += pb
            n = factor * factor
            line.append((r // n, g // n, b // n))
        out.append(line)
    return out_w, out_h, out


def shoot(example_dir, out_png, max_width):
    """拍一个示例的快照并写出降采样 PNG；返回 None 或失败原因。"""
    with tempfile.TemporaryDirectory() as tmp:
        bmp = Path(tmp) / "shot.bmp"
        for args in (["cjpm", "run", "--skip-build", "--run-args", f"--snapshot {bmp}"],
                     ["cjpm", "run", "--run-args", f"--snapshot {bmp}"]):
            proc = subprocess.run(args, cwd=str(example_dir), capture_output=True,
                                  text=True, encoding="utf-8", errors="replace")
            if bmp.exists():
                break
        if not bmp.exists():
            tail = (proc.stdout or "").strip().splitlines()[-3:]
            return "无快照产出：" + " / ".join(tail)
        width, height, rows = read_bmp(bmp)
        w, h, small = downscale(width, height, rows, max_width)
        write_png(out_png, w, h, small)
    return None


def main(argv=None):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="生成示例画廊截图")
    ap.add_argument("names", nargs="*", help="示例名（缺省为全部）")
    ap.add_argument("--max-width", type=int, default=1800, help="图片最大宽度（默认 1800，超出才降采样）")
    args = ap.parse_args(argv)

    IMAGES.mkdir(exist_ok=True)
    dirs = []
    for entry in sorted(EXAMPLES.iterdir()):
        if (entry / "cjpm.toml").exists() and (not args.names or entry.name in args.names):
            dirs.append(entry)
    if not dirs:
        print("没有匹配的示例。")
        return 2

    failures = []
    for entry in dirs:
        out = IMAGES / f"{entry.name}.png"
        error = shoot(entry, out, args.max_width)
        if error is None:
            size_kb = out.stat().st_size // 1024
            print(f"[OK]   {entry.name} -> .images/{entry.name}.png（{size_kb} KB）")
        else:
            failures.append(entry.name)
            print(f"[FAIL] {entry.name}: {error}")
    if failures:
        print(f"\n{len(failures)} 个示例拍摄失败：{', '.join(failures)}")
        return 1
    print(f"\n全部 {len(dirs)} 个示例已生成截图。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
