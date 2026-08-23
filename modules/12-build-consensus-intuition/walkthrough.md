# P12 walkthrough: Build Consensus Intuition

1. Read the guiding question: What inputs, observable effects, and failure modes matter when you
   build Consensus Intuition?
2. Recall P11's distinction between offered work, readiness evidence, and completion. A vote is
   also evidence, but it supports one proposal rather than returning receiver capacity.
3. Recall P09 and P10: replication acknowledgment is not universal visibility, and one sender's
   ordering is not agreement among competing proposers.
4. Make the single prediction in `lesson.md`: identify which vote fixes latency for `q=3` when
   potential evidence arrives at `[0 14 26 38 62] ms`.
5. Run `experiment.m` and inspect only the first baseline view. Reconstruct Node 3's time as
   `12 ms` outbound + `2 ms` processing + `12 ms` return = `26 ms`.
6. Observe Nodes `[1 2 3]` form the first certificate and value `65` is chosen at `26 ms`.
7. Change to the cumulative view. Follow `[1 2 3]` observed votes at `[0 14 26] ms` until the
   threshold is reached.
8. Explain why Nodes 4 and 5 do not delay the baseline: the request asks for three distinct votes,
   not all five.
9. Compute `max(0,2q-N)=max(0,6-5)=1`. Explain why two three-node certificates must share a voter.
10. State the named discipline: the shared node supports at most one value in the same term/slot.
11. Move only delay scale through `[0 0.5 1 2]`. Observe decision latency `[2 14 26 50] ms`.
12. At scale zero, identify the remaining `2 ms` follower processing cost and the deterministic
    lower-node-ID tie rule. Delay changes timing, not quorum geometry.
13. Reset scale to `1`, then move only quorum size through `[2 3 4 5]` votes. Observe decision
    latency `[14 26 38 62] ms`.
14. Compare minimum intersection `[0 1 3 5]` nodes with unavailable-follower tolerance
    `[3 2 1 0]` while the fixed proposer remains online. Name the safety/progress tradeoff and the
    unmodeled proposer-failure boundary before changing another control.
15. Open `interactive.m`. Move one control at a time and use **Reset baseline** before each comparison.
16. Set `q=2`. Observe certificate X `{1,2}` and certificate Y `{4,5}` have no common voter.
17. Name the broken assumption from the symptom: a fast threshold below majority does not force
    conflicting certificates to intersect.
18. Restore `q=3`. Say explicitly that the certificate plot is set geometry; no partition,
    concurrent leader, Raft, Paxos, or message protocol executed.
19. Set `q=4` and timeout `38 ms`. The fourth vote and deadline coincide, so complete evidence wins.
20. Move timeout just below `38 ms`. This evaluator sees only three votes and returns without a
    certificate. The potential fourth-vote time remains visible; timeout proves neither node
    failure nor permanent global non-decision.
21. Set `q=5`, timeout `100 ms`, and take Node 5 offline. Four available votes remain partial
    evidence, and the request times out with one vote still needed.
22. Restore the baseline and enable **Cancel pending proposal at 20 ms**. Two votes have arrived,
    so this evaluator closes its observation window without a certificate or asynchronous signal.
    Later protocol choice is outside the model. Set timeout to `20 ms` too and observe that
    cancellation deterministically wins the local timeout/cancellation classification tie.
23. Set scale `0.75`. The third vote arrives exactly at `20 ms`, wins the cancellation tie, and
    cannot be rolled back by that request.
24. Restore the baseline in a fresh call. The `26 ms` certificate result returns; this is not retry,
    election, replay, durable restore, or live recovery.
25. State the resource boundary: five nodes, one proposal, at most five vote records, two
    five-node witness masks plus five-node decision and intersection masks, seven observation
    instants, delay scale `0–20`, timeout `0–1e6 ms`, and no random, file, timer, storage, network,
    background, or physical operation.
26. Run `run_checks`, answer one interpretation prompt, and teach back vote timing, distinct-node
    threshold, intersection, availability, timeout, cancellation, and the evidence boundary.
