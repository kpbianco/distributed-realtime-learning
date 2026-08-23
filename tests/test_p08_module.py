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
FOLDER = ROOT / "modules/08-distribute-a-time-triggered-schedule"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you distribute "
    "a Time-Triggered Schedule?"
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
CLOCK_SHAPE = (-1.0, 0.5, 1.0, -0.5)
VERSION_ONE_PHASE_US = (0.0, 250.0, 750.0, 500.0)
VERSION_TWO_PHASE_US = (0.0, 250.0, 500.0, 750.0)
BASE_DISTRIBUTION_US = (180.0, 420.0, 760.0, 1120.0)
VALIDATION_US = (80.0, 80.0, 120.0, 100.0)


def reference_schedule(
    clock_error_bound_us: float = 20,
    activation_lead_us: float = 1500,
    distribution_delay_scale: float = 1,
    all_or_nothing_activation: bool = True,
) -> dict[str, object]:
    """Independent four-node schedule arithmetic for retained static evidence."""
    clock_offset = [clock_error_bound_us * value for value in CLOCK_SHAPE]
    arrival_true = [
        distribution_delay_scale * value for value in BASE_DISTRIBUTION_US
    ]
    ready_true = [
        arrival + validation
        for arrival, validation in zip(arrival_true, VALIDATION_US)
    ]
    ready_local = [
        ready + offset for ready, offset in zip(ready_true, clock_offset)
    ]
    activation_true = [
        activation_lead_us - offset for offset in clock_offset
    ]
    activation_slack = [activation_lead_us - ready for ready in ready_local]
    ready_mask = [value <= activation_lead_us for value in ready_local]
    all_ready = all(ready_mask)
    if all_ready:
        active_version = [2, 2, 2, 2]
    elif all_or_nothing_activation:
        active_version = [1, 1, 1, 1]
    else:
        active_version = [2 if ready else 1 for ready in ready_mask]

    new_for_all = all(version == 2 for version in active_version)
    old_for_all = all(version == 1 for version in active_version)
    partial_new = any(version == 2 for version in active_version) and any(
        version == 1 for version in active_version
    )
    selection_withheld = not all_ready and all_or_nothing_activation

    selected_phase = [
        VERSION_TWO_PHASE_US[index]
        if active_version[index] == 2
        else VERSION_ONE_PHASE_US[index]
        for index in range(4)
    ]
    scheduled_local = [activation_lead_us + phase for phase in selected_phase]
    start_true = [
        scheduled - offset
        for scheduled, offset in zip(scheduled_local, clock_offset)
    ]
    start_relative = [
        phase - offset for phase, offset in zip(selected_phase, clock_offset)
    ]
    end_true = [start + 160 for start in start_true]
    start_error = [
        start - scheduled for start, scheduled in zip(start_true, scheduled_local)
    ]
    ordered = sorted(range(4), key=lambda index: start_relative[index])
    ordered_start = [start_true[index] for index in ordered]
    ordered_relative = [start_relative[index] for index in ordered]
    next_relative = ordered_relative[1:] + [ordered_relative[0] + 1000]
    separation = [
        following - (current + 160)
        for following, current in zip(next_relative, ordered_relative)
    ]
    overlap = [max(-value, 0.0) for value in separation]
    transition_collision = [value < 0 for value in separation]
    next_ordered = ordered[1:] + ordered[:1]
    transition_collision_from = [
        ordered[index] + 1
        for index, hit in enumerate(transition_collision)
        if hit
    ]
    transition_collision_to = [
        next_ordered[index] + 1
        for index, hit in enumerate(transition_collision)
        if hit
    ]
    collision_from: list[int] = []
    collision_to: list[int] = []
    collision_overlap: list[float] = []
    for first in range(3):
        for second in range(first + 1, 4):
            first_to_second = (start_relative[second] - start_relative[first]) % 1000
            second_to_first = (start_relative[first] - start_relative[second]) % 1000
            if first_to_second < 160:
                collision_from.append(first + 1)
                collision_to.append(second + 1)
                collision_overlap.append(160 - first_to_second)
            elif second_to_first < 160:
                collision_from.append(second + 1)
                collision_to.append(first + 1)
                collision_overlap.append(160 - second_to_first)
    coherent = len(set(active_version)) == 1
    guaranteed = 90 - 2 * clock_error_bound_us
    if new_for_all:
        state = "new-schedule-selected"
    elif selection_withheld:
        state = "old-schedule-retained"
    elif old_for_all:
        state = "old-schedule-selected"
    elif collision_from:
        state = "mixed-version-overlap"
    else:
        state = "mixed-version-no-overlap-in-fixture"
    return {
        "clock_offset": clock_offset,
        "maximum_pairwise_offset": max(clock_offset) - min(clock_offset),
        "arrival_true": arrival_true,
        "ready_true": ready_true,
        "ready_local": ready_local,
        "activation_true": activation_true,
        "activation_slack": activation_slack,
        "ready_mask": ready_mask,
        "ready_count": sum(ready_mask),
        "late_count": 4 - sum(ready_mask),
        "all_ready": all_ready,
        "required_lead": max(ready_local),
        "minimum_slack": min(activation_slack),
        "maximum_lateness": max(max(-value, 0.0) for value in activation_slack),
        "active_version": active_version,
        "new_for_all": new_for_all,
        "old_for_all": old_for_all,
        "partial_new": partial_new,
        "selection_withheld": selection_withheld,
        "selected_phase": selected_phase,
        "scheduled_local": scheduled_local,
        "start_true": start_true,
        "start_relative": start_relative,
        "end_true": end_true,
        "start_error": start_error,
        "ordered_nodes": [index + 1 for index in ordered],
        "next_ordered_nodes": [index + 1 for index in next_ordered],
        "ordered_start": ordered_start,
        "ordered_relative": ordered_relative,
        "separation": separation,
        "overlap": overlap,
        "transition_collision": transition_collision,
        "transition_collision_from": transition_collision_from,
        "transition_collision_to": transition_collision_to,
        "transition_collision_count": sum(transition_collision),
        "collision_from": collision_from,
        "collision_to": collision_to,
        "collision_overlap": collision_overlap,
        "collision_count": len(collision_from),
        "minimum_separation": min(separation),
        "maximum_overlap": max(collision_overlap, default=0.0),
        "total_pairwise_overlap": sum(collision_overlap),
        "total_overlap": sum(collision_overlap),
        "total_resource_overcommit": sum(overlap),
        "total_idle": sum(max(value, 0.0) for value in separation),
        "coherent": coherent,
        "guaranteed_separation": guaranteed,
        "bound_applicable": coherent,
        "bound_satisfied": coherent and min(separation) >= guaranteed,
        "state": state,
    }


class P08ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P08")

    def assert_float_lists_equal(
        self, actual: list[float], expected: list[float], tolerance: float = 1e-9
    ) -> None:
        self.assertEqual(len(actual), len(expected))
        for index, (left, right) in enumerate(zip(actual, expected)):
            with self.subTest(index=index):
                self.assertTrue(math.isclose(left, right, abs_tol=tolerance, rel_tol=0))

    def test_permanent_manifest_identity_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 8)
        self.assertEqual(self.module["id"], "P08")
        self.assertEqual(self.module["title"], "Distribute a Time-Triggered Schedule")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 2)
        self.assertEqual(self.module["phase_title"], "Time and synchronization")
        self.assertEqual(self.module["slug"], "distribute-a-time-triggered-schedule")
        self.assertEqual(self.module["prerequisites"], ["P07"])
        self.assertEqual(self.module["implementation_batch"], "P08")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p08_checks(self) -> None:
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

            started = run_cli("start", "P08")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P08 — Distribute a Time-Triggered Schedule", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P08')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P08")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P08 — Distribute a Time-Triggered Schedule", continued.stdout)
            checked = run_cli("check", "P08")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P08')\n")

    def test_lesson_entrypoint_runs_baseline_before_live_controls(self) -> None:
        lesson = (FOLDER / "lesson.m").read_text(encoding="utf-8")
        executable_lines = [
            line.strip().lower()
            for line in lesson.splitlines()
            if line.strip() and not line.lstrip().startswith("%")
        ]
        stage_calls = [
            line for line in executable_lines if line in {"experiment;", "interactive;"}
        ]
        self.assertEqual(stage_calls, ["experiment;", "interactive;"])

    def test_owned_text_artifacts_have_exactly_one_terminal_newline(self) -> None:
        for name in ARTIFACTS:
            with self.subTest(name=name):
                content = (FOLDER / name).read_bytes()
                self.assertEqual(content, content.rstrip(b"\r\n") + b"\n", name)
                self.assertTrue(content[:-1].splitlines()[-1].strip(), name)

    def test_relaunch_cleanup_preserves_unrelated_matlab_figures(self) -> None:
        experiment = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        lowered = experiment.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertNotIn("close all", lowered)
        self.assertNotRegex(lowered, r"(?m)^\s*clc\s*;")
        self.assertIn("experimentfiguretag='p08experimentfigure';", compact)
        self.assertIn(
            "existingfigures=findall(groot,'type','figure','tag',experimentfiguretag);",
            compact,
        )
        self.assertIn("close(existingfigures);", compact)
        self.assertEqual(lowered.count("figure('name'"), 8)
        self.assertEqual(compact.count("'tag',experimentfiguretag"), 9)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertNotIn("close all", lowered)
        self.assertIn("interactivefiguretag='p08interactivefigure';", compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            compact,
        )
        self.assertIn("close(existingwindows);", compact)
        self.assertEqual(compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_limits_and_broken_case(self) -> None:
        baseline = reference_schedule()
        self.assertEqual(baseline["clock_offset"], [-20, 10, 20, -10])
        self.assertEqual(baseline["maximum_pairwise_offset"], 40)
        self.assertEqual(baseline["arrival_true"], [180, 420, 760, 1120])
        self.assertEqual(baseline["ready_true"], [260, 500, 880, 1220])
        self.assertEqual(baseline["ready_local"], [240, 510, 900, 1210])
        self.assertEqual(baseline["activation_true"], [1520, 1490, 1480, 1510])
        self.assertEqual(baseline["activation_slack"], [1260, 990, 600, 290])
        self.assertEqual(baseline["ready_mask"], [True, True, True, True])
        self.assertEqual((baseline["ready_count"], baseline["late_count"]), (4, 0))
        self.assertEqual(baseline["required_lead"], 1210)
        self.assertTrue(baseline["new_for_all"])
        self.assertFalse(baseline["old_for_all"])
        self.assertFalse(baseline["selection_withheld"])
        self.assertEqual(baseline["active_version"], [2, 2, 2, 2])
        self.assertEqual(baseline["selected_phase"], [0, 250, 500, 750])
        self.assertEqual(baseline["start_true"], [1520, 1740, 1980, 2260])
        self.assertEqual(baseline["start_relative"], [20, 240, 480, 760])
        self.assertEqual(baseline["end_true"], [1680, 1900, 2140, 2420])
        self.assertEqual(baseline["start_error"], [20, -10, -20, 10])
        self.assertEqual(baseline["ordered_nodes"], [1, 2, 3, 4])
        self.assertEqual(baseline["separation"], [60, 80, 120, 100])
        self.assertEqual(baseline["minimum_separation"], 60)
        self.assertEqual(baseline["guaranteed_separation"], 50)
        self.assertEqual(baseline["total_idle"], 360)
        self.assertEqual(baseline["collision_count"], 0)
        self.assertEqual(baseline["state"], "new-schedule-selected")

        repeated = reference_schedule()
        self.assertEqual(repeated, baseline)
        shifted = reference_schedule(activation_lead_us=2000)
        self.assert_float_lists_equal(
            list(shifted["start_true"]),
            [value + 500 for value in baseline["start_true"]],
        )
        self.assertEqual(shifted["separation"], baseline["separation"])
        self.assertEqual(shifted["active_version"], baseline["active_version"])

        fractional = reference_schedule(2.5, 1500.5, 0.5, True)
        self.assertEqual(fractional["clock_offset"], [-2.5, 1.25, 2.5, -1.25])
        self.assertEqual(fractional["ready_true"], [170, 290, 500, 660])
        self.assertEqual(fractional["ready_local"], [167.5, 291.25, 502.5, 658.75])

        clock_cases = [reference_schedule(value) for value in (0, 20, 40)]
        self.assertEqual(
            [case["minimum_separation"] for case in clock_cases], [90, 60, 30]
        )
        self.assertEqual(
            [case["guaranteed_separation"] for case in clock_cases], [90, 50, 10]
        )
        self.assertEqual(
            [case["maximum_pairwise_offset"] for case in clock_cases], [0, 40, 80]
        )
        self.assertTrue(all(case["collision_count"] == 0 for case in clock_cases))

        guarantee_boundary = reference_schedule(45)
        touching = reference_schedule(60)
        just_overlapping = reference_schedule(60 + 1e-12)
        overlapping = reference_schedule(61)
        self.assertEqual(guarantee_boundary["guaranteed_separation"], 0)
        self.assertEqual(guarantee_boundary["minimum_separation"], 22.5)
        self.assertEqual((touching["minimum_separation"], touching["collision_count"]), (0, 0))
        self.assertLess(just_overlapping["minimum_separation"], 0)
        self.assertGreater(just_overlapping["maximum_overlap"], 0)
        self.assertEqual(just_overlapping["collision_count"], 1)
        translated_just_overlapping = reference_schedule(60 + 1e-12, 1_000_000)
        self.assertEqual(
            translated_just_overlapping["separation"],
            just_overlapping["separation"],
        )
        self.assertEqual(translated_just_overlapping["collision_count"], 1)
        self.assertEqual(overlapping["minimum_separation"], -1.5)
        self.assertEqual((overlapping["maximum_overlap"], overlapping["collision_count"]), (1.5, 1))
        coherent_but_overlapping = reference_schedule(100)
        self.assertTrue(coherent_but_overlapping["new_for_all"])
        self.assertTrue(coherent_but_overlapping["coherent"])
        self.assertEqual(
            coherent_but_overlapping["separation"], [-60, 40, 240, 140]
        )
        self.assertEqual(coherent_but_overlapping["collision_count"], 1)
        self.assertEqual(coherent_but_overlapping["state"], "new-schedule-selected")

        lead_cases = [
            reference_schedule(activation_lead_us=value) for value in (600, 1000, 1500)
        ]
        self.assertEqual([case["ready_count"] for case in lead_cases], [2, 3, 4])
        self.assertEqual(
            [case["minimum_slack"] for case in lead_cases], [-610, -210, 290]
        )
        self.assertEqual(
            [case["selection_withheld"] for case in lead_cases],
            [True, True, False],
        )
        self.assertEqual(
            [case["new_for_all"] for case in lead_cases], [False, False, True]
        )
        self.assertTrue(all(case["coherent"] for case in lead_cases))
        self.assertTrue(all(case["collision_count"] == 0 for case in lead_cases))

        exact = reference_schedule(activation_lead_us=1210)
        just_below = reference_schedule(activation_lead_us=1210 - 1e-12)
        below = reference_schedule(activation_lead_us=1209)
        self.assertTrue(exact["all_ready"])
        self.assertEqual(exact["minimum_slack"], 0)
        self.assertFalse(just_below["all_ready"])
        self.assertFalse(just_below["ready_mask"][3])
        self.assertLess(just_below["activation_slack"][3], 0)
        self.assertTrue(just_below["selection_withheld"])
        self.assertFalse(below["all_ready"])
        self.assertEqual((below["ready_count"], below["minimum_slack"]), (3, -1))

        zero_distribution = reference_schedule(
            activation_lead_us=140, distribution_delay_scale=0
        )
        self.assertEqual(zero_distribution["ready_true"], [80, 80, 120, 100])
        self.assertEqual(zero_distribution["ready_local"], [60, 90, 140, 90])
        self.assertTrue(zero_distribution["all_ready"])

        coherent_retain_old = reference_schedule(activation_lead_us=1000)
        broken = reference_schedule(
            activation_lead_us=1000, all_or_nothing_activation=False
        )
        self.assertEqual(coherent_retain_old["active_version"], [1, 1, 1, 1])
        self.assertEqual(coherent_retain_old["ordered_nodes"], [1, 2, 4, 3])
        self.assertEqual(coherent_retain_old["separation"], [60, 110, 60, 130])
        self.assertTrue(coherent_retain_old["selection_withheld"])
        self.assertTrue(coherent_retain_old["old_for_all"])
        self.assertEqual(broken["ready_mask"], [True, True, True, False])
        self.assertEqual(broken["active_version"], [2, 2, 2, 1])
        self.assertEqual(broken["selected_phase"], [0, 250, 500, 500])
        self.assertEqual(broken["start_true"], [1020, 1240, 1480, 1510])
        self.assertEqual(broken["separation"], [60, 80, -130, 350])
        self.assertEqual(broken["overlap"], [0, 0, 130, 0])
        self.assertEqual((broken["collision_from"], broken["collision_to"]), ([3], [4]))
        self.assertEqual((broken["maximum_overlap"], broken["collision_count"]), (130, 1))
        self.assertFalse(broken["coherent"])
        self.assertFalse(broken["bound_applicable"])
        self.assertEqual(broken["state"], "mixed-version-overlap")

        mixed_without_overlap = reference_schedule(
            activation_lead_us=600, all_or_nothing_activation=False
        )
        self.assertEqual(mixed_without_overlap["active_version"], [2, 2, 1, 1])
        self.assertTrue(mixed_without_overlap["partial_new"])
        self.assertFalse(mixed_without_overlap["coherent"])
        self.assertEqual(mixed_without_overlap["collision_count"], 0)
        self.assertEqual(
            mixed_without_overlap["state"], "mixed-version-no-overlap-in-fixture"
        )

        none_ready = reference_schedule(
            activation_lead_us=0, all_or_nothing_activation=False
        )
        self.assertEqual(none_ready["ready_count"], 0)
        self.assertEqual(none_ready["active_version"], [1, 1, 1, 1])
        self.assertFalse(none_ready["partial_new"])
        self.assertTrue(none_ready["old_for_all"])
        self.assertFalse(none_ready["selection_withheld"])

        bounded = reference_schedule(250, 1_000_000, 100, True)
        for key in ("clock_offset", "ready_local", "start_true", "end_true", "separation"):
            self.assertEqual(len(bounded[key]), 4)
            self.assertTrue(all(math.isfinite(value) for value in bounded[key]))

    def test_multiway_contention_reports_every_conflicting_pair(self) -> None:
        multiway = reference_schedule(250, 1_000_000, 100, True)
        self.assertEqual(multiway["active_version"], [2, 2, 2, 2])
        self.assertEqual(multiway["start_relative"], [250, 125, 250, 875])
        self.assertEqual(multiway["ordered_nodes"], [2, 1, 3, 4])
        self.assertEqual(multiway["separation"], [-35, -160, 465, 90])
        self.assertEqual(multiway["transition_collision_count"], 2)
        self.assertEqual(multiway["total_resource_overcommit"], 195)
        self.assertEqual(
            list(
                zip(
                    multiway["collision_from"],
                    multiway["collision_to"],
                    multiway["collision_overlap"],
                )
            ),
            [(2, 1, 35), (1, 3, 160), (2, 3, 35)],
        )
        self.assertEqual(multiway["collision_count"], 3)
        self.assertEqual(multiway["maximum_overlap"], 160)
        self.assertEqual(multiway["total_pairwise_overlap"], 230)

        model = (FOLDER / "model.m").read_text(encoding="utf-8")
        compact_model = re.sub(r"\s+", "", model).lower().replace("...", "")
        self.assertIn(
            "maxcollisionpaircount=actioncount*(actioncount-1)/2;",
            compact_model,
        )
        self.assertIn(
            "firsttosecondstartdeltaus=mod(actionstartrelativetoactivationus(secondnodeindex)-actionstartrelativetoactivationus(firstnodeindex),cycleperiodus);",
            compact_model,
        )
        self.assertIn(
            "totalresourceovercommitus=sum(overlapdurationtonextactionus);",
            compact_model,
        )
        self.assertNotRegex(
            model,
            r"(?m)^\s*collisionCount\s*=\s*sum\(collisionToNextAction\);\s*$",
        )

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertIn("multiwayOverlap", checks)
        self.assertIn("multiwayOverlap.collisionCount == 3", checks)
        self.assertIn("multiwayOverlap.totalPairwiseOverlapUs == 230", checks)

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(clockerrorboundus,activationleadus,"
            "distributiondelayscale,allornothingactivation)",
            compact,
        )
        for formula in (
            "nodecount=4;",
            "actioncount=4;",
            "scheduleversioncount=2;",
            "cycleperiodus=1000;",
            "actiondurationus=160;",
            "slotspacingus=250;",
            "nominalguardus=slotspacingus-actiondurationus;",
            "clockoffsetshape=[-10.51-0.5];",
            "clockoffsetus=clockerrorboundus*clockoffsetshape;",
            "versiononephaseus=[0250750500];",
            "versiontwophaseus=[0250500750];",
            "basedistributiondelayus=[1804207601120];",
            "schedulevalidationus=[8080120100];",
            "schedulereadylocaltimeus=schedulereadytruetimeus+clockoffsetus;",
            "nodeactivationtruetimeus=activationleadus-clockoffsetus;",
            "activationslackus=activationleadus-schedulereadylocaltimeus;",
            "nodereadyatactivation=schedulereadylocaltimeus<=activationleadus;",
            "activescheduleversion(nodereadyatactivation)=2;",
            "actionstarttruetimeus=scheduledactionlocaltimeus-clockoffsetus;",
            "actionstartrelativetoactivationus=selectedphaseus-clockoffsetus;",
            "[orderedactionstartrelativetoactivationus,orderednodeindex]=sort(actionstartrelativetoactivationus);",
            "nextorderedactionstartrelativetoactivationus=[orderedactionstartrelativetoactivationus(2:end),orderedactionstartrelativetoactivationus(1)+cycleperiodus];",
            "separationtonextactionus=nextorderedactionstartrelativetoactivationus-(orderedactionstartrelativetoactivationus+actiondurationus);",
            "transitioncollisioncount=sum(collisiontonextaction);",
            "totalresourceovercommitus=sum(overlapdurationtonextactionus);",
            "maxcollisionpaircount=actioncount*(actioncount-1)/2;",
            "firsttosecondstartdeltaus=mod(actionstartrelativetoactivationus(secondnodeindex)-actionstartrelativetoactivationus(firstnodeindex),cycleperiodus);",
            "totaloverlapus=totalpairwiseoverlapus;",
            "coherentguaranteedminseparationus=nominalguardus-2*clockerrorboundus;",
            "sharedresourcename='exclusivesharedchannel';",
            "maxderivedtimeus=1.2e6;",
        ):
            self.assertIn(formula, compact)
        self.assertIn(
            "collisiontonextaction=separationtonextactionus<0;", compact
        )
        self.assertNotIn("comparisontoleranceus", compact)
        for normalization in (
            "clockerrorboundus=double(clockerrorboundus);",
            "activationleadus=double(activationleadus);",
            "distributiondelayscale=double(distributiondelayscale);",
            "allornothingactivation=logical(allornothingactivation);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P08:InvalidClockErrorBound",
            "P08:InvalidActivationLead",
            "P08:InvalidDistributionScale",
            "P08:InvalidActivationPolicy",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.sharedActivationEpochRequired = true;",
            "out.scheduleVersionCoherenceRequired = true;",
            "out.clockErrorConsumesGuardBand = true;",
            "out.truthAvailableForTeachingOnly = true;",
            "out.activationWithholdDecisionModeled = true;",
            "out.rollbackDecisionModeled = false;",
            "out.actualRollbackPerformed = false;",
            "out.exclusiveSharedResourceRequired = true;",
            "out.nonpreemptiveResourceOccupancyModeled = true;",
            "out.readinessAcknowledgmentModeled = false;",
            "out.transactionalCommitProtocolModeled = false;",
            "out.clockRateErrorModeled = false;",
            "out.packetLossModeled = false;",
            "out.networkIoPerformed = false;",
            "out.physicalHardwareUsed = false;",
            "out.fullTsnProtocolModeled = false;",
            "out.fullTteProtocolModeled = false;",
            "out.timeoutModeled = false;",
            "out.cancellationModeled = false;",
            "out.actualWaitPerformed = false;",
            "out.transitionCollisionCount = transitionCollisionCount;",
            "out.collisionOverlapDurationUs = collisionOverlapDurationUs;",
            "out.totalPairwiseOverlapUs = totalPairwiseOverlapUs;",
            "out.totalResourceOvercommitUs = totalResourceOvercommitUs;",
            "out.maxCollisionPairCount = maxCollisionPairCount;",
            "out.calculationBounded = true;",
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
            "parfor",
        ):
            self.assertNotIn(opaque, code.lower())

    def test_experiment_and_interactive_expose_required_causal_views(self) -> None:
        experiment = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        lowered = experiment.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        for marker in (
            "deterministic baseline",
            "sweep 1",
            "sweep 2",
            "deliberately broken case",
            "mechanism:",
            "clockerrorboundsus = [0 20 40]",
            "activationleadsus = [600 1000 1500]",
            "baseline = model(20,1500,1,true)",
            "coherentretainold = model(20,1000,1,true)",
            "broken = model(20,1000,1,false)",
            "not an implemented",
        ):
            self.assertIn(marker, lowered)
        for label in (
            "true time relative to shared activation epoch (us)",
            "node-local time after publication (us)",
            "residual clock-error bound e (us)",
            "minimum cyclic action separation (us)",
            "shared activation lead after publication (us)",
            "nodes ready before activation (count)",
            "minimum readiness slack (us)",
            "active schedule version (integer)",
            "separation before next action (us)",
        ):
            self.assertIn(label, lowered)
        self.assertIn(
            "isequal(broken.separationtonextactionus,[6080-130350])", compact
        )

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertIn("uifigure", lowered)
        self.assertEqual(lowered.count("uispinner"), 3)
        self.assertIn("uicheckbox", lowered)
        self.assertIn("schedulemodel=@model;", compact)
        self.assertIn("reset baseline", lowered)
        self.assertGreaterEqual(lowered.count("valuechangedfcn"), 4)
        for setting in (
            "'limits',[0100],'value',baselineclockerrorboundus,'step',5",
            "'limits',[02500],'value',baselineactivationleadus,'step',50",
            "'limits',[02],'value',baselinedistributiondelayscale,'step',0.25",
            "'text','all-or-nothingversions','value',baselineallornothingactivation",
        ):
            self.assertIn(setting, compact)
        for reset in (
            "clockcontrol.value=baselineclockerrorboundus;",
            "leadcontrol.value=baselineactivationleadus;",
            "delaycontrol.value=baselinedistributiondelayscale;",
            "policycontrol.value=baselineallornothingactivation;",
        ):
            self.assertIn(reset, compact)
        self.assertIn(
            "schedulemodel(clockcontrol.value,leadcontrol.value,"
            "delaycontrol.value,policycontrol.value)",
            compact,
        )

    def test_tutor_text_checks_and_malformed_recovery_are_complete(self) -> None:
        tutor_names = ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8") for name in tutor_names
        )
        lowered = combined.lower()
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        for concept in (
            "p07",
            "c_i(t)",
            "node-local time minus coordinator time",
            "shared activation",
            "residual clock",
            "guard",
            "2e",
            "half-open",
            "cycle-wrap",
            "distribution",
            "validation",
            "readiness",
            "version coherence",
            "all-or-nothing",
            "mixed-version",
            "exclusive shared",
            "retain",
            "rollback",
            "timeout",
            "cancellation",
            "interpretation",
            "teach-back",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 35)
        for marker in (
            "baseline",
            "repeated",
            "shifted",
            "typed",
            "fractional",
            "clockErrorBoundsUs",
            "zeroClockError",
            "guaranteeBoundary",
            "touching",
            "justOverlappingClock",
            "overlappingClock",
            "coherentButOverlapping",
            "activationLeadsUs",
            "exactReadinessBoundary",
            "justBelowReadinessBoundary",
            "belowReadinessBoundary",
            "zeroDistributionDelay",
            "coherentRetainOld",
            "broken",
            "mixedWithoutOverlap",
            "recoveredActivation",
            "noneReadyPolicyDisabled",
            "bounded",
            "assertThrows",
            "recovered",
            "P08 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P08:InvalidClockErrorBound",
            "P08:InvalidActivationLead",
            "P08:InvalidDistributionScale",
            "P08:InvalidActivationPolicy",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
