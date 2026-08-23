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
FOLDER = ROOT / "modules/06-model-ntp-style-exchange"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you model "
    "NTP-Style Exchange?"
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


def reference_exchange(
    client_send_time_ms: float = 100,
    clock_offset_ms: float = 7,
    forward_delay_ms: float = 4,
    reverse_delay_ms: float = 4,
    server_processing_ms: float = 2,
) -> dict[str, object]:
    """Independent four-timestamp arithmetic for retained static evidence."""
    true_event_time = [
        client_send_time_ms,
        client_send_time_ms + forward_delay_ms,
        client_send_time_ms + forward_delay_ms + server_processing_ms,
        client_send_time_ms
        + forward_delay_ms
        + server_processing_ms
        + reverse_delay_ms,
    ]
    timestamps = [
        true_event_time[0],
        true_event_time[1] + clock_offset_ms,
        true_event_time[2] + clock_offset_ms,
        true_event_time[3],
    ]
    forward_term = timestamps[1] - timestamps[0]
    reverse_term = timestamps[2] - timestamps[3]
    client_elapsed = timestamps[3] - timestamps[0]
    server_residence = timestamps[2] - timestamps[1]
    estimated_offset = (forward_term + reverse_term) / 2
    raw_estimated_round_trip = client_elapsed - server_residence
    estimated_round_trip = max(raw_estimated_round_trip, 0)
    estimated_one_way = estimated_round_trip / 2
    true_round_trip = forward_delay_ms + reverse_delay_ms
    asymmetry = forward_delay_ms - reverse_delay_ms
    expected_offset = clock_offset_ms + asymmetry / 2
    return {
        "true_event_time": true_event_time,
        "true_event_elapsed": [value - client_send_time_ms for value in true_event_time],
        "timestamps": timestamps,
        "forward_term": forward_term,
        "reverse_term": reverse_term,
        "client_elapsed": client_elapsed,
        "server_residence": server_residence,
        "estimated_offset": estimated_offset,
        "raw_estimated_round_trip": raw_estimated_round_trip,
        "estimated_round_trip": estimated_round_trip,
        "estimated_one_way": estimated_one_way,
        "true_round_trip": true_round_trip,
        "true_mean_one_way": true_round_trip / 2,
        "asymmetry": asymmetry,
        "offset_error": estimated_offset - clock_offset_ms,
        "forward_inference_error": estimated_one_way - forward_delay_ms,
        "reverse_inference_error": estimated_one_way - reverse_delay_ms,
        "offset_residual": estimated_offset - expected_offset,
        "round_trip_residual": estimated_round_trip - true_round_trip,
        "raw_round_trip_residual": raw_estimated_round_trip - true_round_trip,
        "response_residual": client_elapsed
        - (forward_delay_ms + server_processing_ms + reverse_delay_ms),
        "processing_residual": estimated_round_trip - true_round_trip,
        "round_trip_normalized": raw_estimated_round_trip < 0,
        "symmetric": forward_delay_ms == reverse_delay_ms,
    }


class P06ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P06")

    def test_permanent_manifest_identity_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 6)
        self.assertEqual(self.module["id"], "P06")
        self.assertEqual(self.module["title"], "Model NTP-Style Exchange")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 2)
        self.assertEqual(self.module["phase_title"], "Time and synchronization")
        self.assertEqual(self.module["slug"], "model-ntp-style-exchange")
        self.assertEqual(self.module["prerequisites"], ["P05"])
        self.assertEqual(self.module["implementation_batch"], "P06")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p06_checks(self) -> None:
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

            started = run_cli("start", "P06")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P06 — Model NTP-Style Exchange", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P06')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P06")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P06 — Model NTP-Style Exchange", continued.stdout)
            checked = run_cli("check", "P06")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout, "Run in MATLAB: run_module_checks('P06')\n")

    def test_lesson_entrypoint_runs_baseline_before_live_controls(self) -> None:
        lesson = (FOLDER / "lesson.m").read_text(encoding="utf-8")
        executable_lines = [
            line.strip().lower()
            for line in lesson.splitlines()
            if line.strip() and not line.lstrip().startswith("%")
        ]
        learner_stage_calls = [
            line
            for line in executable_lines
            if line in {"experiment;", "interactive;"}
        ]
        self.assertEqual(learner_stage_calls, ["experiment;", "interactive;"])

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
        self.assertIn("experimentfiguretag='p06experimentfigure';", experiment_compact)
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
        self.assertIn("interactivefiguretag='p06interactivefigure';", interactive_compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',interactivefiguretag);",
            interactive_compact,
        )
        self.assertIn("close(existingwindows);", interactive_compact)
        self.assertEqual(interactive_compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_exchange()
        self.assertEqual(baseline["true_event_time"], [100, 104, 106, 110])
        self.assertEqual(baseline["true_event_elapsed"], [0, 4, 6, 10])
        self.assertEqual(baseline["timestamps"], [100, 111, 113, 110])
        self.assertEqual(
            (
                baseline["forward_term"],
                baseline["reverse_term"],
                baseline["estimated_offset"],
            ),
            (11, 3, 7),
        )
        self.assertEqual(
            (
                baseline["client_elapsed"],
                baseline["server_residence"],
                baseline["estimated_round_trip"],
                baseline["estimated_one_way"],
            ),
            (10, 2, 8, 4),
        )
        self.assertEqual(baseline["true_round_trip"], 8)
        self.assertEqual(baseline["asymmetry"], 0)
        self.assertEqual(baseline["offset_error"], 0)
        self.assertTrue(baseline["symmetric"])
        self.assertEqual(
            [
                baseline["offset_residual"],
                baseline["round_trip_residual"],
                baseline["response_residual"],
                baseline["processing_residual"],
            ],
            [0, 0, 0, 0],
        )

        shifted = reference_exchange(client_send_time_ms=500)
        self.assertEqual(shifted["timestamps"], [value + 400 for value in baseline["timestamps"]])
        self.assertEqual(shifted["estimated_offset"], baseline["estimated_offset"])
        self.assertEqual(shifted["estimated_round_trip"], baseline["estimated_round_trip"])

        offset_cases = [
            reference_exchange(clock_offset_ms=value) for value in (-8, 0, 12)
        ]
        self.assertEqual(
            [case["estimated_offset"] for case in offset_cases], [-8, 0, 12]
        )
        self.assertEqual(
            [case["estimated_round_trip"] for case in offset_cases], [8, 8, 8]
        )
        self.assertEqual([case["client_elapsed"] for case in offset_cases], [10, 10, 10])

        delay_cases = [
            reference_exchange(forward_delay_ms=value, reverse_delay_ms=value)
            for value in (1, 4, 10)
        ]
        self.assertEqual([case["estimated_offset"] for case in delay_cases], [7, 7, 7])
        self.assertEqual(
            [case["estimated_round_trip"] for case in delay_cases], [2, 8, 20]
        )
        self.assertEqual([case["client_elapsed"] for case in delay_cases], [4, 10, 22])

        zero_path = reference_exchange(
            forward_delay_ms=0, reverse_delay_ms=0, server_processing_ms=9
        )
        self.assertEqual(zero_path["timestamps"], [100, 107, 116, 109])
        self.assertEqual(zero_path["estimated_round_trip"], 0)
        self.assertEqual(zero_path["client_elapsed"], zero_path["server_residence"])

        processing_cases = [
            reference_exchange(server_processing_ms=value) for value in (0, 2, 12)
        ]
        self.assertEqual([case["client_elapsed"] for case in processing_cases], [8, 10, 20])
        self.assertEqual([case["estimated_offset"] for case in processing_cases], [7, 7, 7])
        self.assertEqual(
            [case["estimated_round_trip"] for case in processing_cases], [8, 8, 8]
        )

        zero_everything = reference_exchange(
            client_send_time_ms=0,
            clock_offset_ms=0,
            forward_delay_ms=0,
            reverse_delay_ms=0,
            server_processing_ms=0,
        )
        self.assertEqual(zero_everything["timestamps"], [0, 0, 0, 0])
        self.assertEqual(zero_everything["estimated_offset"], 0)
        self.assertEqual(zero_everything["estimated_round_trip"], 0)

        bounded = reference_exchange(
            client_send_time_ms=1_000_000,
            clock_offset_ms=1_000_000,
            forward_delay_ms=1_000_000,
            reverse_delay_ms=1_000_000,
            server_processing_ms=1_000_000,
        )
        self.assertEqual(len(bounded["timestamps"]), 4)
        self.assertEqual(bounded["estimated_offset"], 1_000_000)
        self.assertEqual(bounded["estimated_round_trip"], 2_000_000)
        self.assertTrue(all(math.isfinite(value) for value in bounded["timestamps"]))
        self.assertLessEqual(max(abs(value) for value in bounded["timestamps"]), 4_000_000)

        cancellation_edge = reference_exchange(
            client_send_time_ms=-1_000_000,
            clock_offset_ms=-1_000_000,
            forward_delay_ms=1e-10,
            reverse_delay_ms=0,
            server_processing_ms=1e-6,
        )
        self.assertLess(cancellation_edge["raw_estimated_round_trip"], 0)
        self.assertTrue(cancellation_edge["round_trip_normalized"])
        self.assertEqual(cancellation_edge["estimated_round_trip"], 0)
        self.assertEqual(cancellation_edge["estimated_one_way"], 0)
        self.assertEqual(cancellation_edge["true_round_trip"], 1e-10)
        self.assertLess(abs(cancellation_edge["round_trip_residual"]), 1e-8)
        self.assertLess(abs(cancellation_edge["raw_round_trip_residual"]), 1e-8)

        tiny_asymmetry_at_zero_origin = reference_exchange(
            client_send_time_ms=0,
            clock_offset_ms=0,
            forward_delay_ms=1e-10,
            reverse_delay_ms=0,
            server_processing_ms=0,
        )
        tiny_asymmetry_at_shifted_origin = reference_exchange(
            client_send_time_ms=1_000_000,
            clock_offset_ms=0,
            forward_delay_ms=1e-10,
            reverse_delay_ms=0,
            server_processing_ms=0,
        )
        self.assertFalse(tiny_asymmetry_at_zero_origin["symmetric"])
        self.assertFalse(tiny_asymmetry_at_shifted_origin["symmetric"])
        self.assertEqual(
            tiny_asymmetry_at_zero_origin["asymmetry"],
            tiny_asymmetry_at_shifted_origin["asymmetry"],
        )

        precision_obscured_zero_truth = reference_exchange(
            client_send_time_ms=-1_000_000,
            clock_offset_ms=-1_000_000,
            forward_delay_ms=0,
            reverse_delay_ms=0,
            server_processing_ms=1e-10,
        )
        self.assertGreater(
            precision_obscured_zero_truth["raw_estimated_round_trip"], 0
        )
        self.assertEqual(precision_obscured_zero_truth["true_round_trip"], 0)
        self.assertLess(
            abs(precision_obscured_zero_truth["raw_round_trip_residual"]), 1e-8
        )

    def test_broken_asymmetry_is_exactly_aliased_with_offset(self) -> None:
        broken = reference_exchange(
            clock_offset_ms=7, forward_delay_ms=7, reverse_delay_ms=1
        )
        aliased = reference_exchange(
            clock_offset_ms=10, forward_delay_ms=4, reverse_delay_ms=4
        )
        self.assertEqual(broken["timestamps"], [100, 114, 116, 110])
        self.assertEqual(broken["timestamps"], aliased["timestamps"])
        self.assertEqual(
            (
                broken["asymmetry"],
                broken["estimated_offset"],
                broken["offset_error"],
            ),
            (6, 10, 3),
        )
        self.assertEqual(broken["estimated_round_trip"], 8)
        self.assertEqual(broken["estimated_one_way"], 4)
        self.assertEqual(broken["forward_inference_error"], -3)
        self.assertEqual(broken["reverse_inference_error"], 3)
        self.assertFalse(broken["symmetric"])
        self.assertTrue(aliased["symmetric"])
        self.assertEqual(
            [
                broken["offset_residual"],
                broken["round_trip_residual"],
                broken["response_residual"],
                broken["processing_residual"],
            ],
            [0, 0, 0, 0],
        )

        reverse_dominant = reference_exchange(
            clock_offset_ms=7, forward_delay_ms=1, reverse_delay_ms=7
        )
        self.assertEqual(reverse_dominant["offset_error"], -3)
        self.assertEqual(reverse_dominant["estimated_round_trip"], 8)
        zero_offset = reference_exchange(
            clock_offset_ms=0, forward_delay_ms=7, reverse_delay_ms=1
        )
        self.assertEqual(zero_offset["estimated_offset"], 3)

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "function out = model(clientSendTimeMs,clockOffsetMs,forwardDelayMs,"
            "reverseDelayMs,serverProcessingMs)",
            source,
        )
        for formula in (
            "maxtimemagnitudems=1e6;",
            "maxtimestampcount=4;",
            "maxderivedtimestampmagnitudems=4*maxtimemagnitudems;",
            "trueserverreceivetimems=clientsendtimems+forwarddelayms;",
            "trueservertransmittimems=trueserverreceivetimems+serverprocessingms;",
            "trueclientreceivetimems=trueservertransmittimems+reversedelayms;",
            "t2serverreceivems=trueserverreceivetimems+clockoffsetms;",
            "t3servertransmitms=trueservertransmittimems+clockoffsetms;",
            "forwardoffsettermms=t2serverreceivems-t1clienttransmitms;",
            "reverseoffsettermms=t3servertransmitms-t4clientreceivems;",
            "estimatedclockoffsetms=(forwardoffsettermms+reverseoffsettermms)/2;",
            "rawestimatednetworkroundtripdelayms=clientelapsedms-serverresidencems;",
            "estimatednetworkroundtripdelayms=max(rawestimatednetworkroundtripdelayms,0);",
            "pathasymmetryms=forwarddelayms-reversedelayms;",
            "clockoffseterrorms=estimatedclockoffsetms-clockoffsetms;",
            "expectedoffsetestimatems=clockoffsetms+pathasymmetryms/2;",
            "pathsymmetrysatisfiedintruth=forwarddelayms==reversedelayms;",
            "zeronetworkroundtriplimitintruth=forwarddelayms==0&&reversedelayms==0;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "clientsendtimems=double(clientsendtimems);",
            "clockoffsetms=double(clockoffsetms);",
            "forwarddelayms=double(forwarddelayms);",
            "reversedelayms=double(reversedelayms);",
            "serverprocessingms=double(serverprocessingms);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P06:InvalidClientSendTime",
            "P06:InvalidClockOffset",
            "P06:InvalidForwardDelay",
            "P06:InvalidReverseDelay",
            "P06:InvalidServerProcessing",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.pathSymmetryRequiredForUnbiasedOffset = true;",
            "clockOffsetUnbiasedInTruth = pathSymmetrySatisfiedInTruth;",
            "out.truthClassificationUsesExactInputs = true;",
            "out.pathSymmetryGenerallyObservableFromOneExchange =",
            "out.timestampObservationsGenerallyUniqueToPhysicalTruth =",
            "out.zeroNetworkRoundTripLimitInTruth = zeroNetworkRoundTripLimitInTruth;",
            "out.truthAvailableForTeachingOnly = true;",
            "out.twoWayExchangeModeled = true;",
            "out.fullNtpProtocolModeled = false;",
            "out.clockSkewModeled = false;",
            "out.timestampNoiseModeled = false;",
            "out.packetLossModeled = false;",
            "out.hardwareTimestampingModeled = false;",
            "out.networkIoPerformed = false;",
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
            "for ",
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
            "clockoffsetsms = [-8 0 12]",
            "symmetriconewaydelaysms = [1 4 10]",
            "baseline = model(100,7,4,4,2)",
            "broken = model(100,7,7,1,2)",
            "aliased = model(100,10,4,4,2)",
            "simulation-only",
        ):
            self.assertIn(marker, lowered)
        for label in (
            "simulated true elapsed time since t1 (ms)",
            "signed time term (ms)",
            "true server-minus-client clock offset (ms)",
            "symmetric one-way network delay (ms)",
            "endpoint-local timestamp (ms)",
            "directional one-way delay (ms)",
        ):
            self.assertIn(label, lowered)
        self.assertIn(
            "isequal(broken.timestampobservationms,aliased.timestampobservationms)",
            compact,
        )

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        interactive_lower = interactive.lower()
        interactive_compact = re.sub(r"\s+", "", interactive_lower).replace("...", "")
        self.assertIn("uifigure", interactive_lower)
        self.assertIn("exchangemodel=@model;", interactive_compact)
        self.assertIn("reset baseline", interactive_lower)
        self.assertIn("valuechangedfcn", interactive_lower)
        self.assertIn("truth diagnostic: asymmetric path", interactive_lower)
        for setting in (
            "'limits',[-2020],'value',baselineoffsetms",
            "'limits',[020],'value',baselineforwarddelayms",
            "'limits',[020],'value',baselinereversedelayms",
            "'limits',[020],'value',baselineserverprocessingms",
        ):
            self.assertIn(setting, interactive_compact)
        for control in (
            "server - client offset",
            "forward path delay",
            "reverse path delay",
            "server residence",
        ):
            self.assertIn(control, interactive_lower)
        for reset in (
            "offsetcontrol.value=baselineoffsetms;",
            "forwardcontrol.value=baselineforwarddelayms;",
            "reversecontrol.value=baselinereversedelayms;",
            "processingcontrol.value=baselineserverprocessingms;",
        ):
            self.assertIn(reset, interactive_compact)
        self.assertIn(
            "exchangemodel(clientsendtimems,offsetcontrol.value,forwardcontrol.value,"
            "reversecontrol.value,processingcontrol.value)",
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
            "p05",
            "one-way",
            "t1",
            "t2",
            "t3",
            "t4",
            "server clock minus client clock",
            "forward",
            "reverse",
            "server residence",
            "round trip",
            "path symmetry",
            "asymmetry",
            "half",
            "alias",
            "zero residual",
            "p07",
            "hardware timestamp",
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
            "repeated",
            "shifted",
            "typed",
            "fractional",
            "clockOffsetsMs",
            "symmetricOneWayDelaysMs",
            "zeroPath",
            "processingTimesMs",
            "zeroOffsetAsymmetric",
            "forwardDominant",
            "reverseDominant",
            "nearToleranceAsymmetry",
            "tinyAsymmetryAtZeroOrigin",
            "tinyAsymmetryAtShiftedOrigin",
            "cancellationEdge",
            "precisionObscuredZeroTruth",
            "zeroEverything",
            "negativeOffset",
            "broken",
            "aliased",
            "bounded",
            "boundedNegative",
            "assertThrows",
            "recovered",
            "P06 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P06:InvalidClientSendTime",
            "P06:InvalidClockOffset",
            "P06:InvalidForwardDelay",
            "P06:InvalidReverseDelay",
            "P06:InvalidServerProcessing",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
