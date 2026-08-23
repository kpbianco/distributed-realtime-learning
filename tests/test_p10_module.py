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
FOLDER = ROOT / "modules/10-preserve-message-ordering"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you preserve "
    "Message Ordering?"
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
SEND_TIME_MS = (0.0, 10.0, 20.0, 30.0, 40.0, 50.0)
BASE_NETWORK_DELAY_MS = (20.0, 5.0, 35.0, 5.0, 25.0, 0.0)


def inversion_count(values: list[int]) -> int:
    return sum(
        values[left] > values[right]
        for left in range(len(values))
        for right in range(left + 1, len(values))
    )


def reference_ordering(
    delay_scale: float = 1,
    buffer_capacity: int = 2,
    gap_timeout_ms: float = 100,
    message_three_available: bool = True,
    preserve_sequence_order: bool = True,
) -> dict[str, object]:
    """Independent event arithmetic for the fixed six-message P10 stream."""
    sequence = list(range(1, 7))
    network_delay = [delay_scale * value for value in BASE_NETWORK_DELAY_MS]
    arrival_by_sequence = [
        sent + delay for sent, delay in zip(SEND_TIME_MS, network_delay)
    ]
    received_in_send_order = [
        value for value in sequence if value != 3 or message_three_available
    ]
    events = sorted(
        (arrival_by_sequence[value - 1], value)
        for value in received_in_send_order
    )
    arrival_event_time = [event[0] for event in events]
    arrival_sequence = [event[1] for event in events]

    delivered: list[int] = []
    delivered_at: list[float] = []
    delivery_by_sequence: list[float | None] = [None] * 6
    occupancy_after_event: list[int | None] = [None] * len(events)
    buffered: set[int] = set()
    expected = 1
    processed_events = 0
    high_water = 0
    gap_start: float | None = None
    gap_deadline: float | None = None
    last_gap_start: float | None = None
    last_gap_deadline: float | None = None
    timeout_expected: int | None = None
    rejected_sequence: int | None = None
    timed_out = False
    overflow = False
    failure_time: float | None = None
    reason = "complete-ordered"

    if preserve_sequence_order:
        for event_index, (event_time, current_sequence) in enumerate(events):
            if gap_start is not None and event_time > gap_deadline:
                timed_out = True
                failure_time = gap_deadline
                timeout_expected = expected
                reason = "gap-timeout"
                break

            processed_events = event_index + 1
            if current_sequence == expected:
                delivered.append(current_sequence)
                delivered_at.append(event_time)
                delivery_by_sequence[current_sequence - 1] = event_time
                expected += 1
                for _drain_attempt in range(6):
                    if expected > 6 or expected not in buffered:
                        break
                    buffered.remove(expected)
                    delivered.append(expected)
                    delivered_at.append(event_time)
                    delivery_by_sequence[expected - 1] = event_time
                    expected += 1
                if buffered:
                    gap_start = min(arrival_by_sequence[value - 1] for value in buffered)
                    gap_deadline = gap_start + gap_timeout_ms
                    last_gap_start = gap_start
                    last_gap_deadline = gap_deadline
                else:
                    gap_start = None
                    gap_deadline = None
            elif current_sequence > expected:
                if len(buffered) >= buffer_capacity:
                    overflow = True
                    failure_time = event_time
                    rejected_sequence = current_sequence
                    reason = "buffer-overflow"
                    occupancy_after_event[event_index] = len(buffered)
                    break
                buffered.add(current_sequence)
                high_water = max(high_water, len(buffered))
                if gap_start is None:
                    gap_start = event_time
                    gap_deadline = gap_start + gap_timeout_ms
                    last_gap_start = gap_start
                    last_gap_deadline = gap_deadline

            occupancy_after_event[event_index] = len(buffered)
            if gap_start is not None and gap_deadline <= event_time:
                timed_out = True
                failure_time = gap_deadline
                timeout_expected = expected
                reason = "gap-timeout"
                break

        if not timed_out and not overflow and buffered:
            timed_out = True
            failure_time = gap_deadline
            timeout_expected = expected
            reason = "gap-timeout"
    else:
        delivered = arrival_sequence.copy()
        delivered_at = arrival_event_time.copy()
        for event_time, current_sequence in events:
            delivery_by_sequence[current_sequence - 1] = event_time
        occupancy_after_event = [0] * len(events)
        processed_events = len(events)
        expected = 0
        reason = (
            "arrival-order-delivery"
            if message_three_available
            else "arrival-order-missing-message"
        )

    holds: list[float | None] = [None] * 6
    for index, delivery_time in enumerate(delivery_by_sequence):
        if delivery_time is not None:
            holds[index] = delivery_time - arrival_by_sequence[index]
    delivered_holds = [value for value in holds if value is not None]
    complete_all = len(delivered) == 6
    prefix_ordered = delivered == sequence[: len(delivered)]
    complete_ordered = complete_all and delivered == sequence
    terminated = timed_out or overflow
    final_state = delivered[-1] if delivered else 0
    return {
        "network_delay": network_delay,
        "arrival_by_sequence": arrival_by_sequence,
        "received_in_send_order": received_in_send_order,
        "arrival_event_time": arrival_event_time,
        "arrival_sequence": arrival_sequence,
        "arrival_inversions": inversion_count(arrival_sequence),
        "arrival_matches_send": arrival_sequence == received_in_send_order,
        "delivered": delivered,
        "delivered_at": delivered_at,
        "delivery_by_sequence": delivery_by_sequence,
        "delivery_inversions": inversion_count(delivered),
        "prefix_ordered": prefix_ordered,
        "complete_ordered": complete_ordered,
        "all_delivered": complete_all,
        "completion_time": max(delivered_at) if complete_all else None,
        "holds": holds,
        "total_hold": sum(delivered_holds),
        "max_hold": max(delivered_holds, default=0),
        "occupancy": occupancy_after_event,
        "high_water": high_water,
        "buffered_at_termination": len(buffered),
        "expected_at_termination": expected,
        "gap_start": gap_start,
        "gap_deadline": gap_deadline,
        "last_gap_start": last_gap_start,
        "last_gap_deadline": last_gap_deadline,
        "timed_out": timed_out,
        "timeout_expected": timeout_expected,
        "overflow": overflow,
        "rejected_sequence": rejected_sequence,
        "failure_time": failure_time,
        "terminated": terminated,
        "reason": reason,
        "processed_events": processed_events,
        "in_flight_at_termination": len(events) - processed_events,
        "missing_count": 6 - len(events),
        "delivery_suppressed": len(events) - len(delivered),
        "undelivered": 6 - len(delivered),
        "remaining_suppressed": terminated and len(events) > len(delivered),
        "partial_delivery": 0 < len(delivered) < 6,
        "state_trace": [0, *delivered],
        "state_regressions": sum(
            delivered[index] < delivered[index - 1]
            for index in range(1, len(delivered))
        ),
        "final_state": final_state,
        "final_is_latest": final_state == 6,
    }


class P10ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads(
            (ROOT / "curriculum/modules.json").read_text(encoding="utf-8")
        )
        cls.modules = manifest["modules"]
        cls.module = next(module for module in cls.modules if module["id"] == "P10")

    def test_permanent_manifest_identity_prerequisite_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 10)
        self.assertEqual(self.module["id"], "P10")
        self.assertEqual(self.module["title"], "Preserve Message Ordering")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 3)
        self.assertEqual(self.module["phase_title"], "Coordination and flow")
        self.assertEqual(self.module["slug"], "preserve-message-ordering")
        self.assertEqual(self.module["prerequisites"], ["P09"])
        self.assertEqual(self.module["implementation_batch"], "P10")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        positions = {module["id"]: index for index, module in enumerate(self.modules)}
        prerequisite = next(module for module in self.modules if module["id"] == "P09")
        self.assertLess(positions["P09"], positions["P10"])
        self.assertEqual(prerequisite["status"], "implemented")
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p10_checks(self) -> None:
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

            started = run_cli("start", "P10")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P10 — Preserve Message Ordering", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P10')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P10")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P10 — Preserve Message Ordering", continued.stdout)
            checked = run_cli("check", "P10")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P10')\n")

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
        self.assertIn("experimentfiguretag='p10experimentfigure';", compact)
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
        self.assertIn("interactivefiguretag='p10interactivefigure';", compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            compact,
        )
        self.assertIn("close(existingwindows);", compact)
        self.assertEqual(compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_ordering()
        self.assertEqual(baseline["network_delay"], [20, 5, 35, 5, 25, 0])
        self.assertEqual(baseline["arrival_by_sequence"], [20, 15, 55, 35, 65, 50])
        self.assertEqual(baseline["arrival_event_time"], [15, 20, 35, 50, 55, 65])
        self.assertEqual(baseline["arrival_sequence"], [2, 1, 4, 6, 3, 5])
        self.assertEqual(baseline["arrival_inversions"], 4)
        self.assertFalse(baseline["arrival_matches_send"])
        self.assertEqual(baseline["delivered"], [1, 2, 3, 4, 5, 6])
        self.assertEqual(baseline["delivered_at"], [20, 20, 55, 55, 65, 65])
        self.assertEqual(baseline["delivery_by_sequence"], [20, 20, 55, 55, 65, 65])
        self.assertEqual(baseline["delivery_inversions"], 0)
        self.assertTrue(baseline["prefix_ordered"])
        self.assertTrue(baseline["complete_ordered"])
        self.assertEqual(baseline["completion_time"], 65)
        self.assertEqual(baseline["holds"], [0, 5, 0, 20, 0, 15])
        self.assertEqual(baseline["total_hold"], 40)
        self.assertEqual(baseline["max_hold"], 20)
        self.assertEqual(baseline["occupancy"], [1, 0, 1, 2, 1, 0])
        self.assertEqual(baseline["high_water"], 2)
        self.assertEqual(baseline["state_trace"], [0, 1, 2, 3, 4, 5, 6])
        self.assertEqual(baseline["state_regressions"], 0)
        self.assertEqual(baseline["final_state"], 6)
        self.assertEqual(reference_ordering(), baseline)

        delay_cases = [
            reference_ordering(delay_scale=scale)
            for scale in (0, 0.5, 1, 2)
        ]
        self.assertEqual(
            [case["arrival_inversions"] for case in delay_cases], [0, 2, 4, 4]
        )
        self.assertEqual([case["high_water"] for case in delay_cases], [0, 1, 2, 2])
        self.assertEqual([case["total_hold"] for case in delay_cases], [0, 7.5, 40, 110])
        self.assertEqual(
            [case["completion_time"] for case in delay_cases], [50, 52.5, 65, 90]
        )
        self.assertTrue(all(case["complete_ordered"] for case in delay_cases))

        capacity_cases = [reference_ordering(buffer_capacity=value) for value in (0, 1, 2)]
        self.assertEqual(
            [len(case["delivered"]) for case in capacity_cases], [0, 2, 6]
        )
        self.assertEqual([case["high_water"] for case in capacity_cases], [0, 1, 2])
        self.assertEqual(
            [case["failure_time"] or case["completion_time"] for case in capacity_cases],
            [15, 50, 65],
        )
        self.assertEqual(
            [case["complete_ordered"] for case in capacity_cases],
            [False, False, True],
        )

        zero_delay = reference_ordering(0, 0, 0)
        self.assertEqual(zero_delay["arrival_sequence"], [1, 2, 3, 4, 5, 6])
        self.assertEqual(zero_delay["delivered"], [1, 2, 3, 4, 5, 6])
        self.assertEqual(zero_delay["high_water"], 0)
        self.assertEqual(zero_delay["total_hold"], 0)
        self.assertTrue(zero_delay["complete_ordered"])

        naive_zero = reference_ordering(0, 0, 0, True, False)
        self.assertTrue(naive_zero["complete_ordered"])
        self.assertEqual(naive_zero["reason"], "arrival-order-delivery")

        bounded = reference_ordering(20, 6, 1_000_000)
        self.assertEqual(bounded["arrival_by_sequence"], [400, 110, 720, 130, 540, 50])
        self.assertEqual(bounded["arrival_sequence"], [6, 2, 4, 1, 5, 3])
        self.assertEqual(bounded["delivery_by_sequence"], [400, 400, 720, 720, 720, 720])
        self.assertEqual(bounded["high_water"], 3)
        self.assertEqual(bounded["total_hold"], 1730)
        self.assertEqual(bounded["completion_time"], 720)

    def test_timeout_overflow_broken_recovery_and_isolation_oracle(self) -> None:
        exact = reference_ordering(gap_timeout_ms=20)
        just_before = reference_ordering(gap_timeout_ms=20 - 1e-12)
        self.assertTrue(exact["complete_ordered"])
        self.assertFalse(exact["timed_out"])
        self.assertTrue(just_before["timed_out"])
        self.assertLess(just_before["failure_time"], 55)
        self.assertEqual(just_before["timeout_expected"], 3)
        self.assertEqual(just_before["delivered"], [1, 2])
        self.assertEqual(just_before["buffered_at_termination"], 2)
        self.assertEqual(just_before["in_flight_at_termination"], 2)

        missing = reference_ordering(gap_timeout_ms=20, message_three_available=False)
        self.assertEqual(missing["received_in_send_order"], [1, 2, 4, 5, 6])
        self.assertEqual(missing["arrival_sequence"], [2, 1, 4, 6, 5])
        self.assertTrue(missing["timed_out"])
        self.assertEqual(missing["failure_time"], 55)
        self.assertEqual(missing["timeout_expected"], 3)
        self.assertEqual(missing["delivered"], [1, 2])
        self.assertTrue(missing["prefix_ordered"])
        self.assertEqual(missing["buffered_at_termination"], 2)
        self.assertEqual(missing["in_flight_at_termination"], 1)
        self.assertEqual(missing["delivery_suppressed"], 3)
        self.assertEqual(missing["undelivered"], 4)
        self.assertTrue(missing["remaining_suppressed"])
        self.assertTrue(missing["partial_delivery"])
        self.assertEqual(missing["final_state"], 2)
        self.assertEqual(missing["state_regressions"], 0)

        zero_capacity = reference_ordering(buffer_capacity=0)
        self.assertTrue(zero_capacity["overflow"])
        self.assertEqual(zero_capacity["failure_time"], 15)
        self.assertEqual(zero_capacity["rejected_sequence"], 2)
        self.assertEqual(zero_capacity["delivered"], [])
        self.assertEqual(zero_capacity["in_flight_at_termination"], 5)

        one_slot = reference_ordering(buffer_capacity=1)
        self.assertTrue(one_slot["overflow"])
        self.assertEqual(one_slot["failure_time"], 50)
        self.assertEqual(one_slot["rejected_sequence"], 6)
        self.assertEqual(one_slot["delivered"], [1, 2])
        self.assertEqual(one_slot["buffered_at_termination"], 1)
        self.assertEqual(one_slot["in_flight_at_termination"], 2)

        broken = reference_ordering(preserve_sequence_order=False)
        self.assertEqual(broken["delivered"], [2, 1, 4, 6, 3, 5])
        self.assertTrue(broken["all_delivered"])
        self.assertFalse(broken["complete_ordered"])
        self.assertEqual(broken["delivery_inversions"], 4)
        self.assertEqual(broken["holds"], [0, 0, 0, 0, 0, 0])
        self.assertEqual(broken["high_water"], 0)
        self.assertEqual(broken["state_trace"], [0, 2, 1, 4, 6, 3, 5])
        self.assertEqual(broken["state_regressions"], 2)
        self.assertEqual(broken["final_state"], 5)
        self.assertFalse(broken["terminated"])

        recovered = reference_ordering()
        self.assertEqual(recovered, reference_ordering())
        self.assertTrue(recovered["complete_ordered"])
        self.assertEqual(recovered["final_state"], 6)

        bounded_missing = reference_ordering(20, 6, 1_000_000, False)
        self.assertTrue(bounded_missing["timed_out"])
        self.assertEqual(bounded_missing["failure_time"], 1_000_050)
        self.assertLessEqual(bounded_missing["failure_time"], 1_001_000)

    def test_raw_arrival_missing_message_is_distinct_from_ordered_timeout(self) -> None:
        raw_missing = reference_ordering(
            gap_timeout_ms=20,
            message_three_available=False,
            preserve_sequence_order=False,
        )
        self.assertEqual(raw_missing["received_in_send_order"], [1, 2, 4, 5, 6])
        self.assertEqual(raw_missing["arrival_sequence"], [2, 1, 4, 6, 5])
        self.assertEqual(raw_missing["delivered"], [2, 1, 4, 6, 5])
        self.assertFalse(raw_missing["all_delivered"])
        self.assertFalse(raw_missing["complete_ordered"])
        self.assertFalse(raw_missing["timed_out"])
        self.assertFalse(raw_missing["overflow"])
        self.assertFalse(raw_missing["terminated"])
        self.assertEqual(raw_missing["reason"], "arrival-order-missing-message")
        self.assertEqual(raw_missing["processed_events"], 5)
        self.assertEqual(raw_missing["in_flight_at_termination"], 0)
        self.assertEqual(raw_missing["missing_count"], 1)
        self.assertEqual(raw_missing["delivery_suppressed"], 0)
        self.assertEqual(raw_missing["undelivered"], 1)
        self.assertFalse(raw_missing["remaining_suppressed"])
        self.assertTrue(raw_missing["partial_delivery"])
        self.assertEqual(raw_missing["holds"], [0, 0, None, 0, 0, 0])
        self.assertEqual(raw_missing["total_hold"], 0)
        self.assertEqual(raw_missing["state_trace"], [0, 2, 1, 4, 6, 5])
        self.assertEqual(raw_missing["state_regressions"], 2)
        self.assertEqual(raw_missing["final_state"], 5)

        ordered_missing = reference_ordering(
            gap_timeout_ms=20,
            message_three_available=False,
            preserve_sequence_order=True,
        )
        self.assertTrue(ordered_missing["timed_out"])
        self.assertTrue(ordered_missing["terminated"])
        self.assertEqual(ordered_missing["reason"], "gap-timeout")
        self.assertEqual(ordered_missing["delivered"], [1, 2])
        self.assertEqual(ordered_missing["delivery_suppressed"], 3)
        self.assertTrue(ordered_missing["remaining_suppressed"])

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", checks).lower().replace("...", "")
        self.assertIn("brokenmissing=model(1,2,20,false,false);", compact)
        self.assertIn("~brokenmissing.timedout&&~brokenmissing.bufferoverflow", compact)
        self.assertIn("brokenmissing.deliverysuppressedmessagecount==0", compact)
        self.assertIn(
            "strcmp(brokenmissing.terminationreason,'arrival-order-missing-message')",
            compact,
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(delayscale,reorderbuffercapacity,gaptimeoutms,"
            "messagethreeavailable,preservesequenceorder)",
            compact,
        )
        for formula in (
            "messagecount=6;",
            "missingmessageindex=3;",
            "sendintervalms=10;",
            "sequence=1:messagecount;",
            "sendtimems=(sequence-1)*sendintervalms;",
            "basenetworkdelayms=[205355250];",
            "networkdelayms=delayscale*basenetworkdelayms;",
            "arrivaltimems=sendtimems+networkdelayms;",
            "arrivalevents=sortrows(arrivalevents,[12]);",
            "maxdelayscale=20;",
            "maxreorderbuffercapacity=messagecount;",
            "maxgaptimeoutms=1e6;",
            "maxderivedtimems=1.001e6;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "delayscale=double(delayscale);",
            "reorderbuffercapacity=double(reorderbuffercapacity);",
            "gaptimeoutms=double(gaptimeoutms);",
            "messagethreeavailable=logical(messagethreeavailable);",
            "preservesequenceorder=logical(preservesequenceorder);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P10:InvalidDelayScale",
            "P10:InvalidBufferCapacity",
            "P10:InvalidGapTimeout",
            "P10:InvalidMessageAvailability",
            "P10:InvalidOrderingPolicy",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.singleSenderAssumed = true;",
            "out.senderSequenceNumbersTrusted = true;",
            "out.fixedBatchSizeKnown = true;",
            "out.reorderBufferModeled = preserveSequenceOrder;",
            "out.timeoutIsArithmeticClassification = true;",
            "out.actualWaitPerformed = false;",
            "out.deliveryStopPolicyModeled = preserveSequenceOrder;",
            "out.actualAsynchronousCancellationPerformed = false;",
            "out.rollbackModeled = false;",
            "out.actualRollbackPerformed = false;",
            "out.deliveredPrefixNotRolledBack = true;",
            "out.recoveryModeled = false;",
            "out.recoveryRequiresReplayOrReevaluation = true;",
            "out.retransmissionModeled = false;",
            "out.duplicateHandlingModeled = false;",
            "out.sequenceWrapModeled = false;",
            "out.multipleSendersModeled = false;",
            "out.causalOrderModeled = false;",
            "out.totalOrderBroadcastModeled = false;",
            "out.consensusModeled = false;",
            "out.transportProtocolModeled = false;",
            "out.networkIoPerformed = false;",
            "out.storageIoPerformed = false;",
            "out.backgroundWorkStarted = false;",
            "out.physicalHardwareUsed = false;",
            "out.calculationBounded = true;",
        ):
            self.assertIn(boundary, source)
        self.assertIn("for eventIndex = 1:receivedMessageCount", source)
        self.assertIn("for drainAttempt = 1:messageCount", source)
        self.assertIn("for leftIndex = 1:numel(values)", source)
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
            "delayscales = [0 0.5 1 2]",
            "buffercapacities = [0 1 2]",
            "baseline = model(1,2,100,true,true)",
            "broken = model(1,2,100,true,false)",
            "missingmessage = model(1,2,20,false,true)",
            "arrival order is send order",
        ):
            self.assertIn(marker, lowered)
        self.assertIn(
            "current=model(delayscales(caseindex),2,100,true,true);", compact
        )
        for label in (
            "message sequence number (integer)",
            "time from batch start (ms)",
            "network arrival event rank (integer)",
            "buffered successors (messages)",
            "ordering hold before delivery (ms)",
            "path-delay scale (x)",
            "delivered ordering hold (message-ms)",
            "reorder-buffer capacity (messages)",
            "receiver state version (integer)",
        ):
            self.assertIn(label, lowered)
        self.assertIn("isequal(broken.deliverysequence,[214635])", compact)
        self.assertEqual(compact.count("stairs(0:baseline.messagecount"), 1)
        self.assertEqual(compact.count("stairs(0:broken.messagecount"), 1)
        self.assertIn("holdon;stairs(0:broken.messagecount", compact)
        self.assertIn("'linewidth',1.5);holdoff;gridon;", compact)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertIn("uifigure", lowered)
        self.assertEqual(lowered.count("uispinner"), 3)
        self.assertEqual(lowered.count("uicheckbox"), 2)
        self.assertIn("orderingmodel=@model;", compact)
        self.assertIn("reset baseline", lowered)
        self.assertGreaterEqual(lowered.count("valuechangedfcn"), 5)
        for setting in (
            "'limits',[03],'value',baselinedelayscale,'step',0.25",
            "'limits',[06],'value',baselinebuffercapacity,'step',1",
            "'limits',[0200],'value',baselinegaptimeoutms,'step',5",
            "'text','message3arrives','value',baselinemessagethreeavailable",
            "'text','usesequencereorderbuffer','value',baselinepreservesequenceorder",
        ):
            self.assertIn(setting, compact)
        for reset in (
            "delaycontrol.value=baselinedelayscale;",
            "capacitycontrol.value=baselinebuffercapacity;",
            "timeoutcontrol.value=baselinegaptimeoutms;",
            "availabilitycontrol.value=baselinemessagethreeavailable;",
            "policycontrol.value=baselinepreservesequenceorder;",
        ):
            self.assertIn(reset, compact)
        self.assertIn(
            "orderingmodel(delaycontrol.value,capacitycontrol.value,"
            "timeoutcontrol.value,availabilitycontrol.value,policycontrol.value)",
            compact,
        )
        self.assertIn(
            "receivedsequence=current.sequence(current.receivedmask);", compact
        )
        self.assertIn(
            "receivedarrivaltimems=current.arrivaltimems(current.receivedmask);",
            compact,
        )
        self.assertIn("if~current.preservesequenceorder", compact)
        self.assertIn("rawarrivaldelivery,inorderbychance", compact)

    def test_tutor_text_checks_and_malformed_recovery_are_complete(self) -> None:
        tutor_names = ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8") for name in tutor_names
        )
        lowered = combined.lower()
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        for concept in (
            "p09",
            "p11",
            "t_arrive",
            "sequence",
            "single-sender",
            "arrival order",
            "inversion",
            "reorder buffer",
            "message-ms",
            "head-of-line",
            "finite",
            "gap deadline",
            "timeout",
            "cancellation",
            "rollback",
            "recovery",
            "causal order",
            "global total order",
            "consensus",
            "interpretation",
            "teach-back",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 140)
        for marker in (
            "baseline",
            "repeated",
            "typed",
            "fractional",
            "explicitTieRule",
            "delayScales",
            "bufferCapacities",
            "zeroDelay",
            "naiveZeroDelay",
            "capacityAboveNeed",
            "zeroCapacity",
            "oneSlotOverflow",
            "exactGapBoundary",
            "justBeforeGapBoundary",
            "zeroGapTimeout",
            "shortGapTimeout",
            "missingMessage",
            "broken",
            "brokenMissing",
            "recoveryAfterTimeout",
            "recoveryAfterOverflow",
            "bounded",
            "boundedMissing",
            "assertThrows",
            "recoveredAfterMalformed",
            "P10 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P10:InvalidDelayScale",
            "P10:InvalidBufferCapacity",
            "P10:InvalidGapTimeout",
            "P10:InvalidMessageAvailability",
            "P10:InvalidOrderingPolicy",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
