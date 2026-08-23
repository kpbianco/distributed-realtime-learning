from __future__ import annotations

import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "modules/03-compare-tcp-and-udp-behavior"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you compare "
    "TCP and UDP Behavior?"
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
P02_FRAME = [126, 0, 11, 42, 18, 52, 255, 106, 255, 206, 0, 50, 0, 150, 135]


def reference_transport(
    message_count: int = 6,
    message_period_ms: float = 200,
    path_delay_ms: float = 20,
    lost_message_index: int = 3,
    retransmission_timeout_ms: float = 1000,
    deadline_ms: float = 800,
) -> dict[str, object]:
    """Independent arithmetic for the bounded timeout-only teaching scenario."""
    serialization_ms = 8 * 15 / 1000
    service_ms = path_delay_ms + serialization_ms
    send_ms = [index * message_period_ms for index in range(message_count)]
    base_arrival_ms = [sent + service_ms for sent in send_ms]
    udp_latency_ms = [service_ms for _ in send_ms]
    tcp_network_age_ms = [service_ms for _ in send_ms]
    if lost_message_index:
        lost = lost_message_index - 1
        udp_latency_ms[lost] = math.nan
        tcp_network_age_ms[lost] = retransmission_timeout_ms + service_ms

    comparison_tolerance_ms = 1e-9
    tcp_latency_ms: list[float] = []
    prior_age = -math.inf
    for network_age in tcp_network_age_ms:
        prior_age_at_send = prior_age - message_period_ms
        age = (
            prior_age_at_send
            if prior_age_at_send > network_age + comparison_tolerance_ms
            else network_age
        )
        tcp_latency_ms.append(age)
        prior_age = age
    tcp_network_ms = [
        sent + age for sent, age in zip(send_ms, tcp_network_age_ms)
    ]
    tcp_application_ms = [
        sent + age for sent, age in zip(send_ms, tcp_latency_ms)
    ]
    udp_delivery_ms = [
        sent + age if math.isfinite(age) else math.nan
        for sent, age in zip(send_ms, udp_latency_ms)
    ]
    tcp_hol_ms = []
    for application_age, network_age in zip(tcp_latency_ms, tcp_network_age_ms):
        head_of_line = max(application_age - network_age, 0)
        tcp_hol_ms.append(
            0 if head_of_line <= comparison_tolerance_ms else head_of_line
        )
    return {
        "serialization_ms": serialization_ms,
        "service_ms": service_ms,
        "send_ms": send_ms,
        "base_arrival_ms": base_arrival_ms,
        "udp_delivery_ms": udp_delivery_ms,
        "tcp_network_ms": tcp_network_ms,
        "tcp_application_ms": tcp_application_ms,
        "tcp_latency_ms": tcp_latency_ms,
        "udp_latency_ms": udp_latency_ms,
        "tcp_hol_ms": tcp_hol_ms,
        "tcp_delivered": message_count,
        "udp_delivered": sum(math.isfinite(value) for value in udp_delivery_ms),
        "tcp_on_time": sum(value <= deadline_ms + 1e-9 for value in tcp_latency_ms),
        "udp_on_time": sum(
            math.isfinite(value) and value <= deadline_ms + 1e-9
            for value in udp_latency_ms
        ),
        "tcp_retransmissions": int(bool(lost_message_index)),
        "tcp_record_range_attempts": message_count + int(bool(lost_message_index)),
        "udp_datagram_attempts": message_count,
    }


def reference_parse_p02_chunks(
    stream: list[int], chunk_sizes: list[int], max_frame_bytes: int = 135,
    max_frames: int = 2,
) -> dict[str, object]:
    """Independent bounded sync/length/checksum parser for the P02 fixture."""
    if sum(chunk_sizes) != len(stream) or len(stream) > max_frame_bytes * max_frames:
        raise ValueError("fixture exceeds its explicit parser bound")
    receive_buffer: list[int] = []
    frame_lengths: list[int] = []
    after_reads: list[int] = []
    next_byte = 0
    state = "complete"
    sync_checks = 0
    length_checks = 0
    checksum_checks = 0
    max_buffer = 0
    for chunk_size in chunk_sizes:
        if state.startswith("rejected-"):
            break
        receive_buffer.extend(stream[next_byte : next_byte + chunk_size])
        next_byte += chunk_size
        max_buffer = max(max_buffer, len(receive_buffer))
        for _ in range(max_frames):
            if len(frame_lengths) >= max_frames:
                state = "rejected-frame-limit"
                break
            if len(receive_buffer) < 3:
                break
            sync_checks += 1
            if receive_buffer[0] != 126:
                state = "rejected-sync"
                break
            length_checks += 1
            declared_payload = 256 * receive_buffer[1] + receive_buffer[2]
            expected_frame = declared_payload + 4
            schema_valid = declared_payload >= 3 and (declared_payload - 3) % 2 == 0
            if not schema_valid or expected_frame > max_frame_bytes:
                state = "rejected-length"
                break
            if len(receive_buffer) < expected_frame:
                state = "waiting-for-frame"
                break
            checksum_checks += 1
            candidate = receive_buffer[:expected_frame]
            if sum(candidate[1:]) % 256:
                state = "rejected-checksum"
                break
            frame_lengths.append(expected_frame)
            del receive_buffer[:expected_frame]
            state = "complete"
            if len(frame_lengths) == max_frames:
                break
        if len(frame_lengths) >= max_frames and (
            receive_buffer or next_byte < len(stream)
        ):
            state = "rejected-frame-limit"
        after_reads.append(len(receive_buffer))
    if not state.startswith("rejected-") and receive_buffer:
        state = "waiting-for-frame"
    return {
        "frames": len(frame_lengths),
        "frame_lengths": frame_lengths,
        "remainder": len(receive_buffer),
        "unconsumed": len(stream) - next_byte,
        "unrecovered": len(receive_buffer) + len(stream) - next_byte,
        "after_reads": after_reads,
        "max_buffer": max_buffer,
        "sync_checks": sync_checks,
        "length_checks": length_checks,
        "checksum_checks": checksum_checks,
        "state": state,
    }


class P03ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P03")

    def assertFloatListsEqual(
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
        self.assertEqual(self.module["number"], 3)
        self.assertEqual(self.module["id"], "P03")
        self.assertEqual(self.module["title"], "Compare TCP and UDP Behavior")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 1)
        self.assertEqual(self.module["phase_title"], "Network behavior")
        self.assertEqual(self.module["slug"], "compare-tcp-and-udp-behavior")
        self.assertEqual(self.module["prerequisites"], ["P02"])
        self.assertEqual(self.module["implementation_batch"], "P03")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p03_checks(self) -> None:
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

            started = run_cli("start", "P03")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P03 — Compare TCP and UDP Behavior", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P03')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P03")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P03 — Compare TCP and UDP Behavior", continued.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", continued.stdout)

            checked = run_cli("check", "P03")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(
                checked.stdout,
                "Run in MATLAB: run_module_checks('P03')\n",
            )

    def test_changed_text_artifacts_have_one_terminal_newline(self) -> None:
        for name in ARTIFACTS:
            with self.subTest(name=name):
                content = (FOLDER / name).read_bytes()
                self.assertTrue(content.endswith(b"\n"), name)
                self.assertFalse(content.endswith(b"\n\n"), name)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_transport()
        self.assertTrue(math.isclose(float(baseline["serialization_ms"]), 0.120))
        self.assertTrue(math.isclose(float(baseline["service_ms"]), 20.12))
        self.assertFloatListsEqual(
            list(baseline["send_ms"]), [0, 200, 400, 600, 800, 1000]
        )
        self.assertFloatListsEqual(
            list(baseline["udp_delivery_ms"]),
            [20.12, 220.12, math.nan, 620.12, 820.12, 1020.12],
        )
        self.assertFloatListsEqual(
            list(baseline["tcp_network_ms"]),
            [20.12, 220.12, 1420.12, 620.12, 820.12, 1020.12],
        )
        self.assertFloatListsEqual(
            list(baseline["tcp_application_ms"]),
            [20.12, 220.12, 1420.12, 1420.12, 1420.12, 1420.12],
        )
        self.assertFloatListsEqual(
            list(baseline["tcp_latency_ms"]),
            [20.12, 20.12, 1020.12, 820.12, 620.12, 420.12],
        )
        self.assertFloatListsEqual(
            list(baseline["tcp_hol_ms"]), [0, 0, 0, 800, 600, 400]
        )
        self.assertEqual(
            (
                baseline["tcp_delivered"],
                baseline["tcp_on_time"],
                baseline["udp_delivered"],
                baseline["udp_on_time"],
            ),
            (6, 4, 5, 5),
        )

        period_cases = [reference_transport(message_period_ms=value) for value in (100, 200, 400)]
        self.assertEqual([case["tcp_on_time"] for case in period_cases], [3, 4, 5])
        self.assertEqual([case["udp_on_time"] for case in period_cases], [5, 5, 5])
        self.assertFloatListsEqual(
            [max(case["tcp_hol_ms"]) for case in period_cases], [900, 800, 600]
        )

        timeout_cases = [
            reference_transport(retransmission_timeout_ms=value)
            for value in (1000, 1250, 1500)
        ]
        self.assertEqual([case["tcp_on_time"] for case in timeout_cases], [4, 3, 2])
        self.assertEqual([case["udp_on_time"] for case in timeout_cases], [5, 5, 5])
        self.assertFloatListsEqual(
            [max(case["tcp_latency_ms"]) for case in timeout_cases],
            [1020.12, 1270.12, 1520.12],
        )

        no_loss = reference_transport(lost_message_index=0)
        self.assertFloatListsEqual(
            list(no_loss["tcp_application_ms"]), list(no_loss["udp_delivery_ms"])
        )
        self.assertEqual(
            (
                no_loss["tcp_delivered"],
                no_loss["udp_delivered"],
                no_loss["tcp_on_time"],
                no_loss["udp_on_time"],
                no_loss["tcp_retransmissions"],
            ),
            (6, 6, 6, 6, 0),
        )
        last_lost = reference_transport(lost_message_index=6)
        self.assertTrue(all(value == 0 for value in last_lost["tcp_hol_ms"]))
        self.assertTrue(
            math.isclose(last_lost["tcp_application_ms"][-1], 2020.12, abs_tol=1e-9)
        )

        at_boundary = reference_transport(lost_message_index=0, deadline_ms=20.12)
        below_boundary = reference_transport(lost_message_index=0, deadline_ms=20.119)
        self.assertEqual((at_boundary["tcp_on_time"], at_boundary["udp_on_time"]), (6, 6))
        self.assertEqual(
            (below_boundary["tcp_on_time"], below_boundary["udp_on_time"]), (0, 0)
        )
        large_timestamp_boundary = reference_transport(
            message_count=64,
            message_period_ms=1_000_000,
            lost_message_index=0,
            deadline_ms=20.12,
        )
        self.assertEqual(
            (
                large_timestamp_boundary["tcp_on_time"],
                large_timestamp_boundary["udp_on_time"],
            ),
            (64, 64),
        )
        coincident_arrival = reference_transport(
            message_count=2,
            message_period_ms=1_000_000,
            path_delay_ms=999_999,
            lost_message_index=1,
            retransmission_timeout_ms=1_000_000,
            deadline_ms=1_000_000,
        )
        self.assertEqual(coincident_arrival["tcp_hol_ms"], [0, 0])
        self.assertEqual(
            coincident_arrival["tcp_application_ms"][1],
            coincident_arrival["tcp_network_ms"][1],
        )

        minimum = reference_transport(
            message_count=1,
            message_period_ms=1,
            path_delay_ms=0,
            lost_message_index=1,
            deadline_ms=1,
        )
        self.assertEqual(
            (minimum["tcp_delivered"], minimum["udp_delivered"]), (1, 0)
        )
        bounded = reference_transport(message_count=64, lost_message_index=32)
        self.assertEqual(
            (
                len(bounded["send_ms"]),
                bounded["tcp_record_range_attempts"],
                bounded["udp_datagram_attempts"],
            ),
            (64, 65, 64),
        )

        stream = P02_FRAME + P02_FRAME
        parsed = reference_parse_p02_chunks(stream, [9, 21])
        self.assertEqual(sum(P02_FRAME[1:]) % 256, 0)
        self.assertEqual(
            (
                parsed["frames"],
                parsed["frame_lengths"],
                parsed["remainder"],
                parsed["after_reads"],
                parsed["state"],
            ),
            (2, [15, 15], 0, [9, 0], "complete"),
        )
        self.assertEqual(
            (parsed["sync_checks"], parsed["length_checks"], parsed["checksum_checks"]),
            (3, 3, 2),
        )
        self.assertEqual(reference_parse_p02_chunks(P02_FRAME[:2], [2])["state"], "waiting-for-frame")
        self.assertEqual(
            reference_parse_p02_chunks([125, 0, 11], [3])["state"],
            "rejected-sync",
        )
        self.assertEqual(
            reference_parse_p02_chunks([126, 0, 133], [3])["state"],
            "rejected-length",
        )
        corrupt = list(P02_FRAME)
        corrupt[7] ^= 1
        self.assertEqual(
            reference_parse_p02_chunks(corrupt, [15])["state"],
            "rejected-checksum",
        )
        frame_limited = reference_parse_p02_chunks(
            P02_FRAME + P02_FRAME + P02_FRAME, [15, 15, 15]
        )
        self.assertEqual(
            (
                frame_limited["frames"],
                frame_limited["unconsumed"],
                frame_limited["unrecovered"],
                frame_limited["state"],
            ),
            (2, 15, 15, "rejected-frame-limit"),
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", source).replace("...", "")
        self.assertIn(
            "function out = model(messageCount,messagePeriodMs,pathDelayMs,"
            "lostMessageIndex,retransmissionTimeoutMs,deadlineMs)",
            source,
        )
        for normalization in (
            "messageCount=double(messageCount);",
            "messagePeriodMs=double(messagePeriodMs);",
            "pathDelayMs=double(pathDelayMs);",
            "lostMessageIndex=double(lostMessageIndex);",
            "retransmissionTimeoutMs=double(retransmissionTimeoutMs);",
            "deadlineMs=double(deadlineMs);",
        ):
            self.assertIn(normalization, compact)
        for default in (
            "ifnargin<1messageCount=6;end",
            "ifnargin<2messagePeriodMs=200;end",
            "ifnargin<3pathDelayMs=20;end",
            "ifnargin<4lostMessageIndex=3;end",
            "ifnargin<5retransmissionTimeoutMs=1000;end",
            "ifnargin<6deadlineMs=800;end",
        ):
            self.assertIn(default, compact)
        for formula in (
            "maxRecordCount=64;",
            "applicationFrameBytes=15;",
            "linkRateKbps=1000;",
            "serializationTimeMs=8*applicationFrameBytes/linkRateKbps;",
            "serviceDelayMs=pathDelayMs+serializationTimeMs;",
            "messageCount>=1&&messageCount<=64",
            "lostMessageIndex>=0&&lostMessageIndex<=messageCount",
            "retransmissionTimeoutMs>=1000&&retransmissionTimeoutMs<=1e6",
            "udpLatencyMs(lostMask)=NaN;",
            "tcpNetworkAgeMs(lostMask)=retransmissionTimeoutMs+serviceDelayMs;",
            "priorAgeAtThisSendMs=priorApplicationAgeMs-messagePeriodMs;",
            "ifpriorAgeAtThisSendMs>tcpNetworkAgeMs(index)+deadlineToleranceMs",
            "tcpLatencyMs(index)=priorAgeAtThisSendMs;",
            "tcpLatencyMs(index)=tcpNetworkAgeMs(index);",
            "tcpHeadOfLineDelayMs=max(tcpLatencyMs-tcpNetworkAgeMs,0);",
            "tcpHeadOfLineDelayMs(tcpHeadOfLineDelayMs<=deadlineToleranceMs)=0;",
            "tcpOnTime=tcpLatencyMs<=deadlineMs+deadlineToleranceMs;",
            "udpOnTime=udpDelivered&udpLatencyMs<=deadlineMs+deadlineToleranceMs;",
            "p02Frame=uint8([126,0,11,42,18,52,255,106,255,206,0,50,0,150,135]);",
            "tcpReadChunkBytes=[9,21];",
            "badSyncParser=parseP02Chunks(uint8([125,0,11]),[3],135,2);",
            "overLimitHeaderBytes=uint8([126,0,133]);",
            "threeFrameStream=uint8([p02Frame,p02Frame,p02Frame]);",
            "frameLimitParser=parseP02Chunks(threeFrameStream,[15,15,15],135,2);",
            "functionresult=parseP02Chunks(streamBytes,chunkSizes,maxFrameBytes,maxFrameCount)",
            "maxStreamBytes=maxFrameBytes*maxFrameCount;",
            "numel(streamBytes)<=maxStreamBytes",
            "ifframesRecovered>=maxFrameCount",
            "parserState='rejected-frame-limit';",
            "ifreceiveBuffer(1)~=syncByte",
            "parserState='rejected-sync';",
            "declaredPayloadBytes=256*double(receiveBuffer(2))+double(receiveBuffer(3));",
            "schemaValid=declaredPayloadBytes>=minimumPayloadBytes&&mod(declaredPayloadBytes-minimumPayloadBytes,2)==0;",
            "ifmod(sum(double(candidate(2:end))),256)~=0",
            "maxTcpOutOfOrderBufferedApplicationBytes",
            "sufficientSenderWindowAssumed",
            "outOfOrderReceiverRetentionAssumed",
            "'analyticalTimeoutOnly',true",
            "'actualWaitPerformed',false",
            "'deadlineOnlyClassifies',true",
            "'cancellationModeled',false",
            "zeros(messageCount,1)",
        ):
            self.assertIn(formula, compact)
        for identifier in (
            "P03:InvalidMessageCount",
            "P03:InvalidMessagePeriod",
            "P03:InvalidPathDelay",
            "P03:InvalidLostMessageIndex",
            "P03:InvalidRetransmissionTimeout",
            "P03:InvalidDeadline",
        ):
            self.assertIn(identifier, source)
        for opaque in (
            "tcpclient",
            "tcpserver",
            "udpport",
            "tcpip",
            "comm.",
            "timer(",
            "pause(",
            "parfor",
            "fitdist",
            "makedist",
            "webread",
            "fopen(",
            "system(",
            "persistent",
            "global ",
            "while ",
            "rng(",
            "rand(",
        ):
            self.assertNotIn(opaque, source.lower())
        for presentation in ("figure(", "plot(", "stem(", "bar(", "uifigure", "uiaxes"):
            self.assertNotIn(presentation, source.lower())

    def test_experiment_has_two_sweeps_views_metrics_and_broken_case(self) -> None:
        source = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        lowered = source.lower()
        compact = re.sub(r"\s+", "", lowered)
        self.assertGreaterEqual(source.count("%%"), 6)
        for marker in (
            "deterministic baseline",
            "sweep 1",
            "sweep 2",
            "deliberately broken case",
            "mechanism:",
            "messageperiodsms = [100 200 400]",
            "retransmissiontimeoutsms = [1000 1250 1500]",
            "broken = model(6,200,20,3,1000,800)",
        ):
            self.assertIn(marker, lowered)
        self.assertGreaterEqual(lowered.count("figure("), 8)
        self.assertGreaterEqual(lowered.count("xlabel("), 6)
        self.assertGreaterEqual(lowered.count("ylabel("), 8)
        self.assertGreaterEqual(lowered.count("title("), 8)
        self.assertGreaterEqual(lowered.count("assert("), 6)
        for unit in ("bytes", "ms", "count"):
            self.assertIn(unit, lowered)
        self.assertIn("plot(messageperiodsms,periodsweeptcpontime", compact)
        self.assertIn("plot(retransmissiontimeoutsms,timeoutsweeptcpontime", compact)

    def test_interactive_controls_have_meaningful_bounds_and_reset(self) -> None:
        source = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", source.lower()).replace("...", "")
        self.assertIn("uifigure", source.lower())
        self.assertEqual(source.lower().count("uispinner"), 4)
        self.assertIn("'limits',[50600],'value',200,'step',50", compact)
        self.assertIn("'limits',[06],'value',3,'step',1", compact)
        self.assertIn("'limits',[10003000],'value',1000,'step',250", compact)
        self.assertIn("'limits',[1002000],'value',800,'step',100", compact)
        self.assertIn("'roundfractionalvalues','on'", compact)
        self.assertIn("reset baseline", source.lower())
        self.assertIn("transportmodel=@model;", compact)
        self.assertIn(
            "transportmodel(6,periodcontrol.value,20,losscontrol.value,timeoutcontrol.value,deadlinecontrol.value)",
            compact,
        )
        self.assertGreaterEqual(source.lower().count("valuechangedfcn"), 4)
        for label in (
            "application record period",
            "lost record index",
            "tcp retransmission timeout",
            "deadline",
            "head-of-line",
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
            "p02",
            "byte stream",
            "datagram",
            "message boundaries",
            "head-of-line",
            "retransmission",
            "timeout",
            "deadline",
            "mechanism",
            "interpretation",
            "teach-back",
            "cancellation",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 40)
        for marker in (
            "expectedUdpDelivery",
            "expectedTcpNetwork",
            "expectedTcpApplication",
            "boundary",
            "badSyncParser",
            "frameLimitParser",
            "defaulted",
            "repeated",
            "typed",
            "minimum",
            "noLoss",
            "lastLost",
            "deadlineEqual",
            "largeTimestampBoundary",
            "coincidentArrival",
            "messagePeriods",
            "retransmissionTimeouts",
            "bounded",
            "typedBounded",
            "assertThrows",
            "recovered",
            "P03 checks passed",
        ):
            self.assertIn(marker, checks)


if __name__ == "__main__":
    unittest.main()
