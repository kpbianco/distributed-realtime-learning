# P12 — Build Consensus Intuition

**Track:** Distributed Real-Time Systems and Networks  
**Phase 3:** Coordination and flow  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you build Consensus Intuition?

## Compounds on P11

P09 showed that replication acknowledgments and universal visibility are different facts. P10
kept one sender's versions ordered. P11 made a receiver's finite readiness visible upstream. P12
adds a different coordination question: how many distinct nodes must support one value, when is
that evidence observable, and why must possible decision certificates overlap?

## Computational mental model

One proposer asks five fixed nodes to support value `65`. Node `i` can contribute at most one vote
for this proposal. Its vote is potentially observed at

`T_i = s*(d_out_i + d_return_i) + p_i`,

where `s` is a dimensionless round-trip delay scale. The transparent fixture uses base outbound
and return delays `[0 6 12 18 30] ms` and processing times `[0 2 2 2 2] ms`. At `s=1`, potential
vote times are `[0 14 26 38 62] ms`. This evaluator observes a certificate when the `q`-th distinct
online vote arrives, provided that evidence is no later than its timeout or pending cancellation.
Complete quorum evidence wins an exact tie. Node 1 is the fixed proposer/local voter and is always
online; leader failure and replacement are outside this model.

Timing says when one proposal can collect `q` votes. Safety intuition comes from set geometry. Any
two `q`-node certificates in a fixed `N=5` membership overlap by at least

`I_min = max(0, 2q - N)` nodes.

With `q=3`, the minimum intersection is one node. Assuming each node votes for at most one value
in the same term/slot, that shared voter prevents two conflicting majority certificates. With
`q=2`, certificates `{1,2}` and `{4,5}` are disjoint, so two conflicting values can each collect
the configured threshold. Vote timing alone cannot repair that unsafe threshold.

This is a one-round quorum-evidence fixture, not Raft, Paxos, atomic broadcast, or a complete
consensus implementation. It does not execute leader election, terms, logs, replication, value
application, membership changes, partitions, durable voting, retries, or recovery.

## Deterministic baseline

The baseline uses delay scale `1`, quorum `q=3`, decision timeout `100 ms`, all five nodes online,
and no cancellation.

- Potential vote times are `[0 14 26 38 62] ms`.
- Nodes `[1 2 3]` form the first certificate at `26 ms`; value `65` is chosen in the fixture.
- The retained cumulative view is `[1 2 3]` votes at `[0 14 26] ms`.
- The two slower online votes are not needed for this decision.
- Any two three-node certificates intersect in at least one node.
- A three-node quorum can remain reachable with two follower voters unavailable while the fixed
  proposer remains online; the live control exposes only Node 5 availability.

These are deterministic arithmetic values. They are not timestamps from MATLAB execution,
processes, packets, clocks, storage, networks, or physical nodes.

## Controlled experiments

1. Read the vote-time equation and inspect potential evidence time per node.
2. Change to cumulative evidence and identify the exact third vote that crosses `q=3`.
3. Sweep only delay scale through `[0 0.5 1 2]`. Decision latency becomes `[2 14 26 50] ms`.
   At scale zero, fixed follower processing remains and four votes tie at `2 ms`.
4. Reset scale to `1`, then sweep only quorum size through `[2 3 4 5]` votes. Decision latency
   becomes `[14 26 38 62] ms`, minimum intersection becomes `[0 1 3 5]` nodes, and unavailable-
   follower tolerance becomes `[3 2 1 0]` nodes assuming the fixed proposer stays online.
5. Deliberately use `q=2`. The two threshold-sized certificate examples `{1,2}` and `{4,5}` do
   not intersect, so conflicting decisions are possible under the stated one-vote assumption.
6. Require `q=4` with a timeout of exactly `38 ms`: the fourth vote wins the exact deadline tie.
   Move the timeout just below `38 ms`: this evaluator sees only three votes and returns without a
   certificate. The potential fourth-vote time remains visible; later protocol progress is unknown.
7. Require all five votes while Node 5 is offline. Four votes arrive, but the request times out
   because partial evidence does not prove a decision to this evaluator.
8. Request cancellation at `20 ms` while `q=3` needs `26 ms`. This evaluator stops after two votes
   without observing a certificate. At scale `0.75`, the third vote arrives exactly at `20 ms` and
   wins the tie. If cancellation and timeout alone tie, cancellation classifies the local result.
9. Restore baseline inputs in a fresh stateless call. The baseline certificate result returns; no retry,
   new election, replay, durable restore, or live recovery protocol ran.
10. Run independent checks, answer one interpretation question at a time, and teach back safety
    and progress without equating this fixture with a full consensus system.

## Timeout, cancellation, rollback, and recovery boundary

Timeout and cancellation compare finite timestamps; no wall-clock timer, blocking request, or
asynchronous signal runs. A timeout does not prove a node failed or that later evidence could never
arrive. Pending cancellation only closes this evaluator's observation window when a certificate
does not already exist. Complete evidence wins a tie; if cancellation and timeout tie without a
certificate, cancellation wins classification. Neither result proves that a real protocol cannot
choose later because post-resolution protocol progress is not modeled.

Observed votes are not rolled back. A vote is evidence, not a committed state transition in this
fixture, and value application is deliberately outside the model. A fresh call with restored
availability, timeout, or cancellation demonstrates a recovery target only. No leader change,
retry, log replay, stable-storage repair, or protocol recovery is executed.

## Transparent abstraction and resource bound

Every call evaluates exactly five nodes, one proposal, and at most five vote records. It retains
two five-node witness-certificate masks plus one decision mask and one intersection mask: four
fixed masks and twenty membership slots total. It retains at most seven observation instants.
Delay scale is bounded to `0–20`, quorum to integer `1–5 votes`, and timeout to `0–1e6 ms`.
Potential vote time is at most `1202 ms`; request resolution is at most `1e6 ms`.

The model uses base MATLAB vector arithmetic, `sortrows`, and one bounded observation loop. It has
no random, global, persistent, file, storage, timer, system, transport, network, parallel, or
background operation. Fixed membership, an online fixed proposer, follower crash-stop availability,
trustworthy one-vote-per-term behavior, and one proposal are named assumptions. Byzantine behavior,
double voting, proposer failure, leader replacement, concurrent leaders, reconfiguration,
partitions, leases, clock bounds, durable state, and full protocol liveness are omitted.

## Files

- `model.m` — deterministic vote timing, quorum certificate, intersection, timeout, and cancellation arithmetic.
- `experiment.m` — two baseline views, two independent sweeps, broken threshold, and lifecycle boundaries.
- `interactive.m` — delay, quorum, timeout, availability, cancellation, and reset controls.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent identities, limits, malformed recovery, interpretation, and teach-back.

Static validation and independently recomputed reference arithmetic do not imply MATLAB-runtime,
UI, MATLAB numerical-fidelity, consensus-protocol, network, storage, bench, HIL, field, RT1/RT2,
Unreal, signing, deployment, or production validation.
