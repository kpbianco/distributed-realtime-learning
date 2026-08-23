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
FOLDER = ROOT / "modules/11-apply-backpressure"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you apply "
    "Backpressure?"
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


def reference_backpressure(
    producer_interval_ms: float = 10,
    service_time_ms: float = 20,
    receiver_capacity: int = 3,
    max_wait_ms: float = 200,
    use_backpressure: bool = True,
    cancel_message_six: bool = False,
) -> dict[str, object]:
    """Independent finite-event oracle for P11's fixed twelve demands."""
    message_count = 12
    message_ids = list(range(1, message_count + 1))
    ready = [index * producer_interval_ms for index in range(message_count)]
    admitted = [False] * message_count
    dropped = [False] * message_count
    timed_out = [False] * message_count
    canceled = [False] * message_count
    suppressed = [False] * message_count
    admission: list[float | None] = [None] * message_count
    service_start: list[float | None] = [None] * message_count
    completion: list[float | None] = [None] * message_count
    decision: list[float | None] = [None] * message_count
    wait: list[float | None] = [None] * message_count
    receiver_wait: list[float | None] = [None] * message_count
    receiver_residence: list[float | None] = [None] * message_count
    end_to_end: list[float | None] = [None] * message_count
    occupancy_after_admission: list[int | None] = [None] * message_count
    last_completion = 0.0
    stream_stopped = False
    stream_stop_time: float | None = None
    stream_stop_reason = "none"

    for index, ready_time in enumerate(ready):
        if stream_stopped:
            suppressed[index] = True
            decision[index] = max(ready_time, stream_stop_time)
        elif use_backpressure:
            candidate = math.inf if receiver_capacity == 0 else ready_time
            if receiver_capacity > 0:
                for _release_attempt in range(message_count):
                    active_completions = [
                        value
                        for value in completion[:index]
                        if value is not None and value > candidate
                    ]
                    if len(active_completions) < receiver_capacity:
                        break
                    candidate = min(active_completions)

            timeout_time = ready_time + max_wait_ms
            cancellation_time = (
                ready_time + 5
                if cancel_message_six and index == 5
                else math.inf
            )
            if candidate <= timeout_time and candidate <= cancellation_time:
                admitted[index] = True
                admission[index] = candidate
                decision[index] = candidate
            elif cancellation_time <= timeout_time:
                canceled[index] = True
                decision[index] = cancellation_time
                stream_stopped = True
                stream_stop_time = cancellation_time
                stream_stop_reason = "pending-cancellation"
            else:
                timed_out[index] = True
                decision[index] = timeout_time
                stream_stopped = True
                stream_stop_time = timeout_time
                stream_stop_reason = "upstream-timeout"
        else:
            active = sum(
                value is not None and value > ready_time
                for value in completion[:index]
            )
            if active >= receiver_capacity:
                dropped[index] = True
                decision[index] = ready_time
            else:
                admitted[index] = True
                admission[index] = ready_time
                decision[index] = ready_time

        wait[index] = decision[index] - ready_time
        if admitted[index]:
            active = sum(
                value is not None and value > admission[index]
                for value in completion[:index]
            )
            occupancy_after_admission[index] = active + 1
            service_start[index] = max(admission[index], last_completion)
            completion[index] = service_start[index] + service_time_ms
            last_completion = completion[index]
            receiver_wait[index] = service_start[index] - admission[index]
            receiver_residence[index] = completion[index] - admission[index]
            end_to_end[index] = completion[index] - ready_time

    failed = [
        dropped[index]
        or timed_out[index]
        or canceled[index]
        or suppressed[index]
        for index in range(message_count)
    ]
    accepted_ids = [
        message_ids[index] for index, value in enumerate(admitted) if value
    ]
    valid_completions = [value for value in completion if value is not None]
    observation_times = sorted(
        set(ready + [value for value in decision if value is not None] + valid_completions)
    )
    offered_cumulative = [sum(value <= time for value in ready) for time in observation_times]
    admitted_cumulative = [
        sum(value is not None and value <= time for value in admission)
        for time in observation_times
    ]
    completed_cumulative = [
        sum(value is not None and value <= time for value in completion)
        for time in observation_times
    ]
    failed_cumulative = [
        sum(failed[index] and decision[index] <= time for index in range(message_count))
        for time in observation_times
    ]
    receiver_occupancy = [
        sum(
            admission[index] is not None
            and admission[index] <= time
            and completion[index] > time
            for index in range(message_count)
        )
        for time in observation_times
    ]
    upstream_pending = [
        sum(ready[index] <= time < decision[index] for index in range(message_count))
        if use_backpressure
        else 0
        for time in observation_times
    ]
    admitted_count = sum(admitted)
    failed_count = sum(failed)
    return {
        "message_ids": message_ids,
        "ready": ready,
        "admitted": admitted,
        "dropped": dropped,
        "timed_out": timed_out,
        "canceled": canceled,
        "suppressed": suppressed,
        "failed": failed,
        "admission": admission,
        "service_start": service_start,
        "completion": completion,
        "decision": decision,
        "wait": wait,
        "receiver_wait": receiver_wait,
        "receiver_residence": receiver_residence,
        "end_to_end": end_to_end,
        "occupancy_after_admission": occupancy_after_admission,
        "accepted_ids": accepted_ids,
        "admitted_count": admitted_count,
        "completed_count": admitted_count,
        "dropped_count": sum(dropped),
        "timed_out_count": sum(timed_out),
        "canceled_count": sum(canceled),
        "suppressed_count": sum(suppressed),
        "failed_count": failed_count,
        "total_upstream_wait": sum(wait),
        "max_upstream_wait": max(wait),
        "total_receiver_wait": sum(
            value for value in receiver_wait if value is not None
        ),
        "max_receiver_wait": max(
            (value for value in receiver_wait if value is not None), default=0
        ),
        "high_water": max(
            (value for value in occupancy_after_admission if value is not None),
            default=0,
        ),
        "completion_time": max(valid_completions, default=None),
        "observation_times": observation_times,
        "offered_cumulative": offered_cumulative,
        "admitted_cumulative": admitted_cumulative,
        "completed_cumulative": completed_cumulative,
        "failed_cumulative": failed_cumulative,
        "receiver_occupancy": receiver_occupancy,
        "upstream_pending": upstream_pending,
        "peak_upstream_pending": max(upstream_pending),
        "stream_stopped": stream_stopped,
        "stream_stop_time": stream_stop_time,
        "stream_stop_reason": stream_stop_reason,
        "lossless": admitted_count == message_count and failed_count == 0,
        "capacity_respected": max(receiver_occupancy) <= receiver_capacity,
        "accepted_prefix": accepted_ids == message_ids[:admitted_count],
    }


class P11ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads(
            (ROOT / "curriculum/modules.json").read_text(encoding="utf-8")
        )
        cls.modules = manifest["modules"]
        cls.module = next(module for module in cls.modules if module["id"] == "P11")

    def test_permanent_manifest_identity_prerequisite_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 11)
        self.assertEqual(self.module["id"], "P11")
        self.assertEqual(self.module["title"], "Apply Backpressure")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 3)
        self.assertEqual(self.module["phase_title"], "Coordination and flow")
        self.assertEqual(self.module["slug"], "apply-backpressure")
        self.assertEqual(self.module["prerequisites"], ["P10"])
        self.assertEqual(self.module["implementation_batch"], "P11")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        positions = {module["id"]: index for index, module in enumerate(self.modules)}
        prerequisite = next(module for module in self.modules if module["id"] == "P10")
        self.assertLess(positions["P10"], positions["P11"])
        self.assertEqual(prerequisite["status"], "implemented")
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p11_checks(self) -> None:
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

            started = run_cli("start", "P11")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P11 — Apply Backpressure", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P11')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P11")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P11 — Apply Backpressure", continued.stdout)
            checked = run_cli("check", "P11")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P11')\n")

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
        self.assertIn("experimentfiguretag='p11experimentfigure';", compact)
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
        self.assertIn("interactivefiguretag='p11interactivefigure';", compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            compact,
        )
        self.assertIn("close(existingwindows);", compact)
        self.assertEqual(compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_backpressure()
        self.assertEqual(baseline["ready"], list(range(0, 120, 10)))
        self.assertEqual(
            baseline["admission"],
            [0, 10, 20, 30, 40, 60, 80, 100, 120, 140, 160, 180],
        )
        self.assertEqual(baseline["service_start"], list(range(0, 240, 20)))
        self.assertEqual(baseline["completion"], list(range(20, 260, 20)))
        self.assertEqual(
            baseline["wait"], [0, 0, 0, 0, 0, 10, 20, 30, 40, 50, 60, 70]
        )
        self.assertEqual(
            baseline["receiver_wait"],
            [0, 10, 20, 30, 40, 40, 40, 40, 40, 40, 40, 40],
        )
        self.assertEqual(
            baseline["occupancy_after_admission"],
            [1, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3],
        )
        self.assertEqual(baseline["accepted_ids"], list(range(1, 13)))
        self.assertEqual(baseline["total_upstream_wait"], 280)
        self.assertEqual(baseline["max_upstream_wait"], 70)
        self.assertEqual(baseline["total_receiver_wait"], 380)
        self.assertEqual(baseline["max_receiver_wait"], 40)
        self.assertEqual(baseline["high_water"], 3)
        self.assertEqual(baseline["peak_upstream_pending"], 4)
        self.assertEqual(baseline["completion_time"], 240)
        self.assertTrue(baseline["lossless"])
        self.assertTrue(baseline["capacity_respected"])
        self.assertTrue(baseline["accepted_prefix"])
        self.assertEqual(reference_backpressure(), baseline)

        self.assertEqual(
            baseline["receiver_occupancy"],
            [
                admitted - completed
                for admitted, completed in zip(
                    baseline["admitted_cumulative"], baseline["completed_cumulative"]
                )
            ],
        )
        self.assertEqual(
            baseline["upstream_pending"],
            [
                offered - admitted - failed
                for offered, admitted, failed in zip(
                    baseline["offered_cumulative"],
                    baseline["admitted_cumulative"],
                    baseline["failed_cumulative"],
                )
            ],
        )

        interval_cases = [
            reference_backpressure(producer_interval_ms=value)
            for value in (5, 10, 20, 30)
        ]
        self.assertEqual(
            [case["total_upstream_wait"] for case in interval_cases],
            [585, 280, 0, 0],
        )
        self.assertEqual(
            [case["max_upstream_wait"] for case in interval_cases],
            [125, 70, 0, 0],
        )
        self.assertEqual(
            [case["high_water"] for case in interval_cases], [3, 3, 1, 1]
        )
        self.assertEqual(
            [case["completion_time"] for case in interval_cases],
            [240, 240, 240, 350],
        )
        self.assertTrue(all(case["lossless"] for case in interval_cases))

        capacity_cases = [
            reference_backpressure(receiver_capacity=value)
            for value in (1, 2, 3, 6)
        ]
        self.assertEqual(
            [case["total_upstream_wait"] for case in capacity_cases],
            [660, 450, 280, 10],
        )
        self.assertEqual(
            [case["max_upstream_wait"] for case in capacity_cases],
            [110, 90, 70, 10],
        )
        self.assertEqual(
            [case["max_receiver_wait"] for case in capacity_cases],
            [0, 20, 40, 100],
        )
        self.assertEqual(
            [case["completion_time"] for case in capacity_cases],
            [240, 240, 240, 240],
        )
        self.assertEqual(
            [case["high_water"] for case in capacity_cases], [1, 2, 3, 6]
        )
        self.assertTrue(all(case["lossless"] for case in capacity_cases))

        critical = reference_backpressure(20, 20, 1, 0)
        self.assertTrue(critical["lossless"])
        self.assertEqual(critical["wait"], [0] * 12)
        self.assertEqual(critical["receiver_wait"], [0] * 12)
        self.assertEqual(critical["high_water"], 1)

        zero_capacity = reference_backpressure(receiver_capacity=0, max_wait_ms=20)
        self.assertEqual(zero_capacity["admitted_count"], 0)
        self.assertEqual(zero_capacity["timed_out_count"], 1)
        self.assertEqual(zero_capacity["suppressed_count"], 11)
        self.assertEqual(zero_capacity["failed_count"], 12)
        self.assertEqual(zero_capacity["stream_stop_time"], 20)
        self.assertTrue(zero_capacity["capacity_respected"])

        bounded = reference_backpressure(1, 1000, 12, 1_000_000)
        self.assertEqual(bounded["admission"], list(range(12)))
        self.assertEqual(bounded["completion"], list(range(1000, 13_000, 1000)))
        self.assertEqual(bounded["high_water"], 12)
        self.assertTrue(bounded["lossless"])

        # With capacity one, demand i scans its n=i-1 predecessors n+1
        # times before admission, then once for occupancy: sum n*(n+2).
        maximum_prior_completion_comparisons = sum(
            predecessor_count * (predecessor_count + 2)
            for predecessor_count in range(12)
        )
        self.assertEqual(maximum_prior_completion_comparisons, 638)

    def test_broken_timeout_cancellation_recovery_and_isolation_oracle(self) -> None:
        broken = reference_backpressure(use_backpressure=False)
        self.assertEqual(broken["accepted_ids"], [1, 2, 3, 4, 5, 7, 9, 11])
        self.assertEqual(
            [index + 1 for index, value in enumerate(broken["dropped"]) if value],
            [6, 8, 10, 12],
        )
        self.assertEqual(broken["admitted_count"], 8)
        self.assertEqual(broken["dropped_count"], 4)
        self.assertEqual(broken["failed_count"], 4)
        self.assertEqual(broken["total_upstream_wait"], 0)
        self.assertEqual(broken["completion_time"], 160)
        self.assertFalse(broken["accepted_prefix"])
        self.assertFalse(broken["lossless"])
        self.assertTrue(broken["capacity_respected"])

        exact = reference_backpressure(max_wait_ms=10)
        self.assertEqual(exact["accepted_ids"], list(range(1, 7)))
        self.assertEqual(exact["admission"][5], 60)
        self.assertTrue(exact["timed_out"][6])
        self.assertEqual(exact["stream_stop_time"], 70)
        self.assertTrue(all(exact["suppressed"][7:]))
        self.assertEqual(exact["completion_time"], 120)
        self.assertTrue(exact["accepted_prefix"])

        just_before = reference_backpressure(max_wait_ms=10 - 1e-12)
        self.assertEqual(just_before["accepted_ids"], list(range(1, 6)))
        self.assertTrue(just_before["timed_out"][5])
        self.assertLess(just_before["stream_stop_time"], 60)
        self.assertTrue(all(just_before["suppressed"][6:]))
        self.assertEqual(just_before["completion_time"], 100)

        canceled = reference_backpressure(cancel_message_six=True)
        self.assertEqual(canceled["accepted_ids"], list(range(1, 6)))
        self.assertTrue(canceled["canceled"][5])
        self.assertEqual(canceled["canceled_count"], 1)
        self.assertEqual(canceled["suppressed_count"], 6)
        self.assertEqual(canceled["stream_stop_time"], 55)
        self.assertEqual(canceled["stream_stop_reason"], "pending-cancellation")
        self.assertEqual(canceled["completion_time"], 100)
        self.assertTrue(canceled["accepted_prefix"])

        cancellation_too_late = reference_backpressure(
            producer_interval_ms=20,
            service_time_ms=20,
            receiver_capacity=1,
            cancel_message_six=True,
        )
        self.assertTrue(cancellation_too_late["admitted"][5])
        self.assertEqual(cancellation_too_late["canceled_count"], 0)
        self.assertTrue(cancellation_too_late["lossless"])

        recovered = reference_backpressure()
        self.assertEqual(recovered, reference_backpressure())
        self.assertTrue(recovered["lossless"])
        self.assertEqual(recovered["accepted_ids"], list(range(1, 13)))

    def test_readiness_wins_exact_pending_cancellation_tie(self) -> None:
        tied = reference_backpressure(
            producer_interval_ms=5,
            service_time_ms=10,
            receiver_capacity=3,
            max_wait_ms=200,
            use_backpressure=True,
            cancel_message_six=True,
        )
        without_cancellation = reference_backpressure(
            producer_interval_ms=5,
            service_time_ms=10,
            receiver_capacity=3,
            max_wait_ms=200,
            use_backpressure=True,
            cancel_message_six=False,
        )

        self.assertEqual(tied["ready"][5], 25)
        self.assertEqual(tied["admission"][5], 30)
        self.assertEqual(tied["admission"][5], tied["ready"][5] + 5)
        self.assertTrue(tied["admitted"][5])
        self.assertFalse(tied["canceled"][5])
        self.assertEqual(tied["canceled_count"], 0)
        self.assertFalse(tied["stream_stopped"])
        self.assertTrue(tied["lossless"])
        self.assertEqual(tied, without_cancellation)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", checks).lower().replace("...", "")
        self.assertIn(
            "cancellationatadmissiontie=model(5,10,3,200,true,true);", compact
        )
        self.assertIn(
            "cancellationatadmissiontie.admissiontimems(6)=="
            "cancellationatadmissiontie.demandreadytimems(6)+5",
            compact,
        )
        self.assertIn("~cancellationatadmissiontie.canceledmask(6)", compact)

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(producerintervalms,servicetimems,"
            "receivercapacitymessages,maxbackpressurewaitms,"
            "usebackpressure,cancelmessagesixwhilewaiting)",
            compact,
        )
        for formula in (
            "messagecount=12;",
            "cancelmessageindex=6;",
            "canceldelayms=5;",
            "demandreadytimems=(messageid-1)*producerintervalms;",
            "maxadmissioncomparisoncount=(messagecount-1)*messagecount*(2*messagecount+5)/6;",
            "priorcompletiontimems=completiontimems(priormessagerange);",
            "unfinishedpriormask=admittedmask(priormessagerange)&priorcompletiontimems>candidateadmissiontimems;",
            "candidateadmissiontimems=min(priorcompletiontimems(unfinishedpriormask));",
            "servicestarttimems(messageindex)=max(admissiontimems(messageindex),lastcompletiontimems);",
            "completiontimems(messageindex)=servicestarttimems(messageindex)+servicetimems;",
            "[~,admissioneventorder]=sort(admissiontimems(admittedmask));",
            "admittedmessageids=sourceorderedadmittedmessageids(admissioneventorder);",
            "[~,completioneventorder]=sort(completiontimems(admittedmask));",
            "completedmessageids=sourceorderedadmittedmessageids(completioneventorder);",
            "maxobservationeventcount=3*messagecount;",
            "maxderivedtimems=1.012e6;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "producerintervalms=double(producerintervalms);",
            "servicetimems=double(servicetimems);",
            "receivercapacitymessages=double(receivercapacitymessages);",
            "maxbackpressurewaitms=double(maxbackpressurewaitms);",
            "usebackpressure=logical(usebackpressure);",
            "cancelmessagesixwhilewaiting=logical(cancelmessagesixwhilewaiting);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P11:InvalidProducerInterval",
            "P11:InvalidServiceTime",
            "P11:InvalidCapacity",
            "P11:InvalidMaxWait",
            "P11:InvalidBackpressurePolicy",
            "P11:InvalidCancellationPolicy",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.capacityIncludesMessageInService = true;",
            "out.completionCreditBeforeCoincidentAdmission = true;",
            "out.feedbackDelayMs = 0;",
            "out.instantaneousReadinessFeedbackAssumed = true;",
            "out.feedbackOvershootModeled = false;",
            "out.backpressureCreatesServiceCapacity = false;",
            "out.timeoutIsArithmeticClassification = true;",
            "out.actualWallClockWaitPerformed = false;",
            "out.actualAsynchronousCancellationPerformed = false;",
            "out.rollbackModeled = false;",
            "out.actualRollbackPerformed = false;",
            "out.acceptedWorkNotRolledBack = true;",
            "out.recoveryModeled = false;",
            "out.freshEvaluationRequiredForRecoveryTarget = true;",
            "out.retryModeled = false;",
            "out.creditProtocolModeled = false;",
            "out.transportProtocolModeled = false;",
            "out.networkIoPerformed = false;",
            "out.storageIoPerformed = false;",
            "out.backgroundWorkStarted = false;",
            "out.physicalHardwareUsed = false;",
            "out.calculationBounded = true;",
        ):
            self.assertIn(boundary, source)
        self.assertIn("for messageIndex = 1:messageCount", source)
        self.assertIn("for releaseAttempt = 1:messageCount", source)
        self.assertIn("for eventIndex = 1:observationEventCount", source)
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
            "producerintervalsms = [5 10 20 30]",
            "receivercapacities = [1 2 3 6]",
            "baseline = model(10,20,3,200,true,false)",
            "broken = model(10,20,3,200,false,false)",
            "a producer can ignore receiver readiness without loss",
        ):
            self.assertIn(marker, lowered)
        self.assertIn(
            "current=model(producerintervalsms(caseindex),20,3,200,true,false);",
            compact,
        )
        self.assertIn(
            "current=model(10,20,receivercapacities(caseindex),200,true,false);",
            compact,
        )
        for label in (
            "ordered message identifier (integer)",
            "time from first demand (ms)",
            "analytical event time (ms)",
            "messages (count)",
            "producer demand interval (ms)",
            "upstream wait (message-ms or ms)",
            "receiver capacity including service (messages)",
            "cumulative messages (count)",
        ):
            self.assertIn(label, lowered)
        self.assertIn("isequal(find(broken.droppedmask),[681012])", compact)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertIn("uifigure", lowered)
        self.assertEqual(lowered.count("uispinner"), 4)
        self.assertEqual(lowered.count("uicheckbox"), 2)
        self.assertIn("backpressuremodel=@model;", compact)
        self.assertIn("reset baseline", lowered)
        self.assertGreaterEqual(lowered.count("valuechangedfcn"), 6)
        for setting in (
            "'limits',[530],'value',baselineproducerintervalms,'step',5",
            "'limits',[540],'value',baselineservicetimems,'step',5",
            "'limits',[012],'value',baselinereceivercapacitymessages,'step',1",
            "'limits',[0300],'value',baselinemaxbackpressurewaitms,'step',10",
            "'text','applycompletion-creditbackpressure','value',baselineusebackpressure",
            "'text','cancelmessage6ifwaiting','value',baselinecancelmessagesix",
        ):
            self.assertIn(setting, compact)
        for reset in (
            "producercontrol.value=baselineproducerintervalms;",
            "servicecontrol.value=baselineservicetimems;",
            "capacitycontrol.value=baselinereceivercapacitymessages;",
            "waitcontrol.value=baselinemaxbackpressurewaitms;",
            "policycontrol.value=baselineusebackpressure;",
            "cancelcontrol.value=baselinecancelmessagesix;",
        ):
            self.assertIn(reset, compact)
        self.assertIn(
            "backpressuremodel(producercontrol.value,servicecontrol.value,"
            "capacitycontrol.value,waitcontrol.value,policycontrol.value,"
            "cancelcontrol.value)",
            compact,
        )
        self.assertIn("admitted/completed/demand%d/%d/%d", compact)
        self.assertIn(
            "decisiontext,current.admittedcount,current.completedcount,"
            "current.messagecount,current.failedcount",
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
            "p10",
            "p04",
            "r_i",
            "completion credit",
            "receiver capacity",
            "upstream",
            "message-ms",
            "offered",
            "admitted",
            "completed",
            "dropped",
            "timeout",
            "cancellation",
            "rollback",
            "recovery",
            "instantaneous",
            "feedback",
            "interpretation",
            "teach-back",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 170)
        for marker in (
            "baseline",
            "repeated",
            "typed",
            "fractional",
            "producerIntervalsMs",
            "receiverCapacities",
            "critical",
            "underloaded",
            "capacityAboveDemand",
            "zeroCapacity",
            "bounded",
            "worstCaseComparisons",
            "broken",
            "brokenUnderload",
            "exactWaitBoundary",
            "justBeforeWaitBoundary",
            "zeroWait",
            "canceledPending",
            "cancellationTooLate",
            "recoveryAfterTimeout",
            "assertThrows",
            "recoveredAfterMalformed",
            "P11 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P11:InvalidProducerInterval",
            "P11:InvalidServiceTime",
            "P11:InvalidCapacity",
            "P11:InvalidMaxWait",
            "P11:InvalidBackpressurePolicy",
            "P11:InvalidCancellationPolicy",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
