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
FOLDER = ROOT / "modules/07-model-ptp-hardware-timestamping"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you model "
    "PTP Hardware Timestamping?"
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
SOFTWARE_BASE_NS = (600.0, 800.0, 500.0, 700.0)
SOFTWARE_SHAPE = (
    (0, 1, 2, 1, 3, 1, 4, 2),
    (1, 3, 0, 4, 1, 2, 3, 0),
    (2, 0, 3, 1, 4, 2, 1, 3),
    (0, 2, 1, 3, 0, 4, 2, 1),
)
PIPELINE_NS = (-20.0, 80.0, -20.0, 20.0)


def round_half_away_from_zero(value: float) -> int:
    """Apply P07's explicit nearest-integer rule with signed ties away from zero."""
    if value >= 0:
        return math.floor(value + 0.5)
    return math.ceil(value - 0.5)


def reference_timestamping(
    start_time_ns: float = 100000,
    clock_offset_ns: float = 120,
    forward_delay_ns: float = 800,
    reverse_delay_ns: float = 800,
    follower_turnaround_ns: float = 4000,
    host_latency_scale: float = 1,
    hardware_tick_ns: float = 8,
    calibration_fraction: float = 1,
) -> dict[str, object]:
    """Independent capture-plane arithmetic for retained static evidence."""
    exchange_starts = [start_time_ns + index * 20003 for index in range(8)]
    ideal_by_exchange: list[list[float]] = []
    software_by_exchange: list[list[float]] = []
    hardware_by_exchange: list[list[float]] = []
    software_error_by_exchange: list[list[float]] = []
    hardware_error_by_exchange: list[list[float]] = []
    quantization_error_by_exchange: list[list[float]] = []

    for index, exchange_start in enumerate(exchange_starts):
        ideal = [
            exchange_start,
            exchange_start + forward_delay_ns + clock_offset_ns,
            exchange_start
            + forward_delay_ns
            + follower_turnaround_ns
            + clock_offset_ns,
            exchange_start
            + forward_delay_ns
            + follower_turnaround_ns
            + reverse_delay_ns,
        ]
        host_latency = [
            host_latency_scale
            * (SOFTWARE_BASE_NS[event] + 100 * SOFTWARE_SHAPE[event][index])
            for event in range(4)
        ]
        software_error = [
            -host_latency[0],
            host_latency[1],
            -host_latency[2],
            host_latency[3],
        ]
        software = [
            value + error for value, error in zip(ideal, software_error)
        ]
        raw_hardware = [
            value + placement for value, placement in zip(ideal, PIPELINE_NS)
        ]
        quantized = [
            hardware_tick_ns * round_half_away_from_zero(value / hardware_tick_ns)
            for value in raw_hardware
        ]
        quantization_error = [
            captured - raw
            for captured, raw in zip(quantized, raw_hardware)
        ]
        correction = [
            -calibration_fraction * placement for placement in PIPELINE_NS
        ]
        hardware = [
            captured + adjustment
            for captured, adjustment in zip(quantized, correction)
        ]
        hardware_error = [
            captured - value for captured, value in zip(hardware, ideal)
        ]
        ideal_by_exchange.append(ideal)
        software_by_exchange.append(software)
        hardware_by_exchange.append(hardware)
        software_error_by_exchange.append(software_error)
        hardware_error_by_exchange.append(hardware_error)
        quantization_error_by_exchange.append(quantization_error)

    def estimates(matrix: list[list[float]]) -> tuple[list[float], list[float]]:
        offsets = [
            ((stamp[1] - stamp[0]) + (stamp[2] - stamp[3])) / 2
            for stamp in matrix
        ]
        round_trips = [
            (stamp[3] - stamp[0]) - (stamp[2] - stamp[1])
            for stamp in matrix
        ]
        return offsets, round_trips

    ideal_offset, ideal_round_trip = estimates(ideal_by_exchange)
    software_offset, software_round_trip = estimates(software_by_exchange)
    hardware_offset, hardware_round_trip = estimates(hardware_by_exchange)
    true_round_trip = forward_delay_ns + reverse_delay_ns
    hardware_quantization_offset = [
        (error[1] - error[0] + error[2] - error[3]) / 2
        for error in quantization_error_by_exchange
    ]
    hardware_quantization_round_trip = [
        error[3] - error[0] - error[2] + error[1]
        for error in quantization_error_by_exchange
    ]
    return {
        "exchange_starts": exchange_starts,
        "ideal": ideal_by_exchange,
        "software": software_by_exchange,
        "hardware": hardware_by_exchange,
        "software_error": software_error_by_exchange,
        "hardware_error": hardware_error_by_exchange,
        "quantization_error": quantization_error_by_exchange,
        "ideal_offset": ideal_offset,
        "ideal_round_trip": ideal_round_trip,
        "software_offset": software_offset,
        "software_round_trip": software_round_trip,
        "hardware_offset": hardware_offset,
        "hardware_round_trip": hardware_round_trip,
        "software_offset_range": max(software_offset) - min(software_offset),
        "hardware_offset_range": max(hardware_offset) - min(hardware_offset),
        "software_round_trip_range": max(software_round_trip)
        - min(software_round_trip),
        "hardware_round_trip_range": max(hardware_round_trip)
        - min(hardware_round_trip),
        "software_max_offset_error": max(
            abs(value - clock_offset_ns) for value in software_offset
        ),
        "hardware_max_offset_error": max(
            abs(value - clock_offset_ns) for value in hardware_offset
        ),
        "software_max_round_trip_error": max(
            abs(value - true_round_trip) for value in software_round_trip
        ),
        "hardware_max_round_trip_error": max(
            abs(value - true_round_trip) for value in hardware_round_trip
        ),
        "hardware_quantization_offset": hardware_quantization_offset,
        "hardware_quantization_round_trip": hardware_quantization_round_trip,
        "true_round_trip": true_round_trip,
    }


class P07ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P07")

    def assert_float_lists_equal(
        self, actual: list[float], expected: list[float], tolerance: float = 1e-9
    ) -> None:
        self.assertEqual(len(actual), len(expected))
        for index, (left, right) in enumerate(zip(actual, expected)):
            with self.subTest(index=index):
                self.assertTrue(math.isclose(left, right, abs_tol=tolerance, rel_tol=0))

    def test_permanent_manifest_identity_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 7)
        self.assertEqual(self.module["id"], "P07")
        self.assertEqual(self.module["title"], "Model PTP Hardware Timestamping")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 2)
        self.assertEqual(self.module["phase_title"], "Time and synchronization")
        self.assertEqual(self.module["slug"], "model-ptp-hardware-timestamping")
        self.assertEqual(self.module["prerequisites"], ["P06"])
        self.assertEqual(self.module["implementation_batch"], "P07")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p07_checks(self) -> None:
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

            started = run_cli("start", "P07")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P07 — Model PTP Hardware Timestamping", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P07')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P07")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P07 — Model PTP Hardware Timestamping", continued.stdout)
            checked = run_cli("check", "P07")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P07')\n")

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
        experiment_lower = experiment.lower()
        experiment_compact = re.sub(r"\s+", "", experiment_lower).replace("...", "")
        self.assertNotIn("close all", experiment_lower)
        self.assertNotRegex(experiment_lower, r"(?m)^\s*clc\s*;")
        self.assertIn("experimentfiguretag='p07experimentfigure';", experiment_compact)
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
        self.assertIn("interactivefiguretag='p07interactivefigure';", interactive_compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            interactive_compact,
        )
        self.assertIn("close(existingwindows);", interactive_compact)
        self.assertEqual(interactive_compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_limits_and_broken_case(self) -> None:
        baseline = reference_timestamping()
        self.assertEqual(baseline["ideal"][0], [100000, 100920, 104920, 105600])
        self.assertEqual(
            baseline["software_offset"],
            [170, 320, 120, 270, 220, 70, 420, 120],
        )
        self.assertEqual(
            baseline["hardware_offset"],
            [118, 118, 122, 118, 122, 122, 118, 122],
        )
        self.assertEqual(
            baseline["software_round_trip"],
            [4500, 4800, 4800, 5100, 5000, 5100, 5200, 4800],
        )
        self.assertEqual(
            baseline["hardware_round_trip"],
            [1596, 1596, 1604, 1596, 1604, 1604, 1596, 1604],
        )
        self.assertEqual(
            (
                baseline["software_offset_range"],
                baseline["hardware_offset_range"],
                baseline["software_max_offset_error"],
                baseline["hardware_max_offset_error"],
            ),
            (350, 4, 300, 2),
        )
        self.assertEqual(
            (
                baseline["software_round_trip_range"],
                baseline["hardware_round_trip_range"],
                baseline["software_max_round_trip_error"],
                baseline["hardware_max_round_trip_error"],
            ),
            (700, 8, 3600, 4),
        )

        fractional = reference_timestamping(
            start_time_ns=100.5,
            clock_offset_ns=-0.5,
            forward_delay_ns=1.25,
            reverse_delay_ns=1.25,
            follower_turnaround_ns=10.5,
            host_latency_scale=0,
            hardware_tick_ns=0.5,
            calibration_fraction=1,
        )
        self.assertEqual(fractional["software_offset"], [-0.5] * 8)
        self.assertEqual(fractional["hardware_offset"], [-0.25] * 8)
        self.assertEqual(fractional["software_round_trip"], [2.5] * 8)
        self.assertEqual(fractional["hardware_round_trip"], [2.5] * 8)

        host_cases = [
            reference_timestamping(host_latency_scale=value) for value in (0, 1, 2)
        ]
        self.assertEqual(
            [case["software_offset_range"] for case in host_cases], [0, 350, 700]
        )
        self.assertEqual(
            [case["software_max_offset_error"] for case in host_cases],
            [0, 300, 600],
        )
        self.assertEqual(
            [case["software_max_round_trip_error"] for case in host_cases],
            [0, 3600, 7200],
        )
        self.assertEqual(
            [case["hardware_offset_range"] for case in host_cases], [4, 4, 4]
        )

        tick_cases = [
            reference_timestamping(hardware_tick_ns=value) for value in (1, 8, 64)
        ]
        self.assertEqual(
            [case["hardware_offset_range"] for case in tick_cases], [0, 4, 32]
        )
        self.assertEqual(
            [case["hardware_max_offset_error"] for case in tick_cases], [0, 2, 22]
        )
        self.assertEqual(
            [case["hardware_round_trip_range"] for case in tick_cases], [0, 8, 64]
        )
        self.assertEqual(
            [case["hardware_max_round_trip_error"] for case in tick_cases],
            [0, 4, 52],
        )
        self.assertTrue(
            all(case["software_offset"] == baseline["software_offset"] for case in tick_cases)
        )

        broken = reference_timestamping(hardware_tick_ns=1, calibration_fraction=0)
        overcorrected = reference_timestamping(
            hardware_tick_ns=1, calibration_fraction=2
        )
        self.assertEqual(broken["hardware_offset"], [150] * 8)
        self.assertEqual(broken["hardware_round_trip"], [1740] * 8)
        self.assertEqual(broken["hardware_offset_range"], 0)
        self.assertEqual(overcorrected["hardware_offset"], [90] * 8)
        self.assertEqual(overcorrected["hardware_round_trip"], [1460] * 8)

        forward_dominant = reference_timestamping(
            forward_delay_ns=1200,
            reverse_delay_ns=400,
            host_latency_scale=0,
            hardware_tick_ns=1,
        )
        reverse_dominant = reference_timestamping(
            forward_delay_ns=400,
            reverse_delay_ns=1200,
            host_latency_scale=0,
            hardware_tick_ns=1,
        )
        self.assertEqual(forward_dominant["hardware_offset"], [520] * 8)
        self.assertEqual(reverse_dominant["hardware_offset"], [-280] * 8)
        self.assertEqual(forward_dominant["hardware_round_trip"], [1600] * 8)
        self.assertEqual(reverse_dominant["hardware_round_trip"], [1600] * 8)

        for tick in (0.125, 1, 8, 64, 1024):
            with self.subTest(tick=tick):
                case = reference_timestamping(hardware_tick_ns=tick)
                quantization = [
                    value
                    for exchange in case["quantization_error"]
                    for value in exchange
                ]
                self.assertLessEqual(max(abs(value) for value in quantization), tick / 2)
                self.assertLessEqual(
                    max(abs(value) for value in case["hardware_quantization_offset"]),
                    tick,
                )
                self.assertLessEqual(
                    max(
                        abs(value)
                        for value in case["hardware_quantization_round_trip"]
                    ),
                    2 * tick,
                )

        bounded = reference_timestamping(
            start_time_ns=1_000_000,
            clock_offset_ns=1_000_000,
            forward_delay_ns=1_000_000,
            reverse_delay_ns=1_000_000,
            follower_turnaround_ns=1_000_000,
            host_latency_scale=4,
            hardware_tick_ns=1024,
            calibration_fraction=2,
        )
        self.assertEqual(len(bounded["hardware"]), 8)
        self.assertEqual(sum(len(exchange) for exchange in bounded["hardware"]), 32)
        self.assertTrue(
            all(
                math.isfinite(value)
                for matrix_name in ("ideal", "software", "hardware")
                for exchange in bounded[matrix_name]
                for value in exchange
            )
        )

    def test_signed_half_tick_quantization_matches_declared_rule(self) -> None:
        signed_half_tick = reference_timestamping(
            start_time_ns=0,
            clock_offset_ns=0,
            forward_delay_ns=0,
            reverse_delay_ns=0,
            follower_turnaround_ns=0,
            host_latency_scale=0,
            hardware_tick_ns=8,
            calibration_fraction=1,
        )
        self.assertEqual(signed_half_tick["ideal"][0], [0, 0, 0, 0])
        self.assertEqual(signed_half_tick["quantization_error"][0], [-4, 0, -4, 4])
        self.assertEqual(signed_half_tick["hardware"][0], [-4, 0, -4, 4])
        self.assertEqual(
            [round_half_away_from_zero(value) for value in (-2.5, -0.5, 0.5, 2.5)],
            [-3, -1, 1, 3],
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(starttimens,clockoffsetns,forwarddelayns,reversedelayns,"
            "followerturnaroundns,hostlatencyscale,hardwaretickns,calibrationfraction)",
            compact,
        )
        for formula in (
            "exchangecount=8;",
            "timestampsperexchange=4;",
            "exchangeperiodns=20003;",
            "idealreferenceplanetimestampns(2:3,:)=idealreferenceplanetimestampns(2:3,:)+clockoffsetns;",
            "softwarehostlatencyns=hostlatencyscale*(repmat(softwarebaselatencyns,1,exchangecount)+softwarevariationunitns*softwarelatencyshape);",
            "softwaretimestampplacementerrorns=[-softwarehostlatencyns(1,:);softwarehostlatencyns(2,:);-softwarehostlatencyns(3,:);softwarehostlatencyns(4,:)];",
            "hardwarepipelineoffsetns=[-20;80;-20;20];",
            "hardwarefullcorrectionns=-hardwarepipelineoffsetns;",
            "quantizedrawhardwaretimestampns=hardwaretickns*round(rawhardwaretimestampns/hardwaretickns);",
            "configuredhardwarecorrectionns=calibrationfraction*repmat(hardwarefullcorrectionns,1,exchangecount);",
            "hardwareestimatedclockoffsetns=(hardwareforwardoffsettermns+hardwarereverseoffsettermns)/2;",
            "hardwareestimatedroundtripdelayns=(hardwaretimestampns(4,:)-hardwaretimestampns(1,:))-(hardwaretimestampns(3,:)-hardwaretimestampns(2,:));",
            "expectedidealclockoffsetestimatens=clockoffsetns+pathasymmetryns/2;",
            "hardwarequantizationperstampboundns=hardwaretickns/2;",
            "hardwarequantizationoffsetboundns=hardwaretickns;",
            "hardwarequantizationroundtripboundns=2*hardwaretickns;",
            "maxtimestampcount=exchangecount*timestampsperexchange;",
            "maxderivedtimestampmagnitudens=6e6;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "starttimens=double(starttimens);",
            "clockoffsetns=double(clockoffsetns);",
            "forwarddelayns=double(forwarddelayns);",
            "reversedelayns=double(reversedelayns);",
            "followerturnaroundns=double(followerturnaroundns);",
            "hostlatencyscale=double(hostlatencyscale);",
            "hardwaretickns=double(hardwaretickns);",
            "calibrationfraction=double(calibrationfraction);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P07:InvalidStartTime",
            "P07:InvalidClockOffset",
            "P07:InvalidForwardDelay",
            "P07:InvalidReverseDelay",
            "P07:InvalidFollowerTurnaround",
            "P07:InvalidHostLatencyScale",
            "P07:InvalidHardwareTick",
            "P07:InvalidCalibrationFraction",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.pathSymmetryRequiredForUnbiasedOffset = true;",
            "out.consistentReferencePlaneRequired = true;",
            "out.precisionDoesNotProveAccuracy = true;",
            "out.truthAvailableForTeachingOnly = true;",
            "out.hardwareTimestampPlacementModeled = true;",
            "out.fullPtpProtocolModeled = false;",
            "out.timestampCorrelationModeled = false;",
            "out.networkIoPerformed = false;",
            "out.physicalHardwareUsed = false;",
            "out.phcReadPerformed = false;",
            "out.clockAdjustmentPerformed = false;",
            "out.timeoutModeled = false;",
            "out.cancellationModeled = false;",
            "out.actualWaitPerformed = false;",
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
            "hostlatencyscales = [0 1 2]",
            "hardwareticksns = [1 8 64]",
            "baseline = model(100000,120,800,800,4000,1,8,1)",
            "broken = model(100000,120,800,800,4000,1,1,0)",
            "not measurements from a nic or clock",
        ):
            self.assertIn(marker, lowered)
        for label in (
            "estimated follower-minus-leader offset (ns)",
            "captured timestamp minus reference-plane timestamp (ns)",
            "host timestamp-path latency scale (dimensionless)",
            "maximum absolute round-trip error (ns)",
            "hardware timestamp tick (ns)",
            "hardware offset estimate (ns)",
            "timestamp error at modeled reference plane (ns)",
        ):
            self.assertIn(label, lowered)
        self.assertIn(
            "isequal(broken.hardwareestimatedclockoffsetns,150*ones(1,8))",
            compact,
        )

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        interactive_lower = interactive.lower()
        interactive_compact = re.sub(r"\s+", "", interactive_lower).replace("...", "")
        self.assertIn("uifigure", interactive_lower)
        self.assertEqual(interactive_lower.count("uispinner"), 4)
        self.assertIn("timestampmodel=@model;", interactive_compact)
        self.assertIn("reset baseline", interactive_lower)
        self.assertGreaterEqual(interactive_lower.count("valuechangedfcn"), 4)
        self.assertIn("truth diagnostic: asymmetric wire path", interactive_lower)
        for setting in (
            "'limits',[02],'value',baselinehostlatencyscale,'step',0.25",
            "'limits',[1128],'value',baselinehardwaretickns,'step',1",
            "'limits',[01.5],'value',baselinecalibrationfraction,'step',0.1",
            "'limits',[01600],'value',baselinereversedelayns,'step',100",
        ):
            self.assertIn(setting, interactive_compact)
        for control in (
            "host timestamp-path scale",
            "hardware timestamp tick",
            "reference-plane calibration fraction",
            "reverse wire delay",
        ):
            self.assertIn(control, interactive_lower)
        for reset in (
            "hostcontrol.value=baselinehostlatencyscale;",
            "tickcontrol.value=baselinehardwaretickns;",
            "calibrationcontrol.value=baselinecalibrationfraction;",
            "reversecontrol.value=baselinereversedelayns;",
        ):
            self.assertIn(reset, interactive_compact)
        self.assertIn(
            "timestampmodel(starttimens,clockoffsetns,forwarddelayns,"
            "reversecontrol.value,followerturnaroundns,hostcontrol.value,"
            "tickcontrol.value,calibrationcontrol.value)",
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
            "p06",
            "t1",
            "t2",
            "t3",
            "t4",
            "follower clock - leader clock",
            "reference plane",
            "software",
            "hardware",
            "host-path",
            "tick",
            "quantization",
            "calibration",
            "egress",
            "ingress",
            "precision",
            "accuracy",
            "path asymmetry",
            "interpretation",
            "teach-back",
            "timeout",
            "cancellation",
            "ties away from zero",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        for marker in (
            "defaulted",
            "repeated",
            "shifted",
            "typed",
            "fractional",
            "signedHalfTick",
            "hostLatencyScales",
            "zeroHostPath",
            "hardwareTicksNs",
            "fineCalibrated",
            "turnaroundValuesNs",
            "zeroEverything",
            "forwardDominant",
            "reverseDominant",
            "broken",
            "overcorrected",
            "quantizationTicksNs",
            "bounded",
            "boundedNegative",
            "assertThrows",
            "recovered",
            "P07 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P07:InvalidStartTime",
            "P07:InvalidClockOffset",
            "P07:InvalidForwardDelay",
            "P07:InvalidReverseDelay",
            "P07:InvalidFollowerTurnaround",
            "P07:InvalidHostLatencyScale",
            "P07:InvalidHardwareTick",
            "P07:InvalidCalibrationFraction",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
