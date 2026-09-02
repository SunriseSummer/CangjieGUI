"""Human-readable duration formatting and HTML report sections."""

from bench.tooling.config import FRAME_120, FRAME_30, FRAME_60, RATING_LABEL
from bench.tooling.parsing import index_distributions

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


def build_display_section(display, distributions) -> str:
    if not display:
        return (
            '<div class="note"><p class="muted" style="margin:0">尚未采集上机实测数据。运行 '
            "<code>python .dev/cli.py bench run --display</code> 会启动自终止的端到端基准（短暂开窗、跑满固定帧数后自动退出），"
            "将含 GPU 与文本光栅的真实帧率并入本报告。</p></div>"
        )
    distribution_by_case = index_distributions(distributions)
    rows = ""
    for rec in sorted(display, key=lambda r: distribution_by_case.get(
            (r["group"], r["name"]), {}).get("p95Ns", r["ns"]), reverse=True):
        distribution = distribution_by_case.get((rec["group"], rec["name"]))
        judged_ns = distribution["p95Ns"] if distribution else rec["ns"]
        cls = frame_class(judged_ns)
        fps = fps_of(rec["ns"])
        miss = (f"{distribution['over60FpsBudget'] / distribution['samples'] * 100:.1f}%"
                if distribution else "-")
        p50 = fmt_dur(distribution["p50Ns"]) if distribution else "-"
        p95 = fmt_dur(distribution["p95Ns"]) if distribution else "-"
        p99 = fmt_dur(distribution["p99Ns"]) if distribution else "-"
        maximum = fmt_dur(distribution["maxNs"]) if distribution else "-"
        rows += f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{p50}</td>
        <td class="num">{p95}</td>
        <td class="num">{p99}</td>
        <td class="num">{maximum}</td>
        <td class="num">{miss}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>用例</th><th>均值</th><th>P50</th><th>P95</th>
        <th>P99</th><th>最大</th><th>超 60fps 预算</th><th>均值帧率</th><th>P95 评级</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>
  <p class="muted" style="font-size:12.5px">分位数来自单次上机运行的完整帧样本；多次运行时逐字段取中位数。评级按 P95，而非容易掩盖尾延迟的均值。</p>"""


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
  <p class="muted" style="font-size:12.5px">每帧文本度量次数 × 单次 SDL_ttf 成本 ≈ 该帧文本预算。
  未窗口化的组合内容页每帧上千次度量，是 planner 右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。</p>"""
