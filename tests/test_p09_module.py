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
FOLDER = ROOT / "modules/09-replicate-shared-state"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you replicate "
    "Shared State?"
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
BASE_PROPAGATION_MS = (0.0, 10.0, 30.0, 70.0)
APPLY_COST_MS = (0.0, 5.0, 5.0, 5.0)


def reference_replication(
    propagation_delay_scale: float = 1,
    required_ack_count: int = 4,
    read_after_response_ms: float = 0,
    slow_replica_available: bool = True,
    ack_timeout_ms: float = 160,
) -> dict[str, object]:
    """Independent arithmetic for the fixed single-writer replication fixture."""
    available = [True, True, True, slow_replica_available]
    nominal_apply = [
        propagation_delay_scale * delay + cost
        for delay, cost in zip(BASE_PROPAGATION_MS, APPLY_COST_MS)
    ]
    effective_apply = [
        value if online else math.inf
        for value, online in zip(nominal_apply, available)
    ]
    ack_return_delay = [0.0, 0.0, 0.0, 0.0]
    ack_observation = [
        apply_time + return_delay
        for apply_time, return_delay in zip(effective_apply, ack_return_delay)
    ]
    ordered_ack = sorted(ack_observation)
    required_arrival = ordered_ack[required_ack_count - 1]
    reachable = math.isfinite(required_arrival)
    acknowledged = reachable and required_arrival <= ack_timeout_ms
    response_time = required_arrival if acknowledged else ack_timeout_ms
    current_at_response = [
        online and apply_time <= response_time
        for online, apply_time in zip(available, nominal_apply)
    ]
    version_at_response = [1 if current else 0 for current in current_at_response]
    value_at_response = [65 if current else 40 for current in current_at_response]
    read_time = response_time + read_after_response_ms
    current_at_read = [
        online and apply_time <= read_time
        for online, apply_time in zip(available, nominal_apply)
    ]
    version_at_read: list[int | None] = [
        (1 if current else 0) if online else None
        for current, online in zip(current_at_read, available)
    ]
    read_succeeded = available[3]
    read_version = version_at_read[3] if read_succeeded else None
    read_value = (65 if read_version == 1 else 40) if read_succeeded else None
    stale_read = read_succeeded and read_version == 0
    current_count_response = sum(current_at_response)
    all_available_current = all(
        current
        for current, online in zip(current_at_response, available)
        if online
    )
    if all(available):
        converged = True
        convergence_time: float | None = max(nominal_apply)
        all_lag_exposure: float | None = sum(nominal_apply)
    else:
        converged = False
        convergence_time = None
        all_lag_exposure = None
    available_times = [
        value for value, online in zip(nominal_apply, available) if online
    ]
    if acknowledged and not read_succeeded:
        outcome = "acknowledged-read-unavailable"
    elif acknowledged and stale_read:
        outcome = "acknowledged-stale-read"
    elif acknowledged:
        outcome = "acknowledged-current-read"
    elif not read_succeeded:
        outcome = "timeout-read-unavailable"
    elif stale_read:
        outcome = "timeout-stale-read"
    else:
        outcome = "timeout-current-read"
    return {
        "available": available,
        "available_count": sum(available),
        "nominal_apply": nominal_apply,
        "effective_apply": effective_apply,
        "ack_return_delay": ack_return_delay,
        "ack_observation": ack_observation,
        "ordered_ack": ordered_ack,
        "required_arrival": required_arrival,
        "reachable": reachable,
        "acknowledged": acknowledged,
        "timed_out": not acknowledged,
        "response_time": response_time,
        "ack_latency": required_arrival if acknowledged else None,
        "timeout_latency": None if acknowledged else ack_timeout_ms,
        "current_at_response": current_at_response,
        "version_at_response": version_at_response,
        "value_at_response": value_at_response,
        "current_count_response": current_count_response,
        "all_current_response": all(current_at_response),
        "all_available_current": all_available_current,
        "partial_apply": 0 < current_count_response < 4,
        "may_have_applied_on_timeout": not acknowledged
        and current_count_response > 0,
        "read_time": read_time,
        "current_at_read": current_at_read,
        "version_at_read": version_at_read,
        "current_count_read": sum(current_at_read),
        "read_succeeded": read_succeeded,
        "read_version": read_version,
        "read_value": read_value,
        "stale_read": stale_read,
        "read_your_write_applicable": acknowledged and read_succeeded,
        "read_your_write_satisfied": acknowledged
        and read_succeeded
        and read_version == 1,
        "converged": converged,
        "convergence_time": convergence_time,
        "available_convergence_time": max(available_times),
        "all_lag_exposure": all_lag_exposure,
        "online_lag_exposure": sum(available_times),
        "required_but_unavailable": max(required_ack_count - sum(available), 0),
        "outcome": outcome,
    }


class P09ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads(
            (ROOT / "curriculum/modules.json").read_text(encoding="utf-8")
        )
        cls.modules = manifest["modules"]
        cls.module = next(module for module in cls.modules if module["id"] == "P09")

    def assert_float_lists_equal(
        self,
        actual: list[float],
        expected: list[float],
        tolerance: float = 1e-9,
    ) -> None:
        self.assertEqual(len(actual), len(expected))
        for index, (left, right) in enumerate(zip(actual, expected)):
            with self.subTest(index=index):
                self.assertTrue(
                    math.isclose(left, right, abs_tol=tolerance, rel_tol=0),
                    (left, right),
                )

    def test_permanent_manifest_identity_prerequisite_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 9)
        self.assertEqual(self.module["id"], "P09")
        self.assertEqual(self.module["title"], "Replicate Shared State")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 3)
        self.assertEqual(self.module["phase_title"], "Coordination and flow")
        self.assertEqual(self.module["slug"], "replicate-shared-state")
        self.assertEqual(self.module["prerequisites"], ["P08"])
        self.assertEqual(self.module["implementation_batch"], "P09")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        positions = {module["id"]: index for index, module in enumerate(self.modules)}
        prerequisite = next(module for module in self.modules if module["id"] == "P08")
        self.assertLess(positions["P08"], positions["P09"])
        self.assertEqual(prerequisite["status"], "implemented")
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p09_checks(self) -> None:
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

            started = run_cli("start", "P09")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P09 — Replicate Shared State", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P09')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P09")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P09 — Replicate Shared State", continued.stdout)
            checked = run_cli("check", "P09")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P09')\n")

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
        self.assertIn("experimentfiguretag='p09experimentfigure';", compact)
        self.assertIn(
            "existingfigures=findall(groot,'type','figure','tag',experimentfiguretag);",
            compact,
        )
        self.assertIn("close(existingfigures);", compact)
        self.assertEqual(lowered.count("figure('name'"), 5)
        self.assertEqual(compact.count("'tag',experimentfiguretag"), 6)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertNotIn("close all", lowered)
        self.assertIn("interactivefiguretag='p09interactivefigure';", compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            compact,
        )
        self.assertIn("close(existingwindows);", compact)
        self.assertEqual(compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_replication()
        self.assertEqual(baseline["available"], [True, True, True, True])
        self.assertEqual(baseline["nominal_apply"], [0, 15, 35, 75])
        self.assertEqual(baseline["effective_apply"], [0, 15, 35, 75])
        self.assertEqual(baseline["ack_return_delay"], [0, 0, 0, 0])
        self.assertEqual(baseline["ack_observation"], [0, 15, 35, 75])
        self.assertEqual(baseline["ordered_ack"], [0, 15, 35, 75])
        self.assertEqual(baseline["required_arrival"], 75)
        self.assertTrue(baseline["acknowledged"])
        self.assertFalse(baseline["timed_out"])
        self.assertEqual(baseline["response_time"], 75)
        self.assertEqual(baseline["version_at_response"], [1, 1, 1, 1])
        self.assertEqual(baseline["value_at_response"], [65, 65, 65, 65])
        self.assertEqual(baseline["current_count_response"], 4)
        self.assertTrue(baseline["all_current_response"])
        self.assertEqual(baseline["read_time"], 75)
        self.assertTrue(baseline["read_succeeded"])
        self.assertEqual((baseline["read_version"], baseline["read_value"]), (1, 65))
        self.assertFalse(baseline["stale_read"])
        self.assertTrue(baseline["read_your_write_satisfied"])
        self.assertEqual(baseline["convergence_time"], 75)
        self.assertEqual(baseline["all_lag_exposure"], 125)
        self.assertEqual(baseline["outcome"], "acknowledged-current-read")
        self.assertEqual(reference_replication(), baseline)

        fractional = reference_replication(0.5, 2, 2.5, True, 40.5)
        self.assertEqual(fractional["nominal_apply"], [0, 10, 20, 40])
        self.assertEqual(fractional["response_time"], 10)
        self.assertEqual(fractional["read_time"], 12.5)
        self.assertEqual(fractional["read_version"], 0)

        delay_cases = [reference_replication(scale) for scale in (0.5, 1, 2)]
        self.assertEqual(
            [case["nominal_apply"] for case in delay_cases],
            [[0, 10, 20, 40], [0, 15, 35, 75], [0, 25, 65, 145]],
        )
        self.assertEqual(
            [case["convergence_time"] for case in delay_cases], [40, 75, 145]
        )
        self.assertEqual(
            [case["all_lag_exposure"] for case in delay_cases], [70, 125, 235]
        )

        ack_cases = [
            reference_replication(required_ack_count=count) for count in (1, 2, 4)
        ]
        self.assertEqual([case["response_time"] for case in ack_cases], [0, 15, 75])
        self.assertEqual(
            [case["current_count_response"] for case in ack_cases], [1, 2, 4]
        )
        self.assertEqual([case["read_version"] for case in ack_cases], [0, 0, 1])

        zero_propagation = reference_replication(0)
        self.assertEqual(zero_propagation["nominal_apply"], [0, 5, 5, 5])
        self.assertEqual(zero_propagation["convergence_time"], 5)
        self.assertEqual(zero_propagation["all_lag_exposure"], 15)

        exact_timeout = reference_replication(ack_timeout_ms=75)
        just_before_timeout = reference_replication(ack_timeout_ms=75 - 1e-12)
        self.assertTrue(exact_timeout["acknowledged"])
        self.assertTrue(just_before_timeout["timed_out"])
        self.assertEqual(just_before_timeout["current_count_response"], 3)

        just_before_read = reference_replication(
            required_ack_count=1, read_after_response_ms=75 - 1e-12
        )
        exact_read = reference_replication(required_ack_count=1, read_after_response_ms=75)
        self.assertEqual(just_before_read["read_version"], 0)
        self.assertEqual(exact_read["read_version"], 1)

        bounded = reference_replication(20, 4, 1_000_000, True, 1_000_000)
        self.assertEqual(bounded["nominal_apply"], [0, 205, 605, 1405])
        self.assertEqual(bounded["response_time"], 1405)
        self.assertEqual(bounded["read_time"], 1_001_405)
        self.assertTrue(all(math.isfinite(value) for value in bounded["nominal_apply"]))

    def test_broken_timeout_rollback_recovery_and_isolation_oracle(self) -> None:
        broken = reference_replication(required_ack_count=1)
        self.assertTrue(broken["acknowledged"])
        self.assertEqual(broken["response_time"], 0)
        self.assertEqual(broken["version_at_response"], [1, 0, 0, 0])
        self.assertTrue(broken["read_succeeded"])
        self.assertEqual((broken["read_version"], broken["read_value"]), (0, 40))
        self.assertTrue(broken["stale_read"])
        self.assertFalse(broken["read_your_write_satisfied"])
        self.assertEqual(broken["outcome"], "acknowledged-stale-read")

        safe_wait = reference_replication(required_ack_count=1, read_after_response_ms=75)
        all_ack = reference_replication(required_ack_count=4)
        self.assertEqual(safe_wait["read_version"], 1)
        self.assertTrue(all_ack["all_current_response"])

        offline = reference_replication(
            required_ack_count=4,
            slow_replica_available=False,
            ack_timeout_ms=100,
        )
        self.assertEqual(offline["available"], [True, True, True, False])
        self.assertTrue(math.isinf(offline["required_arrival"]))
        self.assertFalse(offline["reachable"])
        self.assertTrue(offline["timed_out"])
        self.assertEqual(offline["response_time"], 100)
        self.assertEqual(offline["version_at_response"], [1, 1, 1, 0])
        self.assertEqual(offline["current_count_response"], 3)
        self.assertTrue(offline["partial_apply"])
        self.assertTrue(offline["may_have_applied_on_timeout"])
        self.assertFalse(offline["read_succeeded"])
        self.assertIsNone(offline["read_version"])
        self.assertFalse(offline["converged"])
        self.assertIsNone(offline["convergence_time"])
        self.assertEqual(offline["available_convergence_time"], 35)
        self.assertEqual(offline["online_lag_exposure"], 50)
        self.assertEqual(offline["outcome"], "timeout-read-unavailable")

        offline_three = reference_replication(
            required_ack_count=3,
            slow_replica_available=False,
            ack_timeout_ms=100,
        )
        self.assertTrue(offline_three["acknowledged"])
        self.assertEqual(offline_three["response_time"], 35)
        self.assertFalse(offline_three["read_succeeded"])
        self.assertEqual(offline_three["outcome"], "acknowledged-read-unavailable")

        late_online = reference_replication(
            required_ack_count=4, read_after_response_ms=1, ack_timeout_ms=74
        )
        self.assertTrue(late_online["timed_out"])
        self.assertEqual(late_online["current_count_response"], 3)
        self.assertFalse(late_online["current_at_response"][3])
        self.assertEqual(late_online["read_time"], 75)
        self.assertTrue(late_online["current_at_read"][3])
        self.assertEqual(late_online["read_version"], 1)
        self.assertEqual(late_online["outcome"], "timeout-current-read")

        recovered = reference_replication()
        self.assertEqual(recovered, reference_replication())
        self.assertTrue(recovered["converged"])
        self.assertEqual(recovered["read_version"], 1)

    def test_timeout_with_online_stale_read_is_distinct_from_unavailable(self) -> None:
        timed_out_stale = reference_replication(
            required_ack_count=4,
            read_after_response_ms=0,
            slow_replica_available=True,
            ack_timeout_ms=74,
        )
        self.assertTrue(timed_out_stale["timed_out"])
        self.assertEqual(timed_out_stale["response_time"], 74)
        self.assertEqual(timed_out_stale["current_count_response"], 3)
        self.assertTrue(timed_out_stale["may_have_applied_on_timeout"])
        self.assertEqual(timed_out_stale["read_time"], 74)
        self.assertTrue(timed_out_stale["read_succeeded"])
        self.assertEqual(timed_out_stale["read_version"], 0)
        self.assertTrue(timed_out_stale["stale_read"])
        self.assertFalse(timed_out_stale["read_your_write_applicable"])
        self.assertFalse(timed_out_stale["read_your_write_satisfied"])
        self.assertEqual(timed_out_stale["outcome"], "timeout-stale-read")

        timed_out_unavailable = reference_replication(
            required_ack_count=4,
            read_after_response_ms=0,
            slow_replica_available=False,
            ack_timeout_ms=74,
        )
        self.assertTrue(timed_out_unavailable["timed_out"])
        self.assertFalse(timed_out_unavailable["read_succeeded"])
        self.assertFalse(timed_out_unavailable["stale_read"])
        self.assertEqual(timed_out_unavailable["outcome"], "timeout-read-unavailable")

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", checks).lower().replace("...", "")
        self.assertIn(
            "onlinetimedoutstaleread=model(1,4,0,true,74);",
            compact,
        )
        self.assertIn(
            "strcmp(onlinetimedoutstaleread.outcome,'timeout-stale-read')",
            compact,
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(propagationdelayscale,requiredackcount,"
            "readafterresponsems,slowreplicaavailable,acktimeoutms)",
            compact,
        )
        for formula in (
            "replicacount=4;",
            "primaryreplicaindex=1;",
            "readtargetreplicaindex=4;",
            "initialversion=0;",
            "updateversion=1;",
            "initialvaluepercent=40;",
            "updatedvaluepercent=65;",
            "basepropagationdelayms=[0103070];",
            "applycostms=[0555];",
            "ackreturndelayms=zeros(1,replicacount);",
            "replicaavailable=[truetruetrueslowreplicaavailable];",
            "nominalapplytimems=propagationdelayscale*basepropagationdelayms+applycostms;",
            "effectiveapplytimems(~replicaavailable)=inf;",
            "ackobservationtimems=effectiveapplytimems+ackreturndelayms;",
            "orderedacktimems=sort(ackobservationtimems);",
            "requiredackarrivaltimems=orderedacktimems(requiredackcount);",
            "writeacknowledged=ackthresholdreachable&&requiredackarrivaltimems<=acktimeoutms;",
            "replicacurrentatresponse=replicaavailable&nominalapplytimems<=clientresponsetimems;",
            "readtimems=clientresponsetimems+readafterresponsems;",
            "replicacurrentatread=replicaavailable&nominalapplytimems<=readtimems;",
            "maxpropagationdelayscale=20;",
            "maxreadafterresponsems=1e6;",
            "maxacktimeoutms=1e6;",
            "maxderivedtimems=2.1e6;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "propagationdelayscale=double(propagationdelayscale);",
            "requiredackcount=double(requiredackcount);",
            "readafterresponsems=double(readafterresponsems);",
            "slowreplicaavailable=logical(slowreplicaavailable);",
            "acktimeoutms=double(acktimeoutms);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P09:InvalidPropagationDelayScale",
            "P09:InvalidRequiredAckCount",
            "P09:InvalidReadDelay",
            "P09:InvalidReplicaAvailability",
            "P09:InvalidAckTimeout",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.singleWriterAssumed = true;",
            "out.replicationModeled = true;",
            "out.timeoutModeled = true;",
            "out.ackReturnDelayAssumedZero = true;",
            "out.ackReturnTransportModeled = false;",
            "out.ackLossModeled = false;",
            "out.acknowledgmentObservationUsesTeachingOracle = true;",
            "out.timeoutIsArithmeticClassification = true;",
            "out.actualWaitPerformed = false;",
            "out.cancellationModeled = false;",
            "out.actualCancellationPerformed = false;",
            "out.rollbackModeled = false;",
            "out.actualRollbackPerformed = false;",
            "out.partialApplyIsNotRolledBack = true;",
            "out.recoveryRequiresReplicaCatchUp = true;",
            "out.writeOrderingModeled = false;",
            "out.concurrentWritersModeled = false;",
            "out.consensusModeled = false;",
            "out.quorumConsensusModeled = false;",
            "out.networkIoPerformed = false;",
            "out.storageIoPerformed = false;",
            "out.backgroundWorkStarted = false;",
            "out.physicalHardwareUsed = false;",
            "out.replicaCount = replicaCount;",
            "out.updateCount = 1;",
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
            "propagationdelayscales = [0.5 1 2]",
            "requiredackcounts = [1 2 4]",
            "baseline = model(1,4,0,true,160)",
            "broken = model(1,1,0,true,160)",
            "timedout = model(1,4,0,false,100)",
            "not universal visibility",
        ):
            self.assertIn(marker, lowered)
        for label in (
            "time after primary accepts update (ms)",
            "applied state version (integer; traces offset for visibility)",
            "replica",
            "propagation delay scale (x)",
            "accumulated version lag (replica-ms)",
            "required acknowledgments w (count)",
            "write response latency (ms)",
            "applied state version at client response (integer)",
        ):
            self.assertIn(label, lowered)
        self.assertIn(
            "isequal(broken.replicaversionatresponse,[1000])", compact
        )

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertIn("uifigure", lowered)
        self.assertEqual(lowered.count("uispinner"), 4)
        self.assertIn("uicheckbox", lowered)
        self.assertIn("replicationmodel=@model;", compact)
        self.assertIn("reset baseline", lowered)
        self.assertGreaterEqual(lowered.count("valuechangedfcn"), 5)
        for setting in (
            "'limits',[05],'value',baselinepropagationdelayscale,'step',0.25",
            "'limits',[14],'value',baselinerequiredackcount,'step',1",
            "'limits',[0200],'value',baselinereadafterresponsems,'step',5",
            "'limits',[0500],'value',baselineacktimeoutms,'step',5",
            "'text','replicadonline','value',baselineslowreplicaavailable",
        ):
            self.assertIn(setting, compact)
        for reset in (
            "delaycontrol.value=baselinepropagationdelayscale;",
            "ackcontrol.value=baselinerequiredackcount;",
            "readcontrol.value=baselinereadafterresponsems;",
            "availabilitycontrol.value=baselineslowreplicaavailable;",
            "timeoutcontrol.value=baselineacktimeoutms;",
        ):
            self.assertIn(reset, compact)
        self.assertIn(
            "replicationmodel(delaycontrol.value,ackcontrol.value,"
            "readcontrol.value,availabilitycontrol.value,timeoutcontrol.value)",
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
            "p08",
            "t_apply_i",
            "single-writer",
            "replicated register",
            "propagation",
            "apply cost",
            "version",
            "replica-ms",
            "acknowledgment",
            "w-th",
            "stale read",
            "universal visibility",
            "timeout",
            "partial apply",
            "rollback",
            "cancellation",
            "recovery",
            "p10",
            "p12",
            "consensus",
            "interpretation",
            "teach-back",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 90)
        for marker in (
            "baseline",
            "repeated",
            "typed",
            "fractional",
            "propagationDelayScales",
            "requiredAckCounts",
            "zeroPropagation",
            "zeroTimeoutPrimaryAck",
            "exactAckTimeout",
            "justBeforeAckTimeout",
            "broken",
            "justBeforeReadBoundary",
            "exactReadBoundary",
            "coherentAllAck",
            "onlineTimedOutStaleRead",
            "onlineLateAck",
            "offlineAllAck",
            "offlineThreeAcks",
            "recoveryTarget",
            "bounded",
            "assertThrows",
            "recoveredAfterMalformed",
            "P09 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P09:InvalidPropagationDelayScale",
            "P09:InvalidRequiredAckCount",
            "P09:InvalidReadDelay",
            "P09:InvalidReplicaAvailability",
            "P09:InvalidAckTimeout",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
