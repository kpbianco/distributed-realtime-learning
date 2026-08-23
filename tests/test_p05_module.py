from __future__ import annotations

import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "modules/05-separate-clock-offset-from-network-delay"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you separate "
    "Clock Offset from Network Delay?"
)
ARTIFACTS = (
    "README.md",
    "lesson.m",
    "model.m",
    "experiment.m",
    "interactive.m",
    "lesson.md",
    "walkthrough.md",
    "checks.md",
    "run_checks.m",
)
QUEUE_SHAPE = (0.0, 0.25, 0.75, 0.5, 1.0, 0.25, 0.5, 0.0)


def reference_clock_delay(
    sample_count: int = 8,
    clock_offset_ms: float = 7,
    propagation_delay_ms: float = 3,
    queue_peak_delay_ms: float = 8,
    hidden_common_delay_ms: float = 0,
    assumed_minimum_delay_ms: float = 3,
) -> dict[str, object]:
    """Independent one-way timestamp arithmetic for retained static evidence."""
    sample_index = list(range(1, sample_count + 1))
    send = [20.0 * index for index in range(sample_count)]
    queue_shape = [QUEUE_SHAPE[index % len(QUEUE_SHAPE)] for index in range(sample_count)]
    queue = [queue_peak_delay_ms * value for value in queue_shape]
    network = [
        propagation_delay_ms + hidden_common_delay_ms + value for value in queue
    ]
    arrival = [sent + delay for sent, delay in zip(send, network)]
    receiver = [value + clock_offset_ms for value in arrival]
    observed = [received - sent for received, sent in zip(receiver, send)]
    observed_minimum = min(observed)
    estimated_offset = observed_minimum - assumed_minimum_delay_ms
    estimated_network = [value - estimated_offset for value in observed]
    estimated_queue = [
        value - assumed_minimum_delay_ms for value in estimated_network
    ]
    offset_error = estimated_offset - clock_offset_ms
    network_error = [
        estimated - actual
        for estimated, actual in zip(estimated_network, network)
    ]
    residual = [
        estimated_offset + delay - value
        for delay, value in zip(estimated_network, observed)
    ]
    actual_floor = min(network)
    return {
        "sample_index": sample_index,
        "send": send,
        "queue_shape": queue_shape,
        "queue": queue,
        "network": network,
        "arrival": arrival,
        "receiver": receiver,
        "observed": observed,
        "observed_minimum": observed_minimum,
        "observed_spread": max(observed) - observed_minimum,
        "estimated_offset": estimated_offset,
        "estimated_network": estimated_network,
        "estimated_queue": estimated_queue,
        "offset_error": offset_error,
        "network_error": network_error,
        "residual": residual,
        "actual_floor": actual_floor,
        "anchor_error": actual_floor - assumed_minimum_delay_ms,
        "anchor_satisfied": math.isclose(
            actual_floor, assumed_minimum_delay_ms, abs_tol=1e-9, rel_tol=0
        ),
        "max_network": max(network),
        "mean_queue": sum(queue) / sample_count,
        "mean_network": sum(network) / sample_count,
        "mean_observed": sum(observed) / sample_count,
    }


class P05ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P05")

    def test_permanent_manifest_identity_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 5)
        self.assertEqual(self.module["id"], "P05")
        self.assertEqual(self.module["title"], "Separate Clock Offset from Network Delay")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 2)
        self.assertEqual(self.module["phase_title"], "Time and synchronization")
        self.assertEqual(self.module["slug"], "separate-clock-offset-from-network-delay")
        self.assertEqual(self.module["prerequisites"], ["P04"])
        self.assertEqual(self.module["implementation_batch"], "P05")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p05_checks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary) / "repo"
            shutil.copytree(ROOT / "bin", fixture / "bin")
            shutil.copytree(ROOT / "curriculum", fixture / "curriculum")
            shutil.copytree(FOLDER, fixture / self.module["folder"])
            environment = os.environ.copy()
            environment["PYTHONDONTWRITEBYTECODE"] = "1"

            def run_cli(*arguments: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [str(fixture / "bin/learn"), *arguments],
                    cwd=fixture,
                    text=True,
                    capture_output=True,
                    env=environment,
                    timeout=10,
                )

            started = run_cli("start", "P05")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P05 — Separate Clock Offset from Network Delay", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P05')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P05")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P05 — Separate Clock Offset from Network Delay", continued.stdout)
            checked = run_cli("check", "P05")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P05')\n")

    def test_owned_text_artifacts_have_exactly_one_terminal_newline(self) -> None:
        for name in ARTIFACTS:
            with self.subTest(name=name):
                content = (FOLDER / name).read_bytes()
                self.assertEqual(content, content.rstrip(b"\r\n") + b"\n", name)
                self.assertTrue(content[:-1].splitlines()[-1].strip(), name)

    def test_relaunch_cleanup_preserves_unrelated_matlab_figures(self) -> None:
        experiment = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        experiment_lower = experiment.lower()
        experiment_compact = re.sub(r"\s+", "", experiment_lower).replace("...", "")
        self.assertNotIn("close all", experiment_lower)
        self.assertNotRegex(experiment_lower, r"(?m)^\s*clc\s*;")
        self.assertIn("experimentfiguretag='p05experimentfigure';", experiment_compact)
        self.assertIn(
            "existingfigures=findall(groot,'type','figure','tag',experimentfiguretag);",
            experiment_compact,
        )
        self.assertIn("close(existingfigures);", experiment_compact)
        self.assertEqual(experiment_lower.count("figure('name'"), 8)
        self.assertEqual(experiment_compact.count("'tag',experimentfiguretag"), 9)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        interactive_lower = interactive.lower()
        interactive_compact = re.sub(r"\s+", "", interactive_lower).replace("...", "")
        self.assertNotIn("close all", interactive_lower)
        self.assertIn("interactivefiguretag='p05interactivefigure';", interactive_compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            interactive_compact,
        )
        self.assertIn("close(existingwindows);", interactive_compact)
        self.assertEqual(interactive_compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_clock_delay()
        self.assertEqual(baseline["sample_index"], list(range(1, 9)))
        self.assertEqual(baseline["send"], list(range(0, 160, 20)))
        self.assertEqual(baseline["queue_shape"], list(QUEUE_SHAPE))
        self.assertEqual(baseline["queue"], [0, 2, 6, 4, 8, 2, 4, 0])
        self.assertEqual(baseline["network"], [3, 5, 9, 7, 11, 5, 7, 3])
        self.assertEqual(baseline["arrival"], [3, 25, 49, 67, 91, 105, 127, 143])
        self.assertEqual(baseline["receiver"], [10, 32, 56, 74, 98, 112, 134, 150])
        self.assertEqual(baseline["observed"], [10, 12, 16, 14, 18, 12, 14, 10])
        self.assertEqual(
            (
                baseline["observed_minimum"],
                baseline["observed_spread"],
                baseline["estimated_offset"],
            ),
            (10, 8, 7),
        )
        self.assertEqual(baseline["estimated_network"], baseline["network"])
        self.assertEqual(baseline["estimated_queue"], baseline["queue"])
        self.assertEqual(baseline["network_error"], [0] * 8)
        self.assertEqual(baseline["residual"], [0] * 8)
        self.assertTrue(baseline["anchor_satisfied"])
        self.assertEqual(
            (
                baseline["mean_queue"],
                baseline["mean_network"],
                baseline["mean_observed"],
            ),
            (3.25, 6.25, 13.25),
        )

        offset_cases = [
            reference_clock_delay(clock_offset_ms=value) for value in (-8, 0, 12)
        ]
        self.assertEqual(
            [case["observed_minimum"] for case in offset_cases], [-5, 3, 15]
        )
        self.assertEqual(
            [case["estimated_offset"] for case in offset_cases], [-8, 0, 12]
        )
        self.assertEqual([case["observed_spread"] for case in offset_cases], [8, 8, 8])
        self.assertTrue(
            all(case["estimated_network"] == baseline["network"] for case in offset_cases)
        )

        queue_cases = [
            reference_clock_delay(queue_peak_delay_ms=value) for value in (0, 4, 12)
        ]
        self.assertEqual([case["estimated_offset"] for case in queue_cases], [7, 7, 7])
        self.assertEqual([case["observed_spread"] for case in queue_cases], [0, 4, 12])
        self.assertEqual([case["max_network"] for case in queue_cases], [3, 7, 15])

        zero_offset = reference_clock_delay(clock_offset_ms=0)
        self.assertEqual(zero_offset["observed"], zero_offset["network"])
        negative_offset = reference_clock_delay(clock_offset_ms=-20)
        self.assertTrue(any(value < 0 for value in negative_offset["observed"]))
        self.assertTrue(all(value >= 0 for value in negative_offset["network"]))
        zero_queue = reference_clock_delay(queue_peak_delay_ms=0)
        self.assertEqual(zero_queue["network"], [3] * 8)
        self.assertEqual(zero_queue["observed"], [10] * 8)
        self.assertEqual(zero_queue["observed_spread"], 0)
        one_sample = reference_clock_delay(sample_count=1)
        self.assertEqual(
            (one_sample["queue"], one_sample["observed"], one_sample["estimated_offset"]),
            ([0], [10], 7),
        )

        bounded = reference_clock_delay(
            sample_count=64,
            clock_offset_ms=-1_000_000,
            propagation_delay_ms=1_000_000,
            queue_peak_delay_ms=1_000_000,
            hidden_common_delay_ms=0,
            assumed_minimum_delay_ms=1_000_000,
        )
        self.assertEqual(len(bounded["observed"]), 64)
        self.assertEqual(bounded["estimated_offset"], -1_000_000)
        self.assertTrue(all(math.isfinite(value) for value in bounded["observed"]))
        self.assertEqual(bounded["residual"], [0] * 64)

    def test_broken_common_delay_is_exactly_aliased_with_offset(self) -> None:
        broken = reference_clock_delay(hidden_common_delay_ms=5)
        aliased = reference_clock_delay(clock_offset_ms=12)
        self.assertEqual(broken["network"], [8, 10, 14, 12, 16, 10, 12, 8])
        self.assertEqual(broken["observed"], [15, 17, 21, 19, 23, 17, 19, 15])
        self.assertEqual(broken["observed"], aliased["observed"])
        self.assertNotEqual(broken["network"], aliased["network"])
        self.assertEqual(
            (broken["estimated_offset"], broken["offset_error"]), (12, 5)
        )
        self.assertEqual(broken["estimated_network"], [3, 5, 9, 7, 11, 5, 7, 3])
        self.assertEqual(broken["network_error"], [-5] * 8)
        self.assertEqual(broken["residual"], [0] * 8)
        self.assertFalse(broken["anchor_satisfied"])
        self.assertTrue(aliased["anchor_satisfied"])

        broken_many = reference_clock_delay(sample_count=64, hidden_common_delay_ms=5)
        alias_many = reference_clock_delay(sample_count=64, clock_offset_ms=12)
        self.assertEqual(broken_many["observed"], alias_many["observed"])
        self.assertEqual(broken_many["offset_error"], 5)

        miscalibrated = reference_clock_delay(assumed_minimum_delay_ms=4)
        self.assertEqual(
            (
                miscalibrated["estimated_offset"],
                miscalibrated["offset_error"],
                miscalibrated["network_error"],
            ),
            (6, -1, [1] * 8),
        )
        anchored_total_floor = reference_clock_delay(
            hidden_common_delay_ms=5, assumed_minimum_delay_ms=8
        )
        self.assertTrue(anchored_total_floor["anchor_satisfied"])
        self.assertEqual(anchored_total_floor["estimated_offset"], 7)
        self.assertEqual(
            anchored_total_floor["estimated_network"],
            anchored_total_floor["network"],
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "function out = model(sampleCount,clockOffsetMs,propagationDelayMs,"
            "queuePeakDelayMs,hiddenCommonDelayMs,assumedMinimumDelayMs)",
            source,
        )
        for formula in (
            "maxsamplecount=64;",
            "maxtimemagnitudems=1e6;",
            "sendperiodms=20;",
            "truesendtimems=(sampleindex-1)*sendperiodms;",
            "queuepatternindex=mod(sampleindex-1,numel(normalizedqueuepattern))+1;",
            "variablequeuedelayms=queuepeakdelayms*queueshape;",
            "truenetworkdelayms=propagationdelayms+hiddencommondelayms+variablequeuedelayms;",
            "receivertimestampms=truearrivaltimems+clockoffsetms;",
            "observedtimestampdifferencems=receivertimestampms-sendertimestampms;",
            "estimatedclockoffsetms=minimumobserveddifferencems-assumedminimumdelayms;",
            "estimatednetworkdelayms=observedtimestampdifferencems-estimatedclockoffsetms;",
            "clockoffseterrorms=estimatedclockoffsetms-clockoffsetms;",
            "networkdelayerrorms=estimatednetworkdelayms-truenetworkdelayms;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "samplecount=double(samplecount);",
            "clockoffsetms=double(clockoffsetms);",
            "propagationdelayms=double(propagationdelayms);",
            "queuepeakdelayms=double(queuepeakdelayms);",
            "hiddencommondelayms=double(hiddencommondelayms);",
            "assumedminimumdelayms=double(assumedminimumdelayms);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P05:InvalidSampleCount",
            "P05:InvalidClockOffset",
            "P05:InvalidPropagationDelay",
            "P05:InvalidQueuePeakDelay",
            "P05:InvalidHiddenCommonDelay",
            "P05:InvalidAssumedMinimumDelay",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.decompositionUniqueFromOneWayOnly = false;",
            "out.constantDelayAliasesWithClockOffset = true;",
            "out.truthAvailableForTeachingOnly = true;",
            "out.measurementNoiseModeled = false;",
            "out.clockSkewModeled = false;",
            "out.twoWayExchangeModeled = false;",
            "out.timeoutModeled = false;",
            "out.cancellationModeled = false;",
            "out.actualWaitPerformed = false;",
        ):
            self.assertIn(boundary, source)
        for opaque in (
            "figure(",
            "plot(",
            "uifigure",
            "uiaxes",
            "global ",
            "persistent",
            "while ",
            "timer(",
            "pause(",
            "fopen(",
            "system(",
            "webread",
            "tcpclient",
            "udpport",
            "rng(",
            "rand(",
            "randn(",
            "eval(",
        ):
            self.assertNotIn(opaque, code.lower())

    def test_experiment_and_interactive_expose_the_required_causal_views(self) -> None:
        experiment = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        lowered = experiment.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        for marker in (
            "deterministic baseline",
            "sweep 1",
            "sweep 2",
            "deliberately broken case",
            "mechanism:",
            "clockoffsetsms = [-8 0 12]",
            "queuepeaksms = [0 4 12]",
            "baseline = model(8,7,3,8,0,3)",
            "broken = model(8,7,3,8,5,3)",
            "aliased = model(8,12,3,8,0,3)",
            "simulation-only",
        ):
            self.assertIn(marker, lowered)
        for label in (
            "cross-clock timestamp difference (ms)",
            "one-way network delay (ms)",
            "true receiver-minus-sender clock offset (ms)",
            "peak additional queue delay (ms)",
            "paired sample index",
        ):
            self.assertIn(label, lowered)
        self.assertIn(
            "isequal(broken.observedtimestampdifferencems,aliased.observedtimestampdifferencems)",
            compact,
        )

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        interactive_lower = interactive.lower()
        interactive_compact = re.sub(r"\s+", "", interactive_lower).replace("...", "")
        self.assertIn("uifigure", interactive_lower)
        self.assertIn("clockmodel=@model;", interactive_compact)
        self.assertIn("reset baseline", interactive_lower)
        self.assertIn("valuechangedfcn", interactive_lower)
        self.assertIn("truth diagnostic: ambiguous false anchor", interactive_lower)
        for setting in (
            "'limits',[-2020],'value',baselineoffsetms",
            "'limits',[020],'value',baselinequeuepeakms",
            "'limits',[010],'value',baselinehiddencommonms",
            "'limits',[020],'value',baselineassumedminimumms",
        ):
            self.assertIn(setting, interactive_compact)
        for control in (
            "receiver - sender offset",
            "peak additional queue delay",
            "hidden common network delay",
            "assumed attainable delay floor",
        ):
            self.assertIn(control, interactive_lower)
        for reset in (
            "offsetcontrol.value=baselineoffsetms;",
            "queuecontrol.value=baselinequeuepeakms;",
            "hiddencontrol.value=baselinehiddencommonms;",
            "floorcontrol.value=baselineassumedminimumms;",
        ):
            self.assertIn(reset, interactive_compact)
        self.assertIn(
            "clockmodel(samplecount,offsetcontrol.value,propagationdelayms,"
            "queuecontrol.value,hiddencontrol.value,floorcontrol.value)",
            interactive_compact,
        )

    def test_tutor_text_checks_and_malformed_recovery_are_complete(self) -> None:
        tutor_names = ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8") for name in tutor_names
        )
        lowered = combined.lower()
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        for concept in (
            "p04",
            "queue waiting",
            "clock offset",
            "network delay",
            "receiver timestamp",
            "sender timestamp",
            "lower envelope",
            "external",
            "attainable",
            "hidden common",
            "alias",
            "negative",
            "reconstruction residual",
            "p06",
            "two-way exchange",
            "interpretation",
            "teach-back",
            "timeout",
            "cancellation",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        for marker in (
            "defaulted",
            "fractional",
            "expectedObservationMs",
            "clockOffsetsMs",
            "queuePeaksMs",
            "zeroOffset",
            "negativeOffset",
            "zeroQueue",
            "oneSample",
            "broken",
            "aliased",
            "miscalibrated",
            "hiddenButAnchored",
            "bounded",
            "brokenMany",
            "assertThrows",
            "recovered",
            "P05 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P05:InvalidSampleCount",
            "P05:InvalidClockOffset",
            "P05:InvalidPropagationDelay",
            "P05:InvalidQueuePeakDelay",
            "P05:InvalidHiddenCommonDelay",
            "P05:InvalidAssumedMinimumDelay",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
