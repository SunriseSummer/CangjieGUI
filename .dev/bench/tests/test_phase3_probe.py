#!/usr/bin/env python3
"""Self-tests for strict phase-three record aggregation and evidence logic."""

import unittest

from bench.tooling import phase3_probe as probe


def record(experiment, scale, variant, total, build, layout, event, draw, build_v, layout_v, event_v, draw_v):
    return (f"@@PHASE3|{experiment}|{scale}|{variant}|{total}|{build}|{layout}|{event}|{draw}|"
            f"{build_v}|{layout_v}|{event_v}|{draw_v}")


class PhaseThreeProbeTest(unittest.TestCase):
    def test_capture_rejects_negative_and_malformed_records(self):
        with self.assertRaises(ValueError):
            probe.parse_capture([record("x", 1, "v", -1, 0, 0, 0, 0, 0, 0, 0, 0)])
        with self.assertRaises(ValueError):
            probe.parse_capture(["@@PHASE3|too|short"])
        with self.assertRaises(ValueError):
            probe.parse_capture(["@@PHASE3_BUFFER|8|auto-command|-1|100"])

    def test_aggregation_uses_field_medians(self):
        captures = []
        for total in (300, 100, 200):
            captures.append([
                record("local-update", 8, "full-tree", total, 10, 20, 30, 40, 8, 8, 8, 8),
                "@@PHASE3_ASSERT|manual-revision|1|1",
            ])
        records, observations = probe.aggregate_captures(captures)
        self.assertEqual(records[("local-update", 8, "full-tree")]["total_ns"], 200)
        self.assertEqual(observations["manual-revision"], (1, 1))

    def test_aggregation_rejects_different_case_sets(self):
        first = [record("x", 1, "a", 1, 1, 1, 1, 1, 1, 1, 1, 1)]
        second = [record("x", 2, "a", 1, 1, 1, 1, 1, 1, 1, 1, 1)]
        with self.assertRaises(ValueError):
            probe.aggregate_captures([first, second])

    def test_cached_sample_count_preserves_aggregate_provenance(self):
        self.assertEqual(probe.cached_sample_count(["@@PHASE3_META|samples|5"]), 5)
        with self.assertRaises(ValueError):
            probe.cached_sample_count(["@@PHASE3_META|samples|0"])

    def test_evidence_detects_localization_residual_fanout_and_state_growth(self):
        lines = [
            record("local-update", 8, "full-tree", 800, 100, 300, 100, 300, 8, 8, 8, 8),
            record("local-update", 8, "manual-retained", 200, 20, 20, 5, 100, 1, 1, 0, 8),
            record("local-update", 8, "auto-retained", 210, 25, 25, 5, 100, 1, 1, 0, 8),
            record("local-update", 8, "auto-command", 160, 25, 25, 5, 55, 1, 1, 0, 1),
            record("local-update", 8, "auto-dynamic", 260, 25, 25, 5, 155, 1, 1, 0, 8),
            record("local-update", 8, "auto-damage", 130, 25, 25, 5, 20, 1, 1, 0, 1),
            record("local-update", 64, "full-tree", 6400, 800, 2400, 800, 2400, 64, 64, 64, 64),
            record("local-update", 64, "manual-retained", 800, 50, 50, 5, 400, 1, 1, 0, 64),
            record("local-update", 64, "auto-retained", 850, 60, 60, 5, 400, 1, 1, 0, 64),
            record("local-update", 64, "auto-command", 500, 60, 60, 5, 200, 1, 1, 0, 1),
            record("local-update", 64, "auto-dynamic", 1200, 60, 60, 5, 900, 1, 1, 0, 64),
            record("local-update", 64, "auto-damage", 350, 60, 60, 5, 30, 1, 1, 0, 1),
            record("retained-state", 0, "cache-hit", 10, 5, 1, 1, 1, 0, 0, 1, 1),
            record("retained-state", 8192, "cache-hit", 1000, 900, 10, 10, 10, 0, 0, 1, 1),
            record("retained-effect", 0, "cache-hit", 10, 5, 1, 1, 1, 0, 0, 1, 1),
            record("retained-effect", 8192, "cache-hit", 1000, 900, 10, 10, 10, 0, 0, 1, 1),
            "@@PHASE3_ASSERT|manual-revision|1|1",
            "@@PHASE3_ASSERT|automatic-state|1|1",
            "@@PHASE3_BUFFER|8|auto-command|64|4096",
            "@@PHASE3_BUFFER|64|auto-command|512|32768",
            "@@PHASE3_BUFFER|8|auto-dynamic|0|0",
            "@@PHASE3_BUFFER|64|auto-dynamic|0|0",
            "@@PHASE3_DIAG|dynamic-probes-8|2|2",
            "@@PHASE3_DIAG|dynamic-bypass-8|20|8",
            "@@PHASE3_DIAG|dynamic-probes-64|10|10",
            "@@PHASE3_DIAG|dynamic-bypass-64|100|32",
            "@@PHASE3_BUFFER|8|auto-damage|64|4096",
            "@@PHASE3_BUFFER|64|auto-damage|512|32768",
        ]
        records, observations = probe.parse_capture(lines)
        evidence = probe.evaluate_evidence(records, observations)
        self.assertTrue(evidence["supports_dependency_tracking"])
        self.assertTrue(evidence["event_subscription_registry_verified"])
        self.assertTrue(evidence["retained_scene_damage_needed"])
        self.assertTrue(evidence["retained_state_bottleneck_observed"])
        self.assertFalse(evidence["hierarchical_state_ownership_verified"])
        self.assertFalse(evidence["hierarchical_effect_ownership_verified"])
        self.assertTrue(evidence["command_buffer_prototype_verified"])
        self.assertTrue(evidence["dynamic_paint_bypass_verified"])
        self.assertAlmostEqual(evidence["dynamic_paint_uncached_total_penalty"], 1200 / 850)
        self.assertFalse(evidence["dynamic_paint_backoff_target_met"])
        self.assertTrue(evidence["dynamic_paint_backoff_diagnostics_verified"])
        self.assertTrue(evidence["damage_after_command_buffer_candidate"])
        self.assertTrue(evidence["damage_prototype_verified"])

    def test_evidence_verifies_bounded_retained_state_hit_cost(self):
        lines = [
            record("local-update", 8, "full-tree", 800, 100, 300, 100, 300, 8, 8, 8, 8),
            record("local-update", 8, "manual-retained", 200, 20, 20, 5, 100, 1, 1, 0, 8),
            record("local-update", 8, "auto-retained", 210, 25, 25, 5, 100, 1, 1, 0, 8),
            record("local-update", 8, "auto-command", 160, 25, 25, 5, 50, 1, 1, 0, 1),
            record("local-update", 8, "auto-dynamic", 260, 25, 25, 5, 150, 1, 1, 0, 8),
            record("local-update", 8, "auto-damage", 130, 25, 25, 5, 20, 1, 1, 0, 1),
            record("retained-state", 0, "cache-hit", 100, 50, 10, 10, 10, 0, 0, 1, 1),
            record("retained-state", 8192, "cache-hit", 120, 60, 10, 10, 10, 0, 0, 1, 1),
            record("retained-effect", 0, "cache-hit", 100, 50, 10, 10, 10, 0, 0, 1, 1),
            record("retained-effect", 8192, "cache-hit", 130, 60, 10, 10, 10, 0, 0, 1, 1),
            "@@PHASE3_ASSERT|manual-revision|1|1",
            "@@PHASE3_ASSERT|automatic-state|1|1",
            "@@PHASE3_BUFFER|8|auto-command|64|4096",
            "@@PHASE3_BUFFER|8|auto-dynamic|0|0",
            "@@PHASE3_DIAG|dynamic-probes-8|2|2",
            "@@PHASE3_DIAG|dynamic-bypass-8|20|8",
            "@@PHASE3_BUFFER|8|auto-damage|64|4096",
        ]
        records, observations = probe.parse_capture(lines)
        evidence = probe.evaluate_evidence(records, observations)
        self.assertFalse(evidence["retained_state_bottleneck_observed"])
        self.assertTrue(evidence["hierarchical_state_ownership_verified"])
        self.assertTrue(evidence["hierarchical_effect_ownership_verified"])


if __name__ == "__main__":
    unittest.main()
