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
FOLDER = ROOT / "modules/13-budget-an-end-to-end-deadline"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you budget "
    "an End-to-End Deadline?"
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


def reference_budget(
    queue_wait_ms: float = 12,
    coordination_wait_ms: float = 26,
    deadline_ms: float = 90,
    include_coordination_budget: bool = True,
) -> dict[str, object]:
    """Independent arithmetic oracle for P13's fixed five-stage path."""
    contributions = [8, queue_wait_ms, 10, coordination_wait_ms, 9]
    reference_budgets = [10, 16, 14, 32, 12]
    budgeted = [True, True, True, include_coordination_budget, True]
    assigned: list[float | None] = [
        value if owned else None
        for value, owned in zip(reference_budgets, budgeted)
    ]
    margins: list[float | None] = [
        budget - contribution if owned else None
        for contribution, budget, owned in zip(
            contributions, reference_budgets, budgeted
        )
    ]
    accounted = [
        contribution if owned else 0
        for contribution, owned in zip(contributions, budgeted)
    ]

    def cumulative(values: list[float]) -> list[float]:
        result: list[float] = [0]
        for value in values:
            result.append(result[-1] + value)
        return result

    full_total = sum(contributions)
    accounted_total = sum(accounted)
    assigned_total = sum(value for value in assigned if value is not None)
    margin_total = sum(value for value in margins if value is not None)
    deadline_slack = deadline_ms - full_total
    apparent_slack = deadline_ms - accounted_total
    allocation_reserve = deadline_ms - assigned_total
    coverage_complete = all(budgeted)
    owned_stages_fit = all(
        value is None or value >= 0 for value in margins
    )
    all_stage_budgets_met = coverage_complete and owned_stages_fit
    allocation_fits = assigned_total <= deadline_ms
    accounted_fits = accounted_total <= deadline_ms
    path_fits = full_total <= deadline_ms
    return {
        "contributions": contributions,
        "budgets": reference_budgets,
        "budgeted": budgeted,
        "assigned": assigned,
        "margins": margins,
        "accounted": accounted,
        "full_total": full_total,
        "accounted_total": accounted_total,
        "assigned_total": assigned_total,
        "unbudgeted": full_total - accounted_total,
        "cumulative_full": cumulative(contributions),
        "cumulative_accounted": cumulative(accounted),
        "cumulative_assigned": cumulative(
            [value if value is not None else 0 for value in assigned]
        ),
        "deadline_slack": deadline_slack,
        "deadline_miss": max(0, -deadline_slack),
        "apparent_slack": apparent_slack,
        "allocation_reserve": allocation_reserve,
        "margin_total": margin_total,
        "coverage_complete": coverage_complete,
        "owned_stages_fit": owned_stages_fit,
        "all_stage_budgets_met": all_stage_budgets_met,
        "allocation_fits": allocation_fits,
        "accounted_fits": accounted_fits,
        "path_fits": path_fits,
        "credible": coverage_complete and all_stage_budgets_met and allocation_fits,
        "false_confidence": (
            not coverage_complete and accounted_fits and not path_fits
        ),
        "local_breach_while_path_fits": (
            coverage_complete and not owned_stages_fit and path_fits
        ),
        "full_identity_residual": (
            deadline_slack - (allocation_reserve + margin_total)
        ),
        "accounted_identity_residual": (
            apparent_slack - (allocation_reserve + margin_total)
        ),
    }


class P13ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads(
            (ROOT / "curriculum/modules.json").read_text(encoding="utf-8")
        )
        cls.modules = manifest["modules"]
        cls.module = next(module for module in cls.modules if module["id"] == "P13")

    def test_permanent_manifest_identity_prerequisite_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 13)
        self.assertEqual(self.module["id"], "P13")
        self.assertEqual(self.module["title"], "Budget an End-to-End Deadline")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 4)
        self.assertEqual(self.module["phase_title"], "Real-time networking")
        self.assertEqual(self.module["slug"], "budget-an-end-to-end-deadline")
        self.assertEqual(self.module["prerequisites"], ["P12"])
        self.assertEqual(self.module["implementation_batch"], "P13")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        positions = {module["id"]: index for index, module in enumerate(self.modules)}
        prerequisite = next(module for module in self.modules if module["id"] == "P12")
        self.assertLess(positions["P12"], positions["P13"])
        self.assertEqual(prerequisite["status"], "implemented")
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p13_checks(self) -> None:
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

            started = run_cli("start", "P13")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P13 — Budget an End-to-End Deadline", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P13')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P13")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P13 — Budget an End-to-End Deadline", continued.stdout)
            checked = run_cli("check", "P13")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(
                checked.stdout, "Run in MATLAB: run_module_checks('P13')\n"
            )

    def test_lesson_entrypoint_and_owned_text_boundaries(self) -> None:
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
        self.assertIn("experimentfiguretag='p13experimentfigure';", compact)
        self.assertIn(
            "existingfigures=findall(groot,'type','figure','tag',"
            "experimentfiguretag);",
            compact,
        )
        self.assertIn("close(existingfigures);", compact)
        self.assertEqual(lowered.count("figure('name'"), 5)
        self.assertEqual(compact.count("'tag',experimentfiguretag"), 6)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertNotIn("close all", lowered)
        self.assertIn("interactivefiguretag='p13interactivefigure';", compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',"
            "interactivefiguretag);",
            compact,
        )
        self.assertIn("close(existingwindows);", compact)
        self.assertEqual(compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_budget()
        self.assertEqual(baseline["contributions"], [8, 12, 10, 26, 9])
        self.assertEqual(baseline["budgets"], [10, 16, 14, 32, 12])
        self.assertEqual(baseline["margins"], [2, 4, 4, 6, 3])
        self.assertEqual(baseline["full_total"], 65)
        self.assertEqual(baseline["assigned_total"], 84)
        self.assertEqual(baseline["deadline_slack"], 25)
        self.assertEqual(baseline["allocation_reserve"], 6)
        self.assertEqual(baseline["margin_total"], 19)
        self.assertEqual(baseline["cumulative_full"], [0, 8, 20, 30, 56, 65])
        self.assertEqual(
            baseline["cumulative_assigned"], [0, 10, 26, 40, 72, 84]
        )
        self.assertTrue(baseline["coverage_complete"])
        self.assertTrue(baseline["owned_stages_fit"])
        self.assertTrue(baseline["all_stage_budgets_met"])
        self.assertTrue(baseline["allocation_fits"])
        self.assertTrue(baseline["path_fits"])
        self.assertTrue(baseline["credible"])
        self.assertEqual(baseline["full_identity_residual"], 0)
        self.assertEqual(reference_budget(), baseline)

        queue_cases = [
            reference_budget(queue_wait_ms=value) for value in (0, 6, 12, 24)
        ]
        self.assertEqual(
            [case["full_total"] for case in queue_cases], [53, 59, 65, 77]
        )
        self.assertEqual(
            [case["deadline_slack"] for case in queue_cases], [37, 31, 25, 13]
        )
        self.assertEqual(
            [case["margins"][1] for case in queue_cases], [16, 10, 4, -8]
        )
        self.assertEqual(
            [case["all_stage_budgets_met"] for case in queue_cases],
            [True, True, True, False],
        )
        self.assertTrue(all(case["path_fits"] for case in queue_cases))

        deadline_cases = [
            reference_budget(deadline_ms=value) for value in (60, 65, 84, 90)
        ]
        self.assertEqual(
            [case["full_total"] for case in deadline_cases], [65, 65, 65, 65]
        )
        self.assertEqual(
            [case["deadline_slack"] for case in deadline_cases], [-5, 0, 19, 25]
        )
        self.assertEqual(
            [case["allocation_reserve"] for case in deadline_cases],
            [-24, -19, 0, 6],
        )
        self.assertEqual(
            [case["path_fits"] for case in deadline_cases],
            [False, True, True, True],
        )
        self.assertEqual(
            [case["allocation_fits"] for case in deadline_cases],
            [False, False, True, True],
        )

        zero_waits = reference_budget(
            queue_wait_ms=0, coordination_wait_ms=0, deadline_ms=27
        )
        self.assertEqual(zero_waits["contributions"], [8, 0, 10, 0, 9])
        self.assertEqual(zero_waits["full_total"], 27)
        self.assertEqual(zero_waits["deadline_slack"], 0)
        self.assertTrue(zero_waits["path_fits"])

        bounded = reference_budget(
            queue_wait_ms=1000,
            coordination_wait_ms=1000,
            deadline_ms=1_000_000,
        )
        self.assertEqual(bounded["contributions"], [8, 1000, 10, 1000, 9])
        self.assertEqual(bounded["full_total"], 2027)
        self.assertTrue(bounded["path_fits"])
        self.assertTrue(bounded["local_breach_while_path_fits"])

    def test_broken_deadline_lifecycle_recovery_and_isolation_oracle(self) -> None:
        broken = reference_budget(
            deadline_ms=60, include_coordination_budget=False
        )
        self.assertEqual(broken["budgeted"], [True, True, True, False, True])
        self.assertEqual(broken["assigned"], [10, 16, 14, None, 12])
        self.assertEqual(broken["margins"], [2, 4, 4, None, 3])
        self.assertEqual(broken["accounted"], [8, 12, 10, 0, 9])
        self.assertEqual(broken["accounted_total"], 39)
        self.assertEqual(broken["full_total"], 65)
        self.assertEqual(broken["assigned_total"], 52)
        self.assertEqual(broken["unbudgeted"], 26)
        self.assertEqual(broken["apparent_slack"], 21)
        self.assertEqual(broken["deadline_slack"], -5)
        self.assertEqual(broken["deadline_miss"], 5)
        self.assertFalse(broken["coverage_complete"])
        self.assertTrue(broken["owned_stages_fit"])
        self.assertTrue(broken["allocation_fits"])
        self.assertTrue(broken["accounted_fits"])
        self.assertFalse(broken["path_fits"])
        self.assertFalse(broken["credible"])
        self.assertTrue(broken["false_confidence"])
        self.assertEqual(broken["full_identity_residual"], -26)
        self.assertEqual(broken["accounted_identity_residual"], 0)

        local_breach = reference_budget(queue_wait_ms=24)
        self.assertEqual(local_breach["margins"][1], -8)
        self.assertTrue(local_breach["path_fits"])
        self.assertFalse(local_breach["all_stage_budgets_met"])
        self.assertTrue(local_breach["local_breach_while_path_fits"])

        restored = reference_budget()
        self.assertEqual(restored, reference_budget())
        self.assertTrue(restored["credible"])

    def test_zero_contribution_omitted_stage_still_fails_coverage(self) -> None:
        unowned = reference_budget(
            coordination_wait_ms=0, include_coordination_budget=False
        )
        owned = reference_budget(
            coordination_wait_ms=0, include_coordination_budget=True
        )

        self.assertEqual(unowned["full_total"], 39)
        self.assertEqual(unowned["accounted_total"], 39)
        self.assertEqual(unowned["unbudgeted"], 0)
        self.assertEqual(unowned["deadline_slack"], 51)
        self.assertEqual(unowned["apparent_slack"], 51)
        self.assertEqual(unowned["full_identity_residual"], 0)
        self.assertEqual(unowned["accounted_identity_residual"], 0)
        self.assertFalse(unowned["coverage_complete"])
        self.assertTrue(unowned["owned_stages_fit"])
        self.assertFalse(unowned["all_stage_budgets_met"])
        self.assertTrue(unowned["allocation_fits"])
        self.assertTrue(unowned["accounted_fits"])
        self.assertTrue(unowned["path_fits"])
        self.assertFalse(unowned["credible"])
        self.assertFalse(unowned["false_confidence"])

        self.assertTrue(owned["coverage_complete"])
        self.assertTrue(owned["credible"])
        self.assertEqual(owned["full_total"], unowned["full_total"])
        self.assertEqual(owned["deadline_slack"], unowned["deadline_slack"])

        model_source = (FOLDER / "model.m").read_text(encoding="utf-8")
        model_compact = re.sub(r"\s+", "", model_source).lower().replace(
            "...", ""
        )
        self.assertIn(
            "budgetcoveragecomplete=all(budgetedstagemask);", model_compact
        )
        self.assertIn(
            "budgetplancredible=budgetcoveragecomplete&&allstagebudgetsmet"
            "&&allocationfitsdeadline;",
            model_compact,
        )

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        checks_compact = re.sub(r"\s+", "", checks).lower().replace("...", "")
        self.assertIn(
            "zerocontributionunowned=model(12,0,90,false);", checks_compact
        )
        self.assertIn(
            "~zerocontributionunowned.budgetcoveragecomplete", checks_compact
        )
        self.assertIn(
            "~zerocontributionunowned.budgetplancredible", checks_compact
        )

    def test_exact_deadline_and_stage_allocation_boundaries(self) -> None:
        exact_deadline = reference_budget(deadline_ms=65)
        just_before_deadline = reference_budget(deadline_ms=65 - 1e-12)
        self.assertEqual(exact_deadline["deadline_slack"], 0)
        self.assertTrue(exact_deadline["path_fits"])
        self.assertLess(just_before_deadline["deadline_slack"], 0)
        self.assertFalse(just_before_deadline["path_fits"])

        exact_queue = reference_budget(queue_wait_ms=16)
        just_over_queue = reference_budget(queue_wait_ms=16 + 1e-12)
        self.assertEqual(exact_queue["margins"][1], 0)
        self.assertTrue(exact_queue["all_stage_budgets_met"])
        self.assertLess(just_over_queue["margins"][1], 0)
        self.assertFalse(just_over_queue["all_stage_budgets_met"])
        self.assertTrue(just_over_queue["path_fits"])

        model_source = (FOLDER / "model.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", model_source).lower().replace("...", "")
        self.assertIn(
            "endtoendboundmeetsdeadline=fullpathcontributionms<=deadlinems;",
            compact,
        )
        self.assertIn(
            "allownedstageswithinbudget=all(stagebudgetmarginms(budgetedstagemask)>=0);",
            compact,
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(queuewaitms,coordinationwaitms,deadlinems,"
            "includecoordinationbudget)",
            compact,
        )
        for formula in (
            "stagecount=5;",
            "maxcumulativepointcount=stagecount+1;",
            "maxtotalcontributionms=2027;",
            "stagecontributionms=[8queuewaitms10coordinationwaitms9];",
            "referencestagebudgetms=[1016143212];",
            "budgetedstagemask=[truetruetrueincludecoordinationbudgettrue];",
            "fullpathcontributionms=sum(stagecontributionms);",
            "accountedpathcontributionms=sum(accountedstagecontributionms);",
            "deadlineSlackMs=deadlineMs-fullPathContributionMs;".lower(),
            "allocationreservems=deadlinems-assignedbudgettotalms;",
            "falseconfidencesymptom=~budgetcoveragecomplete&&accountedpathfitsdeadline"
            "&&~endtoendboundmeetsdeadline;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "queuewaitms=double(queuewaitms);",
            "coordinationwaitms=double(coordinationwaitms);",
            "deadlinems=double(deadlinems);",
            "includecoordinationbudget=logical(includecoordinationbudget);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P13:InvalidQueueWait",
            "P13:InvalidCoordinationWait",
            "P13:InvalidDeadline",
            "P13:InvalidBudgetCoverage",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.deadlineTiePasses = true;",
            "out.deadlineOnlyClassifies = true;",
            "out.deadlineMissMeansGuaranteeFailureOnly = true;",
            "out.timeoutModeled = false;",
            "out.actualWallClockWaitPerformed = false;",
            "out.cancellationModeled = false;",
            "out.actualAsynchronousCancellationPerformed = false;",
            "out.rollbackModeled = false;",
            "out.actualRollbackPerformed = false;",
            "out.stageContributionsRetainedAfterClassification = true;",
            "out.recoveryModeled = false;",
            "out.retryModeled = false;",
            "out.consensusProtocolModeled = false;",
            "out.queueSimulationModeled = false;",
            "out.periodicSchedulingModeled = false;",
            "out.qualityOfServiceModeled = false;",
            "out.admissionControlPolicyModeled = false;",
            "out.networkIoPerformed = false;",
            "out.storageIoPerformed = false;",
            "out.randomnessUsed = false;",
            "out.backgroundWorkStarted = false;",
            "out.physicalHardwareUsed = false;",
            "out.measuredTimingEvidence = false;",
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
            "mechanism",
            "queuewaitvaluesms = [0 6 12 24]",
            "deadlinevaluesms = [60 65 84 90]",
            "baseline = model(12,26,90,true)",
            "broken = model(12,26,60,false)",
            "a deadline budget is credible even if one causal stage is omitted",
        ):
            self.assertIn(marker, lowered)
        self.assertIn(
            "current=model(queuewaitvaluesms(caseindex),26,90,true);", compact
        )
        self.assertIn(
            "current=model(12,26,deadlinevaluesms(caseindex),true);", compact
        )
        for label in (
            "ordered end-to-end stage (identifier)",
            "declared contribution or allocation (ms)",
            "completed stage boundary (count)",
            "cumulative time (ms)",
            "queue/admission wait (ms)",
            "complete path contribution (ms)",
            "end-to-end deadline slack (ms)",
            "queue-stage allocation margin (ms)",
            "end-to-end deadline (ms)",
            "unassigned allocation reserve (ms)",
            "stage represented (0 or 1)",
        ):
            self.assertIn(label, lowered)
        self.assertGreaterEqual(compact.count("subplot(3,1,"), 6)
        self.assertIn("broken.falseconfidencesymptom", compact)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertIn("uifigure", lowered)
        self.assertEqual(lowered.count("uispinner"), 3)
        self.assertEqual(lowered.count("uicheckbox"), 1)
        self.assertIn("budgetmodel=@model;", compact)
        self.assertIn("reset baseline", lowered)
        self.assertGreaterEqual(lowered.count("valuechangedfcn"), 4)
        for setting in (
            "'limits',[040],'value',baselinequeuewaitms,'step',2",
            "'limits',[060],'value',baselinecoordinationwaitms,'step',2",
            "'limits',[0120],'value',baselinedeadlinems,'step',5",
            "'text','includecoordinationstage','value',"
            "baselineincludecoordinationbudget",
        ):
            self.assertIn(setting, compact)
        for reset in (
            "queuecontrol.value=baselinequeuewaitms;",
            "coordinationcontrol.value=baselinecoordinationwaitms;",
            "deadlinecontrol.value=baselinedeadlinems;",
            "coveragecontrol.value=baselineincludecoordinationbudget;",
        ):
            self.assertIn(reset, compact)
        self.assertIn(
            "budgetmodel(queuecontrol.value,coordinationcontrol.value,"
            "deadlinecontrol.value,coveragecontrol.value)",
            compact,
        )
        self.assertIn("full/apparentslack%.1f/%.1fms", compact)
        self.assertIn("deadlineisaclassification,notarunningtimeout", compact)

    def test_tutor_text_checks_and_malformed_recovery_are_complete(self) -> None:
        tutor_names = ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8") for name in tutor_names
        )
        lowered = combined.lower()
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        for concept in (
            "p12",
            "p11",
            "p04",
            "complete path",
            "stage",
            "queue",
            "coordination",
            "allocation",
            "reserve",
            "slack",
            "deadline",
            "coverage",
            "false-confidence",
            "timeout",
            "cancellation",
            "rollback",
            "recovery",
            "interpretation",
            "teach-back",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for boundary in (
            "analytical guarantee failure",
            "not a wall-clock timeout",
            "stateless reevaluation",
            "synthetic declared inputs",
        ):
            self.assertIn(boundary, lowered)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 150)
        for marker in (
            "baseline",
            "repeated",
            "defaults",
            "typed",
            "fractional",
            "queueWaitValuesMs",
            "deadlineValuesMs",
            "broken",
            "completeTight",
            "zeroWaits",
            "exactDeadline",
            "justBeforeDeadline",
            "exactQueueAllocation",
            "justOverQueueAllocation",
            "zeroDeadline",
            "recoveryAfterMiss",
            "bounded",
            "assertThrows",
            "recoveredAfterMalformed",
            "P13 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P13:InvalidQueueWait",
            "P13:InvalidCoordinationWait",
            "P13:InvalidDeadline",
            "P13:InvalidBudgetCoverage",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
