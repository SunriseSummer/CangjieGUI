#!/usr/bin/env python3
"""One-click CUI benchmark runner (cross-platform).

Builds and runs the headless benchmarks, parses their machine-readable @@RESULT lines, and renders
a self-contained HTML report (bench/results/report.html) that lays each per-frame cost against the
interactive frame budgets (120 / 60 / 30 fps) and auto-derives a strengths / weaknesses summary.

Headless numbers measure CPU-side build / layout / draw only (text is estimated, not rasterised).
With --display it also runs the self-terminating display benchmarks (bench/planner_scroll,
bench/large_table), which measure real per-frame cost including SDL text rasterisation, and folds
those in. See bench/README.md.

Usage:
    python bench/run.py                 # build + run headless, write the report
    python bench/run.py --open          # ...and open it in a browser
    python bench/run.py --no-run        # reuse the last capture, just re-render the report
    python bench/run.py --display       # also run the display benchmarks (opens brief windows)
    python bench/run.py --save-baseline # record current per-frame costs as the regression baseline
    python bench/run.py --check         # fail (exit 1) if any case regressed past the threshold
"""

import argparse
import subprocess
import sys
import webbrowser
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"
TEMPLATE = ROOT / "report.template.html"
RAW = RESULTS / "micro.out.txt"
REPORT = RESULTS / "report.html"
BASELINE = ROOT / "baseline.json"

FRAME_60 = 16_666_667   # ns budget for 60 fps
FRAME_120 = 8_333_333   # ns budget for 120 fps
FRAME_30 = 33_333_333   # ns budget for 30 fps
REGRESSION = 1.25       # --check flags a case slower than baseline by more than this factor

RATING_LABEL = {
    "ok": "120fps 就绪",
    "good": "60fps 就绪",
    "warn": "30fps 及格",
    "bad": "低于 30fps",
}

DISPLAY_APPS = ["planner_scroll", "large_table"]


def run_cjpm(pkg_dir: Path, action: str = "run") -> list:
    """Run `cjpm <action>` in pkg_dir and return its stdout as a list of lines."""
    proc = subprocess.run(
        ["cjpm", action],
        cwd=str(pkg_dir),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0 and not proc.stdout:
        sys.stderr.write(proc.stderr or "")
    return proc.stdout.splitlines()


def parse_results(lines):
    frame, micro, display = [], [], []
    for ln in lines:
        if not ln.startswith("@@RESULT"):
            continue
        parts = ln.strip().split("|")
        if len(parts) < 6:
            continue
        rec = {
            "kind": parts[1],
            "group": parts[2],
            "name": parts[3],
            "ns": int(parts[4]),
            "iters": int(parts[5]),
        }
        if rec["kind"] == "frame":
            frame.append(rec)
        elif rec["kind"] == "display":
            display.append(rec)
        else:
            micro.append(rec)
    return frame, micro, display


def parse_counts(lines):
    counts = []
    for ln in lines:
        if not ln.startswith("@@COUNT"):
            continue
        parts = ln.strip().split("|")
        if len(parts) < 4:
            continue
        counts.append({"group": parts[1], "name": parts[2], "count": int(parts[3])})
    return counts


def fmt_dur(ns: float) -> str:
    ns = float(ns)
    if ns < 10_000:
        return f"{ns:.0f} ns"
    if ns < 10_000_000:
        return f"{ns / 1000:.2f} us"
    return f"{ns / 1_000_000:.3f} ms"


def frame_class(ns: float) -> str:
    if ns <= FRAME_120:
        return "ok"
    if ns <= FRAME_60:
        return "good"
    if ns <= FRAME_30:
        return "warn"
    return "bad"


def esc(text: str) -> str:
    return (str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def fps_of(ns: float) -> int:
    return round(1e9 / ns) if ns > 0 else 0


def frame_row(rec) -> str:
    cls = frame_class(rec["ns"])
    fps = fps_of(rec["ns"])
    pct = min(100, round(rec["ns"] / FRAME_60 * 100))
    return f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""


def micro_row(rec, max_ns) -> str:
    ops = fps_of(rec["ns"])
    pct = max(5, round(rec["ns"] / max_ns * 100)) if max_ns > 0 else 5
    return f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{ops:,}</td>
        <td class="barcell"><div class="bar"><div class="fill micro" style="width:{pct}%"></div></div></td>
      </tr>
"""


def build_display_section(display) -> str:
    if not display:
        return (
            '<div class="note"><p class="muted" style="margin:0">尚未采集上机实测数据。运行 '
            "<code>python bench/run.py --display</code> 会启动自终止的端到端基准（短暂开窗、跑满固定帧数后自动退出），"
            "将含 GPU 与文本光栅的真实帧率并入本报告。</p></div>"
        )
    rows = ""
    for rec in sorted(display, key=lambda r: r["ns"], reverse=True):
        cls = frame_class(rec["ns"])
        fps = fps_of(rec["ns"])
        pct = min(100, round(rec["ns"] / FRAME_60 * 100))
        rows += f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>用例</th><th>每帧耗时（真实）</th><th>实测帧率</th><th>评级</th><th>预算占用（相对 16.67ms）</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>"""


def build_count_section(counts) -> str:
    if not counts:
        return ('<div class="note"><p class="muted" style="margin:0">无文本度量诊断数据。</p></div>')
    mx = max((c["count"] for c in counts), default=1) or 1
    rows = ""
    for c in sorted(counts, key=lambda r: r["count"], reverse=True):
        pct = max(3, round(c["count"] / mx * 100))
        cls = "bad" if c["count"] > 500 else ("warn" if c["count"] > 120 else "ok")
        rows += f"""      <tr>
        <td>{esc(c['name'])}</td>
        <td class="num">{c['count']:,}</td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>每帧文本度量次数</th><th>相对量（越短越好）</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>
  <p class="muted" style="font-size:12.5px">每帧文本度量次数 × 单次 SDL_ttf 成本 ≈ 该帧文本预算。未窗口化的组合内容页每帧上千次度量，是 planner 右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。</p>"""


def git_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True,
        )
        return out.stdout.strip() or "(no git)"
    except Exception:
        return "(no git)"


def toolchain() -> str:
    try:
        out = subprocess.run(["cjc", "--version"], capture_output=True, text=True)
        line = (out.stdout or out.stderr).splitlines()
        return line[0].strip() if line else "-"
    except Exception:
        return "-"


def load_baseline():
    import json
    if BASELINE.exists():
        return json.loads(BASELINE.read_text(encoding="utf-8"))
    return {}


def save_baseline(frame, display):
    import json
    data = {f"{r['kind']}|{r['group']}|{r['name']}": r["ns"] for r in list(frame) + list(display)}
    BASELINE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Baseline saved to {BASELINE} ({len(data)} cases).")


def check_regressions(frame, display) -> int:
    base = load_baseline()
    if not base:
        print("No baseline.json; run with --save-baseline first.", file=sys.stderr)
        return 2
    regressed = []
    for r in list(frame) + list(display):
        key = f"{r['kind']}|{r['group']}|{r['name']}"
        if key in base and base[key] > 0 and r["ns"] > base[key] * REGRESSION:
            regressed.append((key, base[key], r["ns"]))
    if regressed:
        print(f"Performance regressions (> {int((REGRESSION - 1) * 100)}% vs baseline):", file=sys.stderr)
        for key, was, now in regressed:
            print(f"  {key}: {fmt_dur(was)} -> {fmt_dur(now)}", file=sys.stderr)
        return 1
    print("No regressions past threshold.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="CUI benchmark runner + HTML report.")
    ap.add_argument("--no-run", action="store_true", help="reuse the last capture instead of rebuilding")
    ap.add_argument("--open", action="store_true", help="open the report when finished")
    ap.add_argument("--display", action="store_true", help="also run the display benchmarks")
    ap.add_argument("--save-baseline", action="store_true", help="record current costs as the regression baseline")
    ap.add_argument("--check", action="store_true", help="exit non-zero if a case regressed past the threshold")
    args = ap.parse_args()

    RESULTS.mkdir(parents=True, exist_ok=True)

    if args.no_run:
        if not RAW.exists():
            print(f"No cached output at {RAW}; run without --no-run first.", file=sys.stderr)
            return 2
        lines = RAW.read_text(encoding="utf-8").splitlines()
    else:
        print("Building and running headless benchmarks (bench/micro)...")
        lines = run_cjpm(ROOT / "micro", "run")
        RAW.write_text("\n".join(lines), encoding="utf-8")

    frame, micro, display = parse_results(lines)
    counts = parse_counts(lines)

    if args.display and not args.no_run:
        for app in DISPLAY_APPS:
            app_dir = ROOT / app
            if not (app_dir / "cjpm.toml").exists():
                continue
            print(f"Running display benchmark bench/{app} (opens a brief window)...")
            _f, _m, d = parse_results(run_cjpm(app_dir, "run"))
            display.extend(d)

    if not frame and not micro and not display:
        print("No @@RESULT lines parsed. Did the build or run fail?", file=sys.stderr)
        return 2

    if args.save_baseline:
        save_baseline(frame, display)
    if args.check:
        return check_regressions(frame, display)

    # --- render ---
    frame_sorted = sorted(frame, key=lambda r: r["ns"], reverse=True)
    over = [r for r in frame_sorted if r["ns"] > FRAME_60]
    comfy = [r for r in frame_sorted if r["ns"] <= FRAME_120]

    worst = "n/a"
    if frame_sorted:
        w = frame_sorted[0]
        worst = f"{esc(w['group'])} / {esc(w['name'])} - {fmt_dur(w['ns'])} (~{fps_of(w['ns'])} fps)"

    frame_rows = "".join(frame_row(r) for r in frame_sorted)

    micro_rows = ""
    groups = {}
    for r in micro:
        groups.setdefault(r["group"], []).append(r)
    for name, recs in groups.items():
        mx = max(r["ns"] for r in recs)
        for r in sorted(recs, key=lambda r: r["ns"], reverse=True):
            micro_rows += micro_row(r, mx)

    weak = ""
    for r in over:
        weak += f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - {fmt_dur(r['ns'])} (~{fps_of(r['ns'])} fps)</li>\n"
    if not weak:
        weak = '        <li class="muted">没有超出 60fps 预算的用例。</li>\n'

    strong = ""
    for r in sorted(comfy, key=lambda r: r["ns"]):
        strong += f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - {fmt_dur(r['ns'])}</li>\n"
    if not strong:
        strong = '        <li class="muted">暂无进入 120fps 区间的帧用例。</li>\n'

    meta = f"生成于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ｜ 提交 {git_commit()} ｜ {esc(toolchain())}"

    html = TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "{{META}}": meta,
        "{{FRAME_COUNT}}": str(len(frame)),
        "{{OVER_COUNT}}": str(len(over)),
        "{{COMFORT_COUNT}}": str(len(comfy)),
        "{{WORST}}": worst,
        "{{FRAME_ROWS}}": frame_rows,
        "{{DISPLAY_SECTION}}": build_display_section(display),
        "{{COUNT_SECTION}}": build_count_section(counts),
        "{{WEAK_ITEMS}}": weak,
        "{{STRONG_ITEMS}}": strong,
        "{{MICRO_ROWS}}": micro_rows,
    }
    for token, value in replacements.items():
        html = html.replace(token, value)

    REPORT.write_text(html, encoding="utf-8")
    print(f"\nReport written to {REPORT}")
    print(f"Frame cases: {len(frame)}  |  over 60fps budget: {len(over)}  |  at 120fps: {len(comfy)}"
          + (f"  |  display cases: {len(display)}" if display else ""))

    if args.open:
        webbrowser.open(REPORT.as_uri())
    return 0


if __name__ == "__main__":
    sys.exit(main())
