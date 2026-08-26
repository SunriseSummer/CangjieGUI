#!/usr/bin/env python3
"""Run and analyse the isolated phase-three architecture decision probes."""

import argparse
import json
import os
import statistics
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "phase3"
RESULTS = ROOT / "results"
RAW = RESULTS / "phase3.out.txt"
JSON_REPORT = RESULTS / "phase3.json"
MARKDOWN_REPORT = RESULTS / "phase3.md"
WINDOWS_PROJECT_BUILT = False
LAST_WINDOWS_PROBE_END = None
WINDOWS_PROBE_COOLDOWN_SECONDS = 1.0

sys.path.insert(0, str(ROOT.parent / ".devtools"))
from process_runner import run_command

NUMERIC_FIELDS = (
    "total_ns",
    "build_ns",
    "layout_ns",
    "event_ns",
    "draw_ns",
    "build_visits",
    "layout_visits",
    "event_visits",
    "draw_visits",
)


def parse_capture(lines):
    """Parse one probe capture and reject malformed, duplicate, or negative records."""
    records = {}
    observations = {}
    for line in lines:
        if line.startswith("@@PHASE3|"):
            parts = line.strip().split("|")
            if len(parts) != 13:
                raise ValueError(f"malformed phase-three record: {line}")
            try:
                scale = int(parts[2])
                values = [int(value) for value in parts[4:]]
            except ValueError as exc:
                raise ValueError(f"non-numeric phase-three record: {line}") from exc
            if scale < 0 or any(value < 0 for value in values):
                raise ValueError(f"invalid phase-three record range: {line}")
            key = (parts[1], scale, parts[3])
            if key in records:
                raise ValueError(f"duplicate phase-three record: {key}")
            record = {"experiment": parts[1], "scale": scale, "variant": parts[3]}
            record.update(dict(zip(NUMERIC_FIELDS, values)))
            records[key] = record
        elif line.startswith("@@PHASE3_ASSERT|"):
            parts = line.strip().split("|")
            if len(parts) != 4:
                raise ValueError(f"malformed phase-three observation: {line}")
            try:
                values = tuple(int(value) for value in parts[2:])
            except ValueError as exc:
                raise ValueError(f"non-numeric phase-three observation: {line}") from exc
            if any(value not in (0, 1) for value in values):
                raise ValueError(f"invalid phase-three observation range: {line}")
            if parts[1] in observations:
                raise ValueError(f"duplicate phase-three observation: {parts[1]}")
            observations[parts[1]] = values
        elif line.startswith("@@PHASE3_BUFFER|"):
            parts = line.strip().split("|")
            if len(parts) != 5:
                raise ValueError(f"malformed phase-three buffer record: {line}")
            try:
                scale, command_count, estimated_bytes = int(parts[1]), int(parts[3]), int(parts[4])
            except ValueError as exc:
                raise ValueError(f"non-numeric phase-three buffer record: {line}") from exc
            if scale < 0 or command_count < 0 or estimated_bytes < 0:
                raise ValueError(f"invalid phase-three buffer record range: {line}")
            key = f"paint-buffer/{scale}/{parts[2]}"
            if key in observations:
                raise ValueError(f"duplicate phase-three buffer record: {key}")
            observations[key] = (command_count, estimated_bytes)
        elif line.startswith("@@PHASE3_DIAG|"):
            parts = line.strip().split("|")
            if len(parts) != 4:
                raise ValueError(f"malformed phase-three diagnostic: {line}")
            try:
                values = tuple(int(value) for value in parts[2:])
            except ValueError as exc:
                raise ValueError(f"non-numeric phase-three diagnostic: {line}") from exc
            if any(value < 0 for value in values):
                raise ValueError(f"invalid phase-three diagnostic range: {line}")
            key = f"diag/{parts[1]}"
            if key in observations:
                raise ValueError(f"duplicate phase-three diagnostic: {key}")
            observations[key] = values
    if not records:
        raise ValueError("capture contains no @@PHASE3 records")
    return records, observations


def aggregate_captures(captures):
    """Take a per-field median after requiring identical record/observation sets."""
    parsed = [parse_capture(lines) for lines in captures]
    record_keys = list(parsed[0][0].keys())
    observation_keys = list(parsed[0][1].keys())
    expected_records = set(record_keys)
    expected_observations = set(observation_keys)
    for records, observations in parsed[1:]:
        if set(records) != expected_records:
            raise ValueError("phase-three record keys differ between samples")
        if set(observations) != expected_observations:
            raise ValueError("phase-three observation keys differ between samples")

    aggregated = {}
    for key in record_keys:
        first = parsed[0][0][key]
        record = {"experiment": first["experiment"], "scale": first["scale"], "variant": first["variant"]}
        for field in NUMERIC_FIELDS:
            record[field] = int(statistics.median(sample[0][key][field] for sample in parsed))
        aggregated[key] = record
    observations = {
        key: tuple(min(sample[1][key][index] for sample in parsed) for index in range(2))
        for key in observation_keys
    }
    return aggregated, observations


def evaluate_evidence(records, observations):
    """Evaluate architecture hypotheses using ratios and deterministic visit counts."""
    local_scales = sorted(key[1] for key in records if key[0] == "local-update" and key[2] == "full-tree")
    state_scales = sorted(key[1] for key in records if key[0] == "retained-state")
    effect_scales = sorted(key[1] for key in records if key[0] == "retained-effect")
    if not local_scales or not state_scales or not effect_scales:
        raise ValueError("capture is missing required pressure experiments")

    largest_local = local_scales[-1]
    full = records[("local-update", largest_local, "full-tree")]
    retained = records[("local-update", largest_local, "manual-retained")]
    automatic = records.get(("local-update", largest_local, "auto-retained"))
    if automatic is None:
        raise ValueError("capture is missing automatic retained experiment")
    command_buffer = records.get(("local-update", largest_local, "auto-command"))
    if command_buffer is None:
        raise ValueError("capture is missing automatic command-buffer experiment")
    smallest_command_buffer = records.get(("local-update", local_scales[0], "auto-command"))
    if smallest_command_buffer is None:
        raise ValueError("capture is missing small automatic command-buffer experiment")
    paint_buffer = observations.get(f"paint-buffer/{largest_local}/auto-command")
    if paint_buffer is None:
        raise ValueError("capture is missing paint-buffer memory observation")
    dynamic_paint = records.get(("local-update", largest_local, "auto-dynamic"))
    if dynamic_paint is None:
        raise ValueError("capture is missing dynamic-paint bypass experiment")
    dynamic_buffer = observations.get(f"paint-buffer/{largest_local}/auto-dynamic")
    if dynamic_buffer is None:
        raise ValueError("capture is missing dynamic-paint buffer observation")
    dynamic_probes = observations.get(f"diag/dynamic-probes-{largest_local}")
    dynamic_bypass = observations.get(f"diag/dynamic-bypass-{largest_local}")
    if dynamic_probes is None or dynamic_bypass is None:
        raise ValueError("capture is missing dynamic-paint backoff diagnostics")
    damage = records.get(("local-update", largest_local, "auto-damage"))
    if damage is None:
        raise ValueError("capture is missing retained-damage experiment")
    damage_buffer = observations.get(f"paint-buffer/{largest_local}/auto-damage")
    if damage_buffer is None:
        raise ValueError("capture is missing retained-damage memory observation")
    smallest_state = records[("retained-state", state_scales[0], "cache-hit")]
    largest_state = records[("retained-state", state_scales[-1], "cache-hit")]
    smallest_effect = records[("retained-effect", effect_scales[0], "cache-hit")]
    largest_effect = records[("retained-effect", effect_scales[-1], "cache-hit")]
    manual = observations.get("manual-revision", (0, 0))
    automatic_state = observations.get("automatic-state", (0, 0))

    speedup = ratio(full["total_ns"], retained["total_ns"])
    state_growth = ratio(largest_state["total_ns"], smallest_state["total_ns"])
    state_build_share = ratio(largest_state["build_ns"], largest_state["total_ns"])
    state_bottleneck = state_growth >= 8.0 and state_build_share >= 0.75
    state_ownership_bounded = state_growth <= 4.0
    effect_growth = ratio(largest_effect["total_ns"], smallest_effect["total_ns"])
    localized = retained["build_visits"] <= 2 and retained["layout_visits"] <= 2
    automatic_localized = automatic["build_visits"] <= 2 and automatic["layout_visits"] <= 2
    event_localized = retained["event_visits"] <= 2 and automatic["event_visits"] <= 2
    draw_fanout = retained["draw_visits"] >= largest_local and automatic["draw_visits"] >= largest_local
    paint_rerecord_localized = command_buffer["draw_visits"] <= 2
    paint_commands_per_region = ratio(paint_buffer[0], largest_local)
    paint_bytes_per_region = ratio(paint_buffer[1], largest_local)
    paint_memory_bounded = paint_buffer[0] > 0 and paint_bytes_per_region <= 32_768.0
    command_draw_speedup = ratio(automatic["draw_ns"], command_buffer["draw_ns"])
    command_total_speedup = ratio(automatic["total_ns"], command_buffer["total_ns"])
    replay_still_scales = ratio(command_buffer["draw_ns"], smallest_command_buffer["draw_ns"]) >= 2.0
    damage_draw_speedup = ratio(command_buffer["draw_ns"], damage["draw_ns"])
    damage_total_speedup = ratio(command_buffer["total_ns"], damage["total_ns"])
    damage_memory_stable = damage_buffer == paint_buffer
    dynamic_bypass_verified = dynamic_buffer == (0, 0) and dynamic_paint["draw_visits"] >= largest_local
    dynamic_uncached_total_penalty = ratio(dynamic_paint["total_ns"], automatic["total_ns"])
    dynamic_uncached_draw_penalty = ratio(dynamic_paint["draw_ns"], automatic["draw_ns"])
    dynamic_probe_rate = ratio(dynamic_probes[0], dynamic_probes[0] + dynamic_bypass[0])
    dynamic_backoff_diagnostics_verified = dynamic_probes[0] == dynamic_probes[1] and dynamic_bypass[0] > 0 and \
        dynamic_probe_rate <= 0.15

    return {
        "largest_local_scale": largest_local,
        "manual_retained_speedup": speedup,
        "automatic_retained_speedup": ratio(full["total_ns"], automatic["total_ns"]),
        "manual_revision_stale_observed": manual[0] == 1,
        "correct_revision_updates": manual[1] == 1,
        "automatic_state_updates": automatic_state[0] == 1,
        "automatic_stable_hit": automatic_state[1] == 1,
        "build_layout_localized": localized,
        "frame_event_localized": event_localized,
        "draw_still_fans_out": draw_fanout,
        "command_buffer_total_speedup": command_total_speedup,
        "command_buffer_draw_speedup": command_draw_speedup,
        "paint_rerecord_localized": paint_rerecord_localized,
        "paint_commands_per_region": paint_commands_per_region,
        "paint_bytes_per_region": paint_bytes_per_region,
        "paint_memory_bounded": paint_memory_bounded,
        "dynamic_paint_bypass_verified": dynamic_bypass_verified,
        "dynamic_paint_total_penalty": ratio(dynamic_paint["total_ns"], command_buffer["total_ns"]),
        "dynamic_paint_draw_penalty": ratio(dynamic_paint["draw_ns"], command_buffer["draw_ns"]),
        "dynamic_paint_uncached_total_penalty": dynamic_uncached_total_penalty,
        "dynamic_paint_uncached_draw_penalty": dynamic_uncached_draw_penalty,
        "dynamic_paint_backoff_target_met": dynamic_uncached_total_penalty <= 1.15 and
            dynamic_uncached_draw_penalty <= 1.15,
        "dynamic_paint_probe_rate": dynamic_probe_rate,
        "dynamic_paint_backoff_remaining": dynamic_bypass[1],
        "dynamic_paint_backoff_diagnostics_verified": dynamic_backoff_diagnostics_verified,
        "command_buffer_prototype_verified": paint_rerecord_localized and paint_memory_bounded and
            command_draw_speedup >= 1.10,
        "damage_after_command_buffer_candidate": replay_still_scales,
        "damage_total_speedup": damage_total_speedup,
        "damage_draw_speedup": damage_draw_speedup,
        "damage_memory_stable": damage_memory_stable,
        "damage_prototype_verified": damage["draw_visits"] <= 2 and damage_memory_stable and
            damage_draw_speedup >= 1.50,
        "largest_state_scale": state_scales[-1],
        "retained_state_cost_growth": state_growth,
        "retained_state_build_share": state_build_share,
        "supports_dependency_tracking": automatic_state == (1, 1) and
            ratio(full["total_ns"], automatic["total_ns"]) >= 2.0 and automatic_localized,
        "event_subscription_registry_verified": event_localized,
        "retained_scene_damage_needed": draw_fanout and ratio(
            retained["total_ns"], records[("local-update", local_scales[0], "manual-retained")]["total_ns"]
        ) >= 2.0,
        "retained_state_bottleneck_observed": state_bottleneck,
        "hierarchical_state_ownership_verified": state_ownership_bounded,
        "retained_effect_cost_growth": effect_growth,
        "hierarchical_effect_ownership_verified": effect_growth <= 4.0,
    }


def ratio(numerator, denominator):
    return float(numerator) / float(denominator) if denominator else 0.0


def machine_lines(records, observations, sample_count):
    lines = [f"@@PHASE3_META|samples|{sample_count}"]
    for record in records.values():
        values = "|".join(str(record[field]) for field in NUMERIC_FIELDS)
        lines.append(
            f"@@PHASE3|{record['experiment']}|{record['scale']}|{record['variant']}|{values}"
        )
    for name, values in observations.items():
        if name.startswith("paint-buffer/"):
            _, scale, variant = name.split("/", 2)
            lines.append(f"@@PHASE3_BUFFER|{scale}|{variant}|{values[0]}|{values[1]}")
        elif name.startswith("diag/"):
            lines.append(f"@@PHASE3_DIAG|{name[5:]}|{values[0]}|{values[1]}")
        else:
            lines.append(f"@@PHASE3_ASSERT|{name}|{values[0]}|{values[1]}")
    return lines


def format_duration(ns):
    if ns < 10_000:
        return f"{ns} ns"
    if ns < 10_000_000:
        return f"{ns / 1000.0:.2f} μs"
    return f"{ns / 1_000_000.0:.2f} ms"


def render_markdown(records, observations, evidence, sample_count):
    local = sorted((record for record in records.values() if record["experiment"] == "local-update"),
                   key=lambda record: (record["scale"], record["variant"]))
    states = sorted((record for record in records.values() if record["experiment"] == "retained-state"),
                    key=lambda record: record["scale"])
    effects = sorted((record for record in records.values() if record["experiment"] == "retained-effect"),
                     key=lambda record: record["scale"])
    lines = [
        "# CUI 架构压力与演进回归实验",
        "",
        f"生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}；独立样本：{sample_count}；逐字段取中位数。",
        "",
        "## 高频局部更新",
        "",
        "| 区域 | 变体 | 总帧时 | build | layout | event | draw | build/layout 访问 | event/draw 访问 |",
        "|---:|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for record in local:
        lines.append(
            f"| {record['scale']} | {record['variant']} | {format_duration(record['total_ns'])} | "
            f"{format_duration(record['build_ns'])} | {format_duration(record['layout_ns'])} | "
            f"{format_duration(record['event_ns'])} | {format_duration(record['draw_ns'])} | "
            f"{record['build_visits']}/{record['layout_visits']} | "
            f"{record['event_visits']}/{record['draw_visits']} |"
        )
    lines.extend([
        "",
        "## retained 状态生命周期",
        "",
        "| 后代状态 | 命中帧时 | build | layout | event | draw |",
        "|---:|---:|---:|---:|---:|---:|",
    ])
    for record in states:
        lines.append(
            f"| {record['scale']} | {format_duration(record['total_ns'])} | "
            f"{format_duration(record['build_ns'])} | {format_duration(record['layout_ns'])} | "
            f"{format_duration(record['event_ns'])} | {format_duration(record['draw_ns'])} |"
        )
    lines.extend([
        "",
        "## retained effect 生命周期",
        "",
        "| 后代 effect | 命中帧时 | build | layout | event | draw |",
        "|---:|---:|---:|---:|---:|---:|",
    ])
    for record in effects:
        lines.append(
            f"| {record['scale']} | {format_duration(record['total_ns'])} | "
            f"{format_duration(record['build_ns'])} | {format_duration(record['layout_ns'])} | "
            f"{format_duration(record['event_ns'])} | {format_duration(record['draw_ns'])} |"
        )
    manual = observations.get("manual-revision", (0, 0))
    lines.extend([
        "",
        "## 判定",
        "",
        f"- 固定 revision 后观察到旧快照：{'是' if manual[0] else '否'}；推进 revision 后更新：{'是' if manual[1] else '否'}。",
        f"- 最大局部更新场景的手工 retained 加速：{evidence['manual_retained_speedup']:.2f}x。",
        f"- 最大局部更新场景的自动 retained 加速：{evidence['automatic_retained_speedup']:.2f}x；"
        f"状态更新/稳定命中：{'通过' if evidence['automatic_state_updates'] and evidence['automatic_stable_hit'] else '失败'}。",
        f"- 命令缓冲相对自动 retained：总帧 {evidence['command_buffer_total_speedup']:.2f}x、draw "
        f"{evidence['command_buffer_draw_speedup']:.2f}x；dirty 重录局部化："
        f"{'通过' if evidence['paint_rerecord_localized'] else '失败'}。",
        f"- 命令缓冲密度：每区域 {evidence['paint_commands_per_region']:.1f} 条 / "
        f"约 {evidence['paint_bytes_per_region']:.0f} B；内存规模看护："
        f"{'通过' if evidence['paint_memory_bounded'] else '失败'}。",
        f"- 动态 paint 安全旁路：{'通过' if evidence['dynamic_paint_bypass_verified'] else '失败'}；"
        f"相对可缓存命令路径总帧/绘制代价：{evidence['dynamic_paint_total_penalty']:.2f}x / "
        f"{evidence['dynamic_paint_draw_penalty']:.2f}x；相对非缓存 retained："
        f"{evidence['dynamic_paint_uncached_total_penalty']:.2f}x / "
        f"{evidence['dynamic_paint_uncached_draw_penalty']:.2f}x，15% 目标："
        f"{'通过' if evidence['dynamic_paint_backoff_target_met'] else '未通过'}。",
        f"- 动态 paint 退避诊断：录制探测占动态 draw {evidence['dynamic_paint_probe_rate'] * 100:.1f}%，"
        f"剩余退避帧合计 {evidence['dynamic_paint_backoff_remaining']}；"
        f"{'通过' if evidence['dynamic_paint_backoff_diagnostics_verified'] else '失败'}。",
        f"- retained 状态命中成本增长：{evidence['retained_state_cost_growth']:.2f}x；最大规模 build 占比："
        f"{evidence['retained_state_build_share'] * 100:.1f}%。",
        f"- 状态依赖追踪证据：{'支持' if evidence['supports_dependency_tracking'] else '未达到阈值'}。",
        f"- Frame 订阅表规模看护：{'通过' if evidence['event_subscription_registry_verified'] else '失败'}。",
        f"- 全场 replay 随区域数增长的 damage 候选信号："
        f"{'存在' if evidence['retained_scene_damage_needed'] else '未观察到'}。",
        f"- 命令缓冲后 replay 仍随场景规模增长："
        f"{'是' if evidence['damage_after_command_buffer_candidate'] else '否'}。",
        f"- 显式 damage 相对全场命令重放：总帧 {evidence['damage_total_speedup']:.2f}x、draw "
        f"{evidence['damage_draw_speedup']:.2f}x；命令内存不增加："
        f"{'是' if evidence['damage_memory_stable'] else '否'}；1.50x 独立收益验收："
        f"{'通过' if evidence['damage_prototype_verified'] else '未通过'}。",
        f"- retained 状态扫描瓶颈：{'仍存在' if evidence['retained_state_bottleneck_observed'] else '未观察到'}；"
        f"层次化所有权规模看护：{'通过' if evidence['hierarchical_state_ownership_verified'] else '失败'}。",
        f"- retained effect 命中成本增长：{evidence['retained_effect_cost_growth']:.2f}x；"
        f"层次化 effect 所有权规模看护：{'通过' if evidence['hierarchical_effect_ownership_verified'] else '失败'}。",
        "",
        "这些结论只描述当前架构成本，不自动指定实现方案；最终方案需结合复杂度、内存和正确性权衡。",
        "",
    ])
    return "\n".join(lines)


def run_probe(timeout):
    global LAST_WINDOWS_PROBE_END, WINDOWS_PROJECT_BUILT
    if os.name == "nt":
        if not WINDOWS_PROJECT_BUILT:
            build_code, build_stdout, build_stderr, build_timed_out = run_command(["cjpm", "build"], PROJECT, timeout)
            if build_code != 0:
                suffix = f"; timed out after {timeout}s" if build_timed_out else ""
                raise RuntimeError(
                    f"phase-three build failed (exit {build_code}{suffix})\n{build_stdout}{build_stderr}")
            WINDOWS_PROJECT_BUILT = True
        executable = PROJECT / "target" / "release" / "bin" / "main.exe"
        if not executable.is_file():
            raise RuntimeError(f"phase-three executable is missing: {executable}")
        environment = os.environ.copy()
        sdl_runtime = ROOT.parent.parent / "CangjieSDL" / ".sdl3"
        environment["PATH"] = str(sdl_runtime) + os.pathsep + environment.get("PATH", "")
        if LAST_WINDOWS_PROBE_END is None:
            time.sleep(WINDOWS_PROBE_COOLDOWN_SECONDS)
        else:
            remaining = WINDOWS_PROBE_COOLDOWN_SECONDS - (time.monotonic() - LAST_WINDOWS_PROBE_END)
            if remaining > 0.0:
                time.sleep(remaining)
        code, stdout, stderr, timed_out = run_command(
            [str(executable)], PROJECT, timeout, env=environment, new_process_group=False)
        LAST_WINDOWS_PROBE_END = time.monotonic()
    else:
        code, stdout, stderr, timed_out = run_command(["cjpm", "run"], PROJECT, timeout)
    if code != 0:
        suffix = f"; timed out after {timeout}s" if timed_out else ""
        raise RuntimeError(f"phase-three probe failed (exit {code}{suffix})\n{stdout}{stderr}")
    return stdout.splitlines()


def main():
    parser = argparse.ArgumentParser(description="Run CUI phase-three architecture decision probes.")
    parser.add_argument("--samples", type=int, default=3, help="independent samples (default 3)")
    parser.add_argument("--timeout", type=int, default=300, help="timeout for each sample (default 300s)")
    parser.add_argument("--no-run", action="store_true", help="reuse the last aggregated capture")
    args = parser.parse_args()
    if args.samples <= 0:
        parser.error("--samples must be greater than zero")
    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")

    RESULTS.mkdir(parents=True, exist_ok=True)
    if args.no_run:
        if not RAW.exists():
            raise ValueError(f"no cached phase-three capture at {RAW}")
        cached_lines = RAW.read_text(encoding="utf-8").splitlines()
        captures = [cached_lines]
        sample_count = cached_sample_count(cached_lines)
    else:
        captures = []
        for sample in range(1, args.samples + 1):
            print(f"phase-three sample {sample}/{args.samples}")
            captures.append(run_probe(args.timeout))
        sample_count = args.samples

    records, observations = aggregate_captures(captures)
    evidence = evaluate_evidence(records, observations)
    RAW.write_text("\n".join(machine_lines(records, observations, sample_count)) + "\n", encoding="utf-8")
    JSON_REPORT.write_text(json.dumps({
        "samples": sample_count,
        "records": list(records.values()),
        "observations": {key: list(value) for key, value in observations.items()},
        "evidence": evidence,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    MARKDOWN_REPORT.write_text(render_markdown(records, observations, evidence, sample_count), encoding="utf-8")

    print(f"report: {MARKDOWN_REPORT}")
    print(f"manual retained speedup: {evidence['manual_retained_speedup']:.2f}x")
    print(f"retained-state hit cost growth: {evidence['retained_state_cost_growth']:.2f}x")
    print(f"retained-effect hit cost growth: {evidence['retained_effect_cost_growth']:.2f}x")
    print("command buffer: total={:.2f}x draw={:.2f}x rerecord-localized={} memory-bounded={} damage-candidate={}".format(
        evidence["command_buffer_total_speedup"],
        evidence["command_buffer_draw_speedup"],
        evidence["paint_rerecord_localized"],
        evidence["paint_memory_bounded"],
        evidence["damage_after_command_buffer_candidate"],
    ))
    print("dynamic paint bypass: verified={} cache-penalty={:.2f}x/{:.2f}x uncached-penalty={:.2f}x/{:.2f}x target={} probe-rate={:.1f}%".format(
        evidence["dynamic_paint_bypass_verified"], evidence["dynamic_paint_total_penalty"],
        evidence["dynamic_paint_draw_penalty"],
        evidence["dynamic_paint_uncached_total_penalty"], evidence["dynamic_paint_uncached_draw_penalty"],
        evidence["dynamic_paint_backoff_target_met"],
        evidence["dynamic_paint_probe_rate"] * 100.0,
    ))
    print("damage prototype: total={:.2f}x draw={:.2f}x memory-stable={} verified={}".format(
        evidence["damage_total_speedup"], evidence["damage_draw_speedup"],
        evidence["damage_memory_stable"], evidence["damage_prototype_verified"],
    ))
    print("evidence: dependency-tracking={} frame-subscriptions={} retained-scene-damage-needed={} state-bottleneck={} state-ownership-bounded={}".format(
        evidence["supports_dependency_tracking"],
        evidence["event_subscription_registry_verified"],
        evidence["retained_scene_damage_needed"],
        evidence["retained_state_bottleneck_observed"],
        evidence["hierarchical_state_ownership_verified"],
    ))
    return 0


def cached_sample_count(lines):
    for line in lines:
        if line.startswith("@@PHASE3_META|samples|"):
            parts = line.strip().split("|")
            if len(parts) != 3:
                raise ValueError(f"malformed phase-three metadata: {line}")
            try:
                count = int(parts[2])
            except ValueError as exc:
                raise ValueError(f"non-numeric phase-three metadata: {line}") from exc
            if count <= 0:
                raise ValueError(f"invalid phase-three metadata range: {line}")
            return count
    return 1


if __name__ == "__main__":
    try:
        exit_code = main()
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Phase-three probe failed: {exc}", file=sys.stderr)
        exit_code = 2
    sys.exit(exit_code)
