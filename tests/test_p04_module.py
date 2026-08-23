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
FOLDER = ROOT / "modules/04-build-a-queue-and-watch-latency-grow"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you build a "
    "Queue and Watch Latency Grow?"
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


def reference_queue(
    message_count: int = 12,
    arrival_period_ms: float = 4,
    service_time_ms: float = 6,
    capacity_messages: int = 4,
    deadline_ms: float = 20,
    release_batch_messages: int = 1,
) -> dict[str, object]:
    """Independent bounded FIFO arithmetic for retained static evidence."""
    arrivals = [index * arrival_period_ms for index in range(message_count)]
    release_start = message_count - 1
    release_end = message_count - 1
    if release_batch_messages > 1:
        if release_batch_messages < message_count:
            release_end = message_count - 2
        release_start = release_end - release_batch_messages + 1
        for index in range(release_start, release_end + 1):
            arrivals[index] = arrivals[release_end]

    time_scale = max(
        1,
        (message_count - 1) * arrival_period_ms
        + message_count * service_time_ms,
        deadline_ms,
    )
    tolerance = 64 * math.ulp(float(time_scale))
    accepted = [False] * message_count
    dropped = [False] * message_count
    starts = [math.nan] * message_count
    departures = [math.nan] * message_count
    waiting = [math.nan] * message_count
    latency = [math.nan] * message_count
    unfinished_before: list[int] = []
    occupancy_after: list[int] = []
    last_departure = 0.0
    has_accepted = False
    comparisons = 0

    for index, arrival in enumerate(arrivals):
        unfinished = 0
        for prior in range(index):
            comparisons += 1
            if accepted[prior] and departures[prior] > arrival + tolerance:
                unfinished += 1
        unfinished_before.append(unfinished)
        if unfinished >= capacity_messages:
            dropped[index] = True
            occupancy_after.append(unfinished)
            continue

        accepted[index] = True
        if has_accepted and last_departure > arrival + tolerance:
            start = last_departure
        else:
            start = arrival
        departure = start + service_time_ms
        wait = start - arrival
        if wait <= tolerance:
            wait = 0.0
        starts[index] = start
        departures[index] = departure
        waiting[index] = wait
        latency[index] = departure - arrival
        last_departure = departure
        has_accepted = True
        occupancy_after.append(unfinished + 1)

    on_time = [
        accepted[index] and latency[index] <= deadline_ms + tolerance
        for index in range(message_count)
    ]
    late = [accepted[index] and not on_time[index] for index in range(message_count)]
    accepted_latency = [latency[index] for index in range(message_count) if accepted[index]]
    accepted_waiting = [waiting[index] for index in range(message_count) if accepted[index]]
    accepted_departures = [
        departures[index] for index in range(message_count) if accepted[index]
    ]
    observation_end = max(arrivals[-1], *accepted_departures)
    observation_horizon = observation_end - arrivals[0]
    return {
        "arrivals": arrivals,
        "accepted": accepted,
        "dropped": dropped,
        "starts": starts,
        "departures": departures,
        "waiting": waiting,
        "latency": latency,
        "unfinished_before": unfinished_before,
        "occupancy_after": occupancy_after,
        "on_time": on_time,
        "late": late,
        "accepted_count": sum(accepted),
        "dropped_count": sum(dropped),
        "on_time_count": sum(on_time),
        "late_count": sum(late),
        "max_waiting": max(accepted_waiting),
        "max_latency": max(accepted_latency),
        "mean_waiting": sum(accepted_waiting) / len(accepted_waiting),
        "mean_latency": sum(accepted_latency) / len(accepted_latency),
        "utilization": service_time_ms / arrival_period_ms,
        "peak_occupancy": max(occupancy_after),
        "observation_horizon": observation_horizon,
        "busy_time": sum(accepted) * service_time_ms,
        "system_time_area": sum(accepted_latency),
        "comparisons": comparisons,
        "release_start": release_start,
        "release_end": release_end,
    }


class P04ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P04")

    def assert_float_lists_equal(
        self, actual: list[float], expected: list[float], tolerance: float = 1e-9
    ) -> None:
        self.assertEqual(len(actual), len(expected))
        for index, (left, right) in enumerate(zip(actual, expected)):
            with self.subTest(index=index):
                if math.isnan(right):
                    self.assertTrue(math.isnan(left))
                else:
                    self.assertTrue(math.isclose(left, right, abs_tol=tolerance, rel_tol=0))

    def test_permanent_manifest_identity_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 4)
        self.assertEqual(self.module["id"], "P04")
        self.assertEqual(self.module["title"], "Build a Queue and Watch Latency Grow")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 1)
        self.assertEqual(self.module["phase_title"], "Network behavior")
        self.assertEqual(self.module["slug"], "build-a-queue-and-watch-latency-grow")
        self.assertEqual(self.module["prerequisites"], ["P03"])
        self.assertEqual(self.module["implementation_batch"], "P04")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p04_checks(self) -> None:
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

            started = run_cli("start", "P04")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P04 — Build a Queue and Watch Latency Grow", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P04')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P04")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P04 — Build a Queue and Watch Latency Grow", continued.stdout)
            checked = run_cli("check", "P04")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P04')\n")

    def test_changed_text_artifacts_have_one_terminal_newline(self) -> None:
        for name in ARTIFACTS:
            with self.subTest(name=name):
                content = (FOLDER / name).read_bytes()
                self.assertTrue(content.endswith(b"\n"), name)
                self.assertFalse(content.endswith(b"\n\n"), name)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_queue()
        self.assertEqual(baseline["arrivals"], list(range(0, 48, 4)))
        self.assertEqual(
            baseline["accepted"],
            [True, True, True, True, True, True, True, True, True, True, False, True],
        )
        self.assert_float_lists_equal(
            list(baseline["starts"]),
            [0, 6, 12, 18, 24, 30, 36, 42, 48, 54, math.nan, 60],
        )
        self.assert_float_lists_equal(
            list(baseline["departures"]),
            [6, 12, 18, 24, 30, 36, 42, 48, 54, 60, math.nan, 66],
        )
        self.assert_float_lists_equal(
            list(baseline["waiting"]),
            [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, math.nan, 16],
        )
        self.assert_float_lists_equal(
            list(baseline["latency"]),
            [6, 8, 10, 12, 14, 16, 18, 20, 22, 24, math.nan, 22],
        )
        self.assertEqual(baseline["unfinished_before"], [0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 3])
        self.assertEqual(baseline["occupancy_after"], [1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4, 4])
        self.assertEqual(
            (
                baseline["accepted_count"],
                baseline["dropped_count"],
                baseline["on_time_count"],
                baseline["late_count"],
            ),
            (11, 1, 8, 3),
        )
        self.assertEqual((baseline["max_waiting"], baseline["max_latency"]), (18, 24))
        self.assertTrue(math.isclose(float(baseline["mean_waiting"]), 106 / 11))
        self.assertTrue(math.isclose(float(baseline["mean_latency"]), 172 / 11))
        self.assertEqual(
            (
                baseline["observation_horizon"],
                baseline["busy_time"],
                baseline["system_time_area"],
            ),
            (66, 66, 172),
        )
        self.assertEqual(baseline["accepted_count"] + baseline["dropped_count"], 12)
        self.assertLessEqual(int(baseline["peak_occupancy"]), 4)
        self.assertTrue(math.isnan(list(baseline["latency"])[10]))
        self.assertEqual(list(baseline["departures"])[11], 66)

        for index, accepted in enumerate(baseline["accepted"]):
            if accepted:
                self.assertGreaterEqual(baseline["starts"][index], baseline["arrivals"][index])
                self.assertEqual(
                    baseline["departures"][index], baseline["starts"][index] + 6
                )
                self.assertEqual(
                    baseline["latency"][index], baseline["waiting"][index] + 6
                )
        accepted_departures = [
            baseline["departures"][index]
            for index, accepted in enumerate(baseline["accepted"])
            if accepted
        ]
        self.assertTrue(
            all(left < right for left, right in zip(accepted_departures, accepted_departures[1:]))
        )

        arrival_cases = [reference_queue(arrival_period_ms=value) for value in (4, 6, 8)]
        self.assertEqual([case["utilization"] for case in arrival_cases], [1.5, 1, 0.75])
        self.assertEqual([case["on_time_count"] for case in arrival_cases], [8, 12, 12])
        self.assertEqual([case["dropped_count"] for case in arrival_cases], [1, 0, 0])
        self.assertEqual([case["max_latency"] for case in arrival_cases], [24, 6, 6])

        capacity_cases = [reference_queue(capacity_messages=value) for value in (1, 2, 4, 8)]
        self.assertEqual([case["on_time_count"] for case in capacity_cases], [6, 9, 8, 8])
        self.assertEqual([case["late_count"] for case in capacity_cases], [0, 0, 3, 4])
        self.assertEqual([case["dropped_count"] for case in capacity_cases], [6, 3, 1, 0])
        self.assertEqual([case["max_latency"] for case in capacity_cases], [6, 12, 24, 28])

        underloaded = reference_queue(8, 8, 6, 1, 6, 1)
        critical = reference_queue(8, 6, 6, 1, 6, 1)
        self.assertEqual(underloaded["waiting"], [0] * 8)
        self.assertEqual(critical["waiting"], [0] * 8)
        self.assertEqual((underloaded["dropped_count"], critical["dropped_count"]), (0, 0))
        one_record = reference_queue(1, 100, 6, 1, 6, 1)
        self.assertEqual(
            (one_record["accepted_count"], one_record["waiting"], one_record["latency"]),
            (1, [0], [6]),
        )

        deadline_equal = reference_queue(3, 4, 6, 8, 10, 1)
        deadline_below = reference_queue(3, 4, 6, 8, 9.999, 1)
        self.assertEqual((deadline_equal["on_time_count"], deadline_below["on_time_count"]), (3, 2))
        self.assertEqual(deadline_equal["departures"], deadline_below["departures"])

        large = reference_queue(64, 1_000_000, 1_000_000, 1, 1_000_000, 1)
        self.assertEqual(large["waiting"], [0] * 64)
        self.assertEqual((large["accepted_count"], large["on_time_count"]), (64, 64))
        bounded = reference_queue(64, 1, 64, 64, 1000, 8)
        self.assertEqual((bounded["accepted_count"], bounded["peak_occupancy"]), (64, 64))
        self.assertEqual(bounded["comparisons"], 2016)

    def test_broken_release_burst_is_transient_not_average_overload(self) -> None:
        smooth = reference_queue(8, 10, 6, 8, 15, 1)
        broken = reference_queue(8, 10, 6, 8, 15, 4)
        self.assertEqual(smooth["utilization"], broken["utilization"])
        self.assertLess(float(broken["utilization"]), 1)
        self.assertEqual(broken["arrivals"], [0, 10, 20, 60, 60, 60, 60, 70])
        self.assertEqual(broken["waiting"], [0, 0, 0, 0, 6, 12, 18, 14])
        self.assertEqual(broken["latency"], [6, 6, 6, 6, 12, 18, 24, 20])
        self.assertEqual(
            (
                smooth["dropped_count"],
                broken["dropped_count"],
                smooth["late_count"],
                broken["late_count"],
                smooth["max_latency"],
                broken["max_latency"],
            ),
            (0, 0, 0, 3, 6, 24),
        )

    def test_equal_time_burst_overflow_tail_drops_and_recovers(self) -> None:
        overflow = reference_queue(8, 10, 6, 2, 15, 4)
        self.assertEqual(overflow["arrivals"], [0, 10, 20, 60, 60, 60, 60, 70])
        self.assertEqual(
            overflow["accepted"],
            [True, True, True, True, True, False, False, True],
        )
        self.assertEqual(
            overflow["dropped"],
            [False, False, False, False, False, True, True, False],
        )
        self.assert_float_lists_equal(
            list(overflow["starts"]),
            [0, 10, 20, 60, 66, math.nan, math.nan, 72],
        )
        self.assert_float_lists_equal(
            list(overflow["departures"]),
            [6, 16, 26, 66, 72, math.nan, math.nan, 78],
        )
        self.assert_float_lists_equal(
            list(overflow["waiting"]),
            [0, 0, 0, 0, 6, math.nan, math.nan, 2],
        )
        self.assert_float_lists_equal(
            list(overflow["latency"]),
            [6, 6, 6, 6, 12, math.nan, math.nan, 8],
        )
        self.assertEqual(overflow["unfinished_before"], [0, 0, 0, 0, 1, 2, 2, 1])
        self.assertEqual(overflow["occupancy_after"], [1, 1, 1, 1, 2, 2, 2, 2])
        self.assertEqual(
            (
                overflow["accepted_count"],
                overflow["dropped_count"],
                overflow["on_time_count"],
                overflow["late_count"],
                overflow["peak_occupancy"],
            ),
            (6, 2, 6, 0, 2),
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", source).lower().replace("...", "")
        self.assertIn(
            "function out = model(messageCount,arrivalPeriodMs,serviceTimeMs,"
            "capacityMessages,deadlineMs,releaseBatchMessages)",
            source,
        )
        for formula in (
            "maxmessagecount=64;",
            "maxcapacitymessages=64;",
            "maxreleasebatchmessages=8;",
            "arrivaltimems=(recordindex-1)*arrivalperiodms;",
            "unfinishedcount>=capacitymessages",
            "servicestarttimems(arrivalindex)=lastaccepteddeparturems;",
            "departuretimems(arrivalindex)=servicestarttimems(arrivalindex)+servicetimems;",
            "waitingtimems(arrivalindex)=servicestarttimems(arrivalindex)-arrivaltimems(arrivalindex);",
            "systemlatencyms(arrivalindex)=departuretimems(arrivalindex)-arrivaltimems(arrivalindex);",
            "nominalutilization=servicetimems/arrivalperiodms;",
            "maxadmissioncomparisoncount=maxmessagecount*(maxmessagecount-1)/2;",
            "'tail-drop-on-arrival'",
            "deadlineonlyclassifies=true;",
            "cancellationmodeled=false;",
            "timeoutmodeled=false;",
            "actualwaitperformed=false;",
        ):
            self.assertIn(formula, compact)
        for identifier in (
            "P04:InvalidMessageCount",
            "P04:InvalidArrivalPeriod",
            "P04:InvalidServiceTime",
            "P04:InvalidCapacity",
            "P04:InvalidDeadline",
            "P04:InvalidReleaseBatch",
        ):
            self.assertIn(identifier, source)
        for normalized in (
            "messagecount=double(messagecount);",
            "arrivalperiodms=double(arrivalperiodms);",
            "servicetimems=double(servicetimems);",
            "capacitymessages=double(capacitymessages);",
            "deadlinems=double(deadlinems);",
            "releasebatchmessages=double(releasebatchmessages);",
        ):
            self.assertIn(normalized, compact)
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
            "poissrnd",
            "exprnd",
            "simevents",
            "queueing.",
        ):
            self.assertNotIn(opaque, source.lower())

    def test_experiment_has_two_sweeps_views_metrics_and_broken_case(self) -> None:
        source = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        lowered = source.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertGreaterEqual(source.count("%%"), 7)
        for marker in (
            "deterministic baseline",
            "sweep 1",
            "sweep 2",
            "deliberately broken case",
            "mechanism:",
            "arrivalperiodsms = [4 6 8]",
            "capacityvalues = [1 2 4 8]",
            "baseline = model(12,4,6,4,20,1)",
            "broken = model(8,10,6,8,15,4)",
        ):
            self.assertIn(marker, lowered)
        self.assertGreaterEqual(lowered.count("figure("), 9)
        self.assertGreaterEqual(lowered.count("xlabel("), 8)
        self.assertGreaterEqual(lowered.count("ylabel("), 8)
        self.assertGreaterEqual(lowered.count("title("), 9)
        self.assertGreaterEqual(lowered.count("assert("), 9)
        for unit in ("ms", "records", "count", "utilization"):
            self.assertIn(unit, lowered)
        self.assertIn("plot(arrivalperiodsms,arrivalsweeponTime".lower(), compact)
        self.assertIn("plot(capacityvalues,capacitysweeponTime".lower(), compact)

    def test_interactive_controls_have_meaningful_bounds_and_reset(self) -> None:
        source = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", source).lower().replace("...", "")
        self.assertIn("uifigure", source.lower())
        self.assertEqual(source.lower().count("uispinner"), 4)
        self.assertIn("uicheckbox", source.lower())
        self.assertIn("queuemodel=@model;", compact)
        self.assertIn("'limits',[120],'value',baselineperiodms", compact)
        self.assertIn("'limits',[120],'value',baselineservicems", compact)
        self.assertIn("'limits',[1messagecount],'value',baselinecapacity", compact)
        self.assertIn("'limits',[160],'value',baselinedeadlinems", compact)
        self.assertIn("'roundfractionalvalues','on'", compact)
        self.assertIn("p03 release burst (4)", source.lower())
        self.assertIn("reset baseline", source.lower())
        self.assertGreaterEqual(source.lower().count("valuechangedfcn"), 5)
        self.assertIn(
            "queuemodel(messagecount,periodcontrol.value,servicecontrol.value,"
            "capacitycontrol.value,deadlinecontrol.value,releasebatchmessages)",
            compact,
        )
        for label in (
            "arrival period",
            "service time",
            "capacity incl. service",
            "deadline",
            "unfinished records",
            "system latency",
        ):
            self.assertIn(label, source.lower())

    def test_lesson_checks_and_walkthrough_are_concept_first(self) -> None:
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8")
            for name in ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        )
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        lowered = combined.lower()
        for concept in (
            "p03",
            "fifo",
            "arrival",
            "service",
            "utilization",
            "backlog",
            "waiting",
            "system latency",
            "capacity",
            "drop",
            "deadline",
            "mechanism",
            "interpretation",
            "teach-back",
            "timeout",
            "cancellation",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 35)
        for marker in (
            "defaulted",
            "expectedArrival",
            "expectedWaiting",
            "expectedLatency",
            "underloaded",
            "critical",
            "deadlineEqual",
            "arrivalPeriods",
            "capacityValues",
            "smooth",
            "broken",
            "burstOverflow",
            "largeTimestampBoundary",
            "bounded",
            "typedBounded",
            "assertThrows",
            "recovered",
            "P04 checks passed",
        ):
            self.assertIn(marker, checks)


if __name__ == "__main__":
    unittest.main()
