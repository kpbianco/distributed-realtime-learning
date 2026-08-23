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
FOLDER = ROOT / "modules/12-build-consensus-intuition"
QUESTION = (
    "What inputs, observable effects, and failure modes matter when you build "
    "Consensus Intuition?"
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


def reference_consensus(
    delay_scale: float = 1,
    quorum_size: int = 3,
    timeout_ms: float = 100,
    node_five_online: bool = True,
    cancel_pending: bool = False,
) -> dict[str, object]:
    """Independent arithmetic oracle for P12's fixed five-node round."""
    node_count = 5
    node_ids = list(range(1, node_count + 1))
    outbound = [0, 6, 12, 18, 30]
    processing = [0, 2, 2, 2, 2]
    return_delay = [0, 6, 12, 18, 30]
    potential_vote_times: list[float | None] = [
        delay_scale * (forward + backward) + cost
        for forward, backward, cost in zip(outbound, return_delay, processing)
    ]
    online = [True, True, True, True, node_five_online]
    if not node_five_online:
        potential_vote_times[4] = None

    records = sorted(
        (potential_vote_times[index], node_ids[index])
        for index in range(node_count)
        if online[index]
    )
    available_vote_count = len(records)
    quorum_reachable = available_vote_count >= quorum_size
    candidate_time = (
        records[quorum_size - 1][0] if quorum_reachable else math.inf
    )
    cancel_time = 20 if cancel_pending else math.inf

    if candidate_time <= timeout_ms and candidate_time <= cancel_time:
        outcome = "decided"
        resolution_time = candidate_time
        decided, timed_out, canceled = True, False, False
    elif cancel_time <= timeout_ms:
        outcome = "canceled-pending"
        resolution_time = cancel_time
        decided, timed_out, canceled = False, False, True
    else:
        outcome = "timed-out"
        resolution_time = timeout_ms
        decided, timed_out, canceled = False, True, False

    vote_observed = [
        online[index]
        and potential_vote_times[index] is not None
        and potential_vote_times[index] <= resolution_time
        for index in range(node_count)
    ]
    observed_vote_count = sum(vote_observed)
    certificate_ids = (
        [node_id for _time, node_id in records[:quorum_size]] if decided else []
    )
    certificate_mask = [node_id in certificate_ids for node_id in node_ids]
    accepted_times = [
        potential_vote_times[index]
        for index in range(node_count)
        if vote_observed[index]
    ]
    observation_times = sorted(set([0, resolution_time, *accepted_times]))
    cumulative = [
        sum(
            online[index]
            and potential_vote_times[index] is not None
            and potential_vote_times[index] <= time
            and potential_vote_times[index] <= resolution_time
            for index in range(node_count)
        )
        for time in observation_times
    ]

    certificate_a = list(range(1, quorum_size + 1))
    certificate_b = list(
        range(node_count - quorum_size + 1, node_count + 1)
    )
    intersection = sorted(set(certificate_a) & set(certificate_b))
    minimum_intersection = max(0, 2 * quorum_size - node_count)
    finite_vote_times = [value for value, _node_id in records]
    return {
        "node_ids": node_ids,
        "outbound": outbound,
        "processing": processing,
        "return_delay": return_delay,
        "round_trip": [
            forward + backward
            for forward, backward in zip(outbound, return_delay)
        ],
        "potential_vote_times": potential_vote_times,
        "online": online,
        "records": records,
        "available_vote_count": available_vote_count,
        "quorum_reachable": quorum_reachable,
        "candidate_time": None if math.isinf(candidate_time) else candidate_time,
        "timeout_margin": (
            None if math.isinf(candidate_time) else timeout_ms - candidate_time
        ),
        "outcome": outcome,
        "resolution_time": resolution_time,
        "decided": decided,
        "timed_out": timed_out,
        "canceled": canceled,
        "vote_observed": vote_observed,
        "observed_vote_count": observed_vote_count,
        "unobserved_online_vote_count": (
            available_vote_count - observed_vote_count
        ),
        "votes_still_needed": max(0, quorum_size - observed_vote_count),
        "certificate_ids": certificate_ids,
        "certificate_mask": certificate_mask,
        "decision_time": candidate_time if decided else None,
        "chosen_value": 65 if decided else None,
        "observation_times": observation_times,
        "cumulative": cumulative,
        "certificate_a": certificate_a,
        "certificate_b": certificate_b,
        "intersection": intersection,
        "minimum_intersection": minimum_intersection,
        "safe_majority": 2 * quorum_size > node_count,
        "conflicting_possible": len(intersection) == 0,
        "fixed_proposer_online_assumed": True,
        "unavailable_follower_tolerance": node_count - quorum_size,
        "vote_spread": max(finite_vote_times) - min(finite_vote_times),
        "partial_observed_votes_do_not_prove_decision": (
            not decided and observed_vote_count < quorum_size
        ),
        "post_resolution_protocol_progress_modeled": False,
        "decision_won_timeout_tie": decided and candidate_time == timeout_ms,
        "decision_won_cancellation_tie": (
            decided and cancel_pending and candidate_time == 20
        ),
        "cancellation_could_not_erase_observed_certificate": (
            cancel_pending and decided and candidate_time <= 20
        ),
        "cancellation_won_timeout_tie": (
            canceled and cancel_pending and cancel_time == timeout_ms
        ),
    }


class P12ModuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = json.loads(
            (ROOT / "curriculum/modules.json").read_text(encoding="utf-8")
        )
        cls.modules = manifest["modules"]
        cls.module = next(module for module in cls.modules if module["id"] == "P12")

    def test_permanent_manifest_identity_prerequisite_and_artifact_set(self) -> None:
        self.assertEqual(self.module["number"], 12)
        self.assertEqual(self.module["id"], "P12")
        self.assertEqual(self.module["title"], "Build Consensus Intuition")
        self.assertEqual(self.module["guiding_question"], QUESTION)
        self.assertEqual(self.module["phase"], 3)
        self.assertEqual(self.module["phase_title"], "Coordination and flow")
        self.assertEqual(self.module["slug"], "build-consensus-intuition")
        self.assertEqual(self.module["prerequisites"], ["P11"])
        self.assertEqual(self.module["implementation_batch"], "P12")
        self.assertEqual(self.module["status"], "implemented")
        self.assertEqual(self.module["evidence_level"], "simulated")
        self.assertEqual(FOLDER, ROOT / self.module["folder"])
        positions = {module["id"]: index for index, module in enumerate(self.modules)}
        prerequisite = next(module for module in self.modules if module["id"] == "P11")
        self.assertLess(positions["P11"], positions["P12"])
        self.assertEqual(prerequisite["status"], "implemented")
        names = {path.name for path in FOLDER.iterdir() if path.is_file()}
        self.assertTrue(set(ARTIFACTS) <= names)

    def test_public_cli_starts_continues_and_exposes_p12_checks(self) -> None:
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

            started = run_cli("start", "P12")
            self.assertEqual(started.returncode, 0, started.stderr)
            self.assertIn("P12 — Build Consensus Intuition", started.stdout)
            self.assertIn(f"Guiding question: {QUESTION}", started.stdout)
            self.assertIn("launch_lesson('P12')", started.stdout)
            state = json.loads(
                (fixture / ".learning/progress.json").read_text(encoding="utf-8")
            )
            self.assertEqual(state["current"], "P12")

            continued = run_cli("continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn("P12 — Build Consensus Intuition", continued.stdout)
            checked = run_cli("check", "P12")
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(
                checked.stdout, "Run in MATLAB: run_module_checks('P12')\n"
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
        self.assertIn("experimentfiguretag='p12experimentfigure';", compact)
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
        self.assertIn("interactivefiguretag='p12interactivefigure';", compact)
        self.assertIn(
            "existingwindows=findall(groot,'type','figure','tag',"
            "interactivefiguretag);",
            compact,
        )
        self.assertIn("close(existingwindows);", compact)
        self.assertEqual(compact.count("'tag',interactivefiguretag"), 2)

    def test_independent_baseline_sweeps_and_limiting_cases(self) -> None:
        baseline = reference_consensus()
        self.assertEqual(baseline["round_trip"], [0, 12, 24, 36, 60])
        self.assertEqual(baseline["processing"], [0, 2, 2, 2, 2])
        self.assertEqual(
            baseline["potential_vote_times"], [0, 14, 26, 38, 62]
        )
        self.assertEqual(
            baseline["records"], [(0, 1), (14, 2), (26, 3), (38, 4), (62, 5)]
        )
        self.assertTrue(baseline["quorum_reachable"])
        self.assertEqual(baseline["candidate_time"], 26)
        self.assertEqual(baseline["timeout_margin"], 74)
        self.assertTrue(baseline["decided"])
        self.assertFalse(baseline["timed_out"])
        self.assertFalse(baseline["canceled"])
        self.assertEqual(baseline["outcome"], "decided")
        self.assertEqual(baseline["resolution_time"], 26)
        self.assertEqual(baseline["certificate_ids"], [1, 2, 3])
        self.assertEqual(
            baseline["certificate_mask"], [True, True, True, False, False]
        )
        self.assertEqual(baseline["chosen_value"], 65)
        self.assertEqual(baseline["observed_vote_count"], 3)
        self.assertEqual(baseline["unobserved_online_vote_count"], 2)
        self.assertEqual(baseline["observation_times"], [0, 14, 26])
        self.assertEqual(baseline["cumulative"], [1, 2, 3])
        self.assertEqual(baseline["certificate_a"], [1, 2, 3])
        self.assertEqual(baseline["certificate_b"], [3, 4, 5])
        self.assertEqual(baseline["intersection"], [3])
        self.assertEqual(baseline["minimum_intersection"], 1)
        self.assertTrue(baseline["safe_majority"])
        self.assertFalse(baseline["conflicting_possible"])
        self.assertTrue(baseline["fixed_proposer_online_assumed"])
        self.assertEqual(baseline["unavailable_follower_tolerance"], 2)
        self.assertEqual(baseline["vote_spread"], 62)
        self.assertEqual(reference_consensus(), baseline)

        delay_cases = [reference_consensus(delay_scale=value) for value in (0, 0.5, 1, 2)]
        self.assertEqual(
            [case["decision_time"] for case in delay_cases], [2, 14, 26, 50]
        )
        self.assertEqual(
            [case["vote_spread"] for case in delay_cases], [2, 32, 62, 122]
        )
        self.assertEqual(
            [case["observed_vote_count"] for case in delay_cases], [5, 3, 3, 3]
        )
        self.assertTrue(all(case["decided"] for case in delay_cases))

        quorum_cases = [reference_consensus(quorum_size=value) for value in (2, 3, 4, 5)]
        self.assertEqual(
            [case["decision_time"] for case in quorum_cases], [14, 26, 38, 62]
        )
        self.assertEqual(
            [case["minimum_intersection"] for case in quorum_cases], [0, 1, 3, 5]
        )
        self.assertEqual(
            [case["unavailable_follower_tolerance"] for case in quorum_cases],
            [3, 2, 1, 0],
        )
        self.assertEqual(
            [case["safe_majority"] for case in quorum_cases],
            [False, True, True, True],
        )

        zero_delay = reference_consensus(delay_scale=0)
        self.assertEqual(zero_delay["potential_vote_times"], [0, 2, 2, 2, 2])
        self.assertEqual(zero_delay["certificate_ids"], [1, 2, 3])
        self.assertEqual(zero_delay["observed_vote_count"], 5)
        self.assertEqual(zero_delay["observation_times"], [0, 2])
        self.assertEqual(zero_delay["cumulative"], [1, 5])

        bounded = reference_consensus(delay_scale=20, quorum_size=5, timeout_ms=1_000_000)
        self.assertEqual(
            bounded["potential_vote_times"], [0, 242, 482, 722, 1202]
        )
        self.assertEqual(bounded["decision_time"], 1202)
        self.assertEqual(bounded["observed_vote_count"], 5)

    def test_broken_timeout_cancellation_recovery_and_isolation_oracle(self) -> None:
        broken = reference_consensus(quorum_size=2)
        self.assertTrue(broken["decided"])
        self.assertEqual(broken["decision_time"], 14)
        self.assertEqual(broken["certificate_ids"], [1, 2])
        self.assertEqual(broken["certificate_a"], [1, 2])
        self.assertEqual(broken["certificate_b"], [4, 5])
        self.assertEqual(broken["intersection"], [])
        self.assertEqual(broken["minimum_intersection"], 0)
        self.assertFalse(broken["safe_majority"])
        self.assertTrue(broken["conflicting_possible"])

        exact = reference_consensus(quorum_size=4, timeout_ms=38)
        self.assertTrue(exact["decided"])
        self.assertEqual(exact["decision_time"], 38)
        self.assertTrue(exact["decision_won_timeout_tie"])
        self.assertEqual(exact["certificate_ids"], [1, 2, 3, 4])

        just_before = reference_consensus(quorum_size=4, timeout_ms=38 - 1e-12)
        self.assertTrue(just_before["timed_out"])
        self.assertFalse(just_before["decided"])
        self.assertEqual(just_before["observed_vote_count"], 3)
        self.assertEqual(just_before["votes_still_needed"], 1)
        self.assertEqual(just_before["certificate_ids"], [])
        self.assertIsNone(just_before["chosen_value"])
        self.assertEqual(just_before["candidate_time"], 38)
        self.assertTrue(
            just_before["partial_observed_votes_do_not_prove_decision"]
        )
        self.assertFalse(just_before["post_resolution_protocol_progress_modeled"])

        unavailable = reference_consensus(
            quorum_size=5, node_five_online=False
        )
        self.assertFalse(unavailable["quorum_reachable"])
        self.assertTrue(unavailable["timed_out"])
        self.assertEqual(unavailable["available_vote_count"], 4)
        self.assertEqual(unavailable["observed_vote_count"], 4)
        self.assertEqual(unavailable["votes_still_needed"], 1)
        self.assertIsNone(unavailable["candidate_time"])

        canceled = reference_consensus(cancel_pending=True)
        self.assertTrue(canceled["canceled"])
        self.assertFalse(canceled["decided"])
        self.assertEqual(canceled["resolution_time"], 20)
        self.assertEqual(canceled["observed_vote_count"], 2)
        self.assertEqual(canceled["votes_still_needed"], 1)
        self.assertEqual(canceled["certificate_ids"], [])
        self.assertIsNone(canceled["chosen_value"])
        self.assertEqual(canceled["candidate_time"], 26)
        self.assertTrue(
            canceled["partial_observed_votes_do_not_prove_decision"]
        )

        cancellation_tie = reference_consensus(
            delay_scale=0.75, cancel_pending=True
        )
        self.assertEqual(
            cancellation_tie["potential_vote_times"], [0, 11, 20, 29, 47]
        )
        self.assertTrue(cancellation_tie["decided"])
        self.assertFalse(cancellation_tie["canceled"])
        self.assertEqual(cancellation_tie["decision_time"], 20)
        self.assertTrue(cancellation_tie["decision_won_cancellation_tie"])
        self.assertTrue(
            cancellation_tie[
                "cancellation_could_not_erase_observed_certificate"
            ]
        )

        too_late = reference_consensus(quorum_size=2, cancel_pending=True)
        self.assertTrue(too_late["decided"])
        self.assertEqual(too_late["decision_time"], 14)
        self.assertTrue(
            too_late["cancellation_could_not_erase_observed_certificate"]
        )

        cancellation_timeout_tie = reference_consensus(
            timeout_ms=20, cancel_pending=True
        )
        self.assertTrue(cancellation_timeout_tie["canceled"])
        self.assertFalse(cancellation_timeout_tie["timed_out"])
        self.assertEqual(cancellation_timeout_tie["resolution_time"], 20)
        self.assertEqual(cancellation_timeout_tie["candidate_time"], 26)
        self.assertTrue(
            cancellation_timeout_tie["cancellation_won_timeout_tie"]
        )

        recovered = reference_consensus()
        self.assertEqual(recovered, reference_consensus())
        self.assertTrue(recovered["decided"])

    def test_timeout_precedes_later_pending_cancellation(self) -> None:
        timed_out = reference_consensus(timeout_ms=14, cancel_pending=True)
        without_cancellation = reference_consensus(
            timeout_ms=14, cancel_pending=False
        )

        self.assertFalse(timed_out["decided"])
        self.assertTrue(timed_out["timed_out"])
        self.assertFalse(timed_out["canceled"])
        self.assertEqual(timed_out["outcome"], "timed-out")
        self.assertEqual(timed_out["resolution_time"], 14)
        self.assertEqual(timed_out["observed_vote_count"], 2)
        self.assertEqual(timed_out["votes_still_needed"], 1)
        self.assertEqual(timed_out["candidate_time"], 26)
        self.assertEqual(timed_out["observation_times"], [0, 14])
        self.assertEqual(timed_out["cumulative"], [1, 2])
        self.assertEqual(timed_out, without_cancellation)

        model_source = (FOLDER / "model.m").read_text(encoding="utf-8")
        model_compact = re.sub(r"\s+", "", model_source).lower().replace(
            "...", ""
        )
        self.assertIn(
            "elseifcancellationdeadlinems<=decisiontimeoutms", model_compact
        )

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        compact = re.sub(r"\s+", "", checks).lower().replace("...", "")
        self.assertIn(
            "timeoutbeforecancellation=model(1,3,14,true,true);", compact
        )
        self.assertIn("timeoutbeforecancellation.timedout", compact)
        self.assertIn("~timeoutbeforecancellation.canceled", compact)
        self.assertIn(
            "timeoutbeforecancellation.requestresolutiontimems==14", compact
        )

    def test_model_is_bounded_deterministic_and_presentation_free(self) -> None:
        source = (FOLDER / "model.m").read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.lstrip().startswith("%")
        )
        compact = re.sub(r"\s+", "", code).lower().replace("...", "")
        self.assertIn(
            "functionout=model(delayscale,quorumsize,decisiontimeoutms,"
            "nodefiveonline,cancelpendingproposal)",
            compact,
        )
        for formula in (
            "nodecount=5;",
            "majorityquorumsize=floor(nodecount/2)+1;",
            "cancelrequesttimems=20;",
            "baseroundtripdelayms=baseoutbounddelayms+basereturndelayms;",
            "potentialvotetimems=delayscale*baseroundtripdelayms+voteprocessingtimems;",
            "availablevoterecords=sortrows(availablevoterecords,[12]);",
            "candidatedecisiontimems=orderedpotentialvotetimems(quorumsize);",
            "minimumquorumintersectionnodes=max(0,2*quorumsize-nodecount);",
            "safemajorityquorum=2*quorumsize>nodecount;",
            "fixedproposeronlineassumed=true;",
            "unavailablefollowertolerance=nodecount-quorumsize;",
            "maxobservationeventcount=nodecount+2;",
            "maxwitnesscertificatemembershipcount=2*nodecount;",
            "maxcertificatemaskcount=4;",
            "maxcertificatemaskmembershipslots=maxcertificatemaskcount*nodecount;",
            "maxpotentialvotetimems=1202;",
        ):
            self.assertIn(formula, compact)
        for normalization in (
            "delayscale=double(delayscale);",
            "quorumsize=double(quorumsize);",
            "decisiontimeoutms=double(decisiontimeoutms);",
            "nodefiveonline=logical(nodefiveonline);",
            "cancelpendingproposal=logical(cancelpendingproposal);",
        ):
            self.assertIn(normalization, compact)
        for identifier in (
            "P12:InvalidDelayScale",
            "P12:InvalidQuorumSize",
            "P12:InvalidDecisionTimeout",
            "P12:InvalidNodeAvailability",
            "P12:InvalidCancellationPolicy",
        ):
            self.assertIn(identifier, source)
        for boundary in (
            "out.quorumEvidenceWinsExactTie = true;",
            "out.cancellationHasTimeoutTiePrecedence = true;",
            "out.decisionMeansCertificateObservedByEvaluator = true;",
            "out.postResolutionProtocolProgressModeled = false;",
            "out.timeoutIsArithmeticClassification = true;",
            "out.actualWallClockWaitPerformed = false;",
            "out.actualAsynchronousCancellationPerformed = false;",
            "out.rollbackModeled = false;",
            "out.actualRollbackPerformed = false;",
            "out.observedVotesNotRolledBack = true;",
            "out.cancellationClosesEvaluatorWindowOnly = true;",
            "out.observedCertificateNotErasedByLateCancellation = true;",
            "out.recoveryModeled = false;",
            "out.retryModeled = false;",
            "out.fullConsensusProtocolModeled = false;",
            "out.leaderElectionModeled = false;",
            "out.logReplicationModeled = false;",
            "out.valueApplicationModeled = false;",
            "out.partitionExecutionModeled = false;",
            "out.networkIoPerformed = false;",
            "out.storageIoPerformed = false;",
            "out.backgroundWorkStarted = false;",
            "out.physicalHardwareUsed = false;",
            "out.calculationBounded = true;",
        ):
            self.assertIn(boundary, source)
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
            "delayscales = [0 0.5 1 2]",
            "quorumsizes = [2 3 4 5]",
            "baseline = model(1,3,100,true,false)",
            "broken = model(1,2,100,true,false)",
            "any fast threshold is enough for agreement",
        ):
            self.assertIn(marker, lowered)
        self.assertIn(
            "current=model(delayscales(caseindex),3,100,true,false);", compact
        )
        self.assertIn(
            "current=model(1,quorumsizes(caseindex),100,true,false);", compact
        )
        for label in (
            "node identifier (integer)",
            "vote observed by proposer (ms)",
            "analytical event time (ms)",
            "observed votes (count)",
            "round-trip delay scale (dimensionless)",
            "decision latency (ms)",
            "quorum size (votes)",
            "guaranteed minimum intersection (nodes)",
            "unavailable-follower tolerance (nodes)",
            "certificate membership (0 or 1)",
        ):
            self.assertIn(label, lowered)
        self.assertNotIn(
            "vote spread (ms) or votes at decision (count)", lowered
        )
        self.assertNotIn(
            "decision latency (ms) or intersection (nodes)", lowered
        )
        self.assertGreaterEqual(compact.count("subplot(3,1,"), 6)
        self.assertIn("isempty(broken.certificateintersectionnodeids)", compact)

        interactive = (FOLDER / "interactive.m").read_text(encoding="utf-8")
        lowered = interactive.lower()
        compact = re.sub(r"\s+", "", lowered).replace("...", "")
        self.assertIn("uifigure", lowered)
        self.assertEqual(lowered.count("uispinner"), 3)
        self.assertEqual(lowered.count("uicheckbox"), 2)
        self.assertIn("consensusmodel=@model;", compact)
        self.assertIn("reset baseline", lowered)
        self.assertGreaterEqual(lowered.count("valuechangedfcn"), 5)
        for setting in (
            "'limits',[03],'value',baselinedelayscale,'step',0.25",
            "'limits',[15],'value',baselinequorumsize,'step',1",
            "'limits',[0150],'value',baselinedecisiontimeoutms,'step',5",
            "'text','node5online','value',baselinenodefiveonline",
            "'text','cancelpendingproposalat20ms','value',baselinecancelpendingproposal",
        ):
            self.assertIn(setting, compact)
        for reset in (
            "delaycontrol.value=baselinedelayscale;",
            "quorumcontrol.value=baselinequorumsize;",
            "timeoutcontrol.value=baselinedecisiontimeoutms;",
            "availabilitycontrol.value=baselinenodefiveonline;",
            "cancelcontrol.value=baselinecancelpendingproposal;",
        ):
            self.assertIn(reset, compact)
        self.assertIn(
            "consensusmodel(delaycontrol.value,quorumcontrol.value,"
            "timeoutcontrol.value,availabilitycontrol.value,cancelcontrol.value)",
            compact,
        )
        self.assertIn("observed/required/available%d/%d/%dvotes", compact)
        self.assertIn("fixedproposeronline", compact)
        self.assertIn("disjointconflictingcertificatespossible", compact)

    def test_tutor_text_checks_and_malformed_recovery_are_complete(self) -> None:
        tutor_names = ("README.md", "lesson.m", "lesson.md", "walkthrough.md", "checks.md")
        combined = "\n".join(
            (FOLDER / name).read_text(encoding="utf-8") for name in tutor_names
        )
        lowered = combined.lower()
        self.assertGreaterEqual(combined.count(QUESTION), 3)
        for concept in (
            "p11",
            "p10",
            "p09",
            "distinct",
            "q-th",
            "certificate",
            "intersection",
            "one-vote",
            "safety",
            "progress",
            "availability",
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
            "fixed proposer remains online",
            "permanent global non-decision",
            "post-resolution protocol progress",
            "cancellation deterministically wins",
        ):
            self.assertIn(boundary, lowered)
        for placeholder in ("scaffolded", "todo", "fixme", "placeholder", "not implemented"):
            self.assertNotIn(placeholder, lowered)

        checks = (FOLDER / "run_checks.m").read_text(encoding="utf-8")
        self.assertGreaterEqual(checks.count("assert("), 185)
        for marker in (
            "baseline",
            "repeated",
            "defaults",
            "typed",
            "fractional",
            "zeroDelay",
            "delayScales",
            "quorumSizes",
            "broken",
            "singleVote",
            "exactTimeoutBoundary",
            "justBeforeTimeoutBoundary",
            "zeroTimeoutWithoutQuorum",
            "timeoutAfterFourVotes",
            "nodeFiveUnavailable",
            "unreachableQuorum",
            "canceledPending",
            "decisionAtCancellationTie",
            "cancellationTooLate",
            "cancellationTimeoutTie",
            "timeoutBeforeCancellation",
            "recoveryAfterTimeout",
            "bounded",
            "assertThrows",
            "recoveredAfterMalformed",
            "P12 checks passed",
        ):
            self.assertIn(marker, checks)
        for identifier in (
            "P12:InvalidDelayScale",
            "P12:InvalidQuorumSize",
            "P12:InvalidDecisionTimeout",
            "P12:InvalidNodeAvailability",
            "P12:InvalidCancellationPolicy",
        ):
            self.assertIn(identifier, checks)


if __name__ == "__main__":
    unittest.main()
