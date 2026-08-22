from __future__ import annotations

import json
import math
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "modules/02-serialize-and-frame-a-message"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you serialize "
    "and Frame a Message?"
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


def reference_frame(sample_count: int, link_rate_kbps: float, delta: int = 0) -> dict[str, object]:
    """Independent protocol arithmetic used to anchor the retained static contract."""
    samples = [100 * index - 250 for index in range(1, sample_count + 1)]
    payload = [42, 0x12, 0x34]
    for sample in samples:
        encoded = sample % 65536
        payload.extend((encoded // 256, encoded % 256))
    declared = len(payload) + delta
    length_bytes = [declared // 256, declared % 256]
    checksum = (-sum(length_bytes + payload)) % 256
    frame = [0x7E, *length_bytes, *payload, checksum]
    expected_frame_bytes = declared + 4
    return {
        "samples": samples,
        "payload": payload,
        "frame": frame,
        "checksum": checksum,
        "payload_bytes": len(payload),
        "frame_bytes": len(frame),
        "expected_frame_bytes": expected_frame_bytes,
        "missing_bytes": max(expected_frame_bytes - len(frame), 0),
        "wire_bits": 8 * len(frame),
        "time_ms": 8 * len(frame) / link_rate_kbps,
        "efficiency": len(payload) / len(frame),
    }


class P02ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        cls.module = next(module for module in manifest["modules"] if module["id"] == "P02")

    def test_permanent_manifest_identity_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 2)
        self.assertEqual(self.module["title"], "Serialize and Frame a Message")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 1)
        self.assertEqual(self.module["phase_title"], "Network behavior")
        self.assertEqual(self.module["prerequisites"], ["P01"])
        self.assertEqual(self.module["implementation_batch"], "P02")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_changed_text_artifacts_have_one_terminal_newline(self) -> None:
        for name in ARTIFACTS:
            with self.subTest(name=name):
                content = (FOLDER / name).read_bytes()
                self.assertTrue(content.endswith(b"\n"), name)
                self.assertFalse(content.endswith(b"\n\n"), name)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_frame(4, 1000)
        self.assertEqual(baseline["samples"], [-150, -50, 50, 150])
        self.assertEqual(
            baseline["payload"],
            [42, 18, 52, 255, 106, 255, 206, 0, 50, 0, 150],
        )
        self.assertEqual(
            baseline["frame"],
            [126, 0, 11, 42, 18, 52, 255, 106, 255, 206, 0, 50, 0, 150, 135],
        )
        self.assertEqual(baseline["checksum"], 135)
        self.assertEqual((baseline["payload_bytes"], baseline["frame_bytes"]), (11, 15))
        self.assertEqual(baseline["wire_bits"], 120)
        self.assertTrue(math.isclose(float(baseline["time_ms"]), 0.120))
        self.assertTrue(math.isclose(float(baseline["efficiency"]), 11 / 15))

        sample_sweep = [reference_frame(count, 1000) for count in (0, 1, 4, 16)]
        self.assertEqual([case["frame_bytes"] for case in sample_sweep], [7, 9, 15, 39])
        self.assertEqual([case["time_ms"] for case in sample_sweep], [0.056, 0.072, 0.120, 0.312])
        rate_sweep = [reference_frame(4, rate) for rate in (125, 1000, 10000)]
        self.assertEqual([case["time_ms"] for case in rate_sweep], [0.96, 0.12, 0.012])
        self.assertEqual({case["frame_bytes"] for case in rate_sweep}, {15})
        self.assertEqual({case["efficiency"] for case in rate_sweep}, {11 / 15})

        empty = reference_frame(0, 1000)
        bounded = reference_frame(64, 1000)
        self.assertEqual((empty["payload_bytes"], empty["frame_bytes"], empty["checksum"]), (3, 7, 141))
        self.assertEqual((bounded["payload_bytes"], bounded["frame_bytes"], bounded["checksum"]), (131, 135, 63))
        broken = reference_frame(4, 1000, 2)
        self.assertEqual((broken["frame_bytes"], broken["expected_frame_bytes"], broken["missing_bytes"]), (15, 17, 2))

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", source)
        self.assertIn("function out = model(sampleCount,linkRateKbps,declaredLengthDelta)", source)
        self.assertIn("payloadBytes=3+2*sampleCount;", compact)
        self.assertIn("wireBits=8*actualFrameBytes;", compact)
        self.assertIn("serializationTimeMs=wireBits/linkRateKbps;", compact)
        self.assertIn("framingEfficiency=payloadBytes/actualFrameBytes;", compact)
        self.assertIn("checksum=uint8(mod(-sum(double(frameWithoutChecksum(2:end))),256));", compact)
        self.assertIn("sampleCount<=64", compact)
        self.assertIn("declaredPayloadBytes>65535", compact)
        self.assertIn("maxPayloadBytes=3+2*64;", compact)
        self.assertIn("declaredLengthWithinPolicy=declaredPayloadBytes<=maxPayloadBytes;", compact)
        self.assertIn("schemaValid=declaredPayloadBytes>=3&&mod(declaredPayloadBytes-3,2)==0;", compact)
        self.assertIn("zeros(1,payloadBytes,'uint8')", compact)
        self.assertNotIn("zeros(1,declaredPayloadBytes", compact)
        for normalization in (
            "sampleCount=double(sampleCount);",
            "linkRateKbps=double(linkRateKbps);",
            "declaredLengthDelta=double(declaredLengthDelta);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P02:InvalidSampleCount",
            "P02:InvalidLinkRate",
            "P02:InvalidDeclaredLengthDelta",
            "P02:DeclaredLengthOutOfRange",
        ):
            self.assertIn(identifier, source)
        for opaque in ("typecast(", "de2bi", "jsonencode", "tcpclient", "udpport", "comm.", "crc"):
            self.assertNotIn(opaque, source.lower())
        for presentation in ("figure(", "plot(", "stem(", "bar(", "uifigure", "uiaxes"):
            self.assertNotIn(presentation, source.lower())
        self.assertIn('receiverState = "waiting-for-bytes"', source)
        self.assertIn("timeoutRequired=declaredLengthWithinPolicy&&schemaValid&&missingBytes>0;", compact)

    def test_experiment_has_two_sweeps_views_metrics_and_broken_case(self) -> None:
        source = (FOLDER / "experiment.m").read_text(encoding="utf-8")
        lowered = source.lower()
        self.assertGreaterEqual(source.count("%%"), 6)
        for marker in (
            "deterministic baseline",
            "sweep 1",
            "sweep 2",
            "deliberately broken case",
            "mechanism:",
            "samplecounts = [0 1 4 16]",
            "linkrateskbps = [125 1000 10000]",
            "broken = model(4,1000,2)",
        ):
            self.assertIn(marker, lowered)
        self.assertGreaterEqual(lowered.count("figure("), 5)
        self.assertGreaterEqual(lowered.count("xlabel("), 3)
        self.assertGreaterEqual(lowered.count("ylabel("), 5)
        self.assertGreaterEqual(lowered.count("title("), 5)
        for unit in ("bytes", "bits", "kb/s", "ms"):
            self.assertIn(unit, lowered)
        self.assertGreaterEqual(lowered.count("assert("), 4)
        self.assertIn("plot(samplecounts,samplesweepframes", re.sub(r"\s+", "", lowered))
        self.assertIn("semilogx(linkrateskbps,ratesweepframes", re.sub(r"\s+", "", lowered))

    def test_interactive_controls_have_meaningful_bounds_and_reset(self) -> None:
        source = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", source.lower())
        self.assertIn("uifigure", source.lower())
        self.assertEqual(source.lower().count("uispinner"), 3)
        self.assertIn("'limits',[064],'value',4,'step',1", compact)
        self.assertIn("'limits',[110000],'value',1000,'step',125", compact)
        self.assertIn("'limits',[016],'value',0,'step',1", compact)
        self.assertEqual(compact.count("'roundfractionalvalues','on'"), 2)
        self.assertIn("reset baseline", source.lower())
        self.assertIn("model(sampleControl.Value,rateControl.Value,deltaControl.Value)", source)
        self.assertGreaterEqual(source.lower().count("valuechangedfcn"), 3)
        for label in ("samples per message", "link rate", "extra bytes declared"):
            self.assertIn(label, source.lower())

    def test_lesson_checks_and_walkthrough_are_concept_first(self) -> None:
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8")
            for name in ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        )
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        lowered = combined.lower()
        for concept in (
            "p01",
            "big-endian",
            "mechanism",
            "timeout",
            "teach-back",
            "interpretation",
            "already-aligned",
            "resynchronization",
        ):
            self.assertIn(concept, lowered)
        self.assertEqual(lowered.count("one prediction before the baseline"), 1)
        for placeholder in ("scaffolded", "todo", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 25)
        for marker in (
            "expectedPayload",
            "expectedFrame",
            "typedBounded",
            "sampleCounts",
            "linkRates",
            "shortDeclaration",
            "invalidSchema",
            "overLimit",
            "corrupted",
            "assertThrows",
            "recovered",
            "P02 checks passed",
        ):
            self.assertIn(marker, checks)


if __name__ == "__main__":
    unittest.main()
