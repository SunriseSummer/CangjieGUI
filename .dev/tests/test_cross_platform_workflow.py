#!/usr/bin/env python3
"""Fail-closed contract checks for the expensive three-platform qualification workflow."""

import unittest

from cui_dev.common.paths import REPOSITORY_ROOT


WORKFLOW = REPOSITORY_ROOT / ".github" / "workflows" / "cross-platform-qualification.yml"


class CrossPlatformWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text(encoding="utf-8")
        cls.portable = cls.text.split("  portable:\n", 1)[1].split("  qualify:\n", 1)[0]
        cls.qualify = cls.text.split("  qualify:\n", 1)[1]

    def test_exact_qualification_profiles_are_present(self):
        for profile in ("windows-x86_64", "linux-x86_64", "macos-arm64"):
            self.assertEqual(self.qualify.count(f"profile: {profile}"), 1)

    def test_hosted_portability_lane_covers_fresh_linux_and_arm_macos(self):
        self.assertEqual(self.portable.count("profile: linux-x86_64"), 1)
        self.assertEqual(self.portable.count("profile: macos-arm64"), 1)
        self.assertNotIn("profile: windows-x86_64", self.portable)
        self.assertIn("runner: ubuntu-24.04", self.portable)
        self.assertIn("runner: macos-15", self.portable)
        for command in (
                "python .dev/cli.py release bootstrap",
                "python .dev/cli.py release build-sdl",
                "python .dev/cli.py release stage-runtime"):
            self.assertIn(command, self.portable)
        self.assertIn("steps.bootstrap.outputs.cangjie_runtime", self.portable)
        self.assertIn("run: cjc --version && cjpm --version", self.portable)
        self.assertIn("python .dev/cli.py test tools", self.portable)
        self.assertIn("python .dev/cli.py test tools", self.qualify)

    def test_runner_requires_toolchain_and_interactive_gui_labels(self):
        self.assertIn(
            'runs-on: [self-hosted, "${{ matrix.os_label }}", "${{ matrix.arch_label }}", '
            'cangjie-1.0.5, cui-gui]', self.qualify)
        self.assertIn("--expected-profile ${{ matrix.profile }}", self.qualify)

    def test_both_repositories_and_explicit_runtimes_are_staged(self):
        for lane in (self.portable, self.qualify):
            self.assertEqual(lane.count("uses: actions/checkout@v6"), 2)
            self.assertIn("repository: SunriseSummer/CangjieSDL", lane)
            self.assertIn("python .dev/cli.py release stage-runtime", lane)

    def test_real_window_delivery_and_cross_platform_evidence_are_required(self):
        required = (
            "python .dev/cli.py test examples --smoke-snapshots --retained-diff",
            "python .dev/cli.py release verify",
            "python .dev/cli.py bench probe --samples 3",
            "python .dev/cli.py test packages",
        )
        for command in required:
            self.assertIn(command, self.qualify)

    def test_performance_modes_never_share_an_ambiguous_action(self):
        self.assertIn("options:\n          - report\n          - candidate\n          - check", self.text)
        self.assertEqual(self.qualify.count("--capture-baseline-candidate"), 1)
        self.assertEqual(self.qualify.count("--check --timeout 600"), 1)

    def test_workflow_cannot_soft_fail_qualification_steps(self):
        self.assertNotIn("continue-on-error", self.text)
        self.assertNotIn("|| true", self.text)
        self.assertEqual(self.text.count("fail-fast: false"), 2)
        self.assertEqual(self.text.count("if-no-files-found: error"), 2)


if __name__ == "__main__":
    unittest.main()
