# P12 lesson: Build Consensus Intuition

## Guiding question

What inputs, observable effects, and failure modes matter when you build Consensus Intuition?

## Compounds on P11

P11 separated offered work from admitted and completed work: a readiness credit was evidence that
one finite receiver slot existed. A quorum vote is a different kind of evidence. It says one
distinct node supported a proposal under stated voting rules; it does not add service capacity or
prove that every replica has applied the value.

P09 already showed why an acknowledgment count is not automatically consensus, and P10 showed why
one sender's sequence order is not global agreement. P12 combines those cautions into two visible
questions: when does one proposal have enough votes to decide, and can another conflicting
proposal collect a different valid-looking certificate?

## Mental model

Use five fixed nodes. The proposer has a local vote at `0 ms`. Each follower receives the proposal,
spends `2 ms` processing it, and returns a vote. For node `i`,

`T_i = s*(d_out_i + d_return_i) + p_i`.

The fixture uses equal outbound and return vectors `[0 6 12 18 30] ms`, processing
`[0 2 2 2 2] ms`, and lower node ID to break exact timing ties. At delay scale `s=1`, vote evidence
could arrive at `[0 14 26 38 62] ms`.

A threshold `q` lets this evaluator report a certificate for one value at the `q`-th distinct
online vote, unless timeout or pending cancellation closes its observation window first. Complete
quorum evidence wins an exact tie with either boundary. A timeout is a statement about evidence
observed by a finite deadline, not proof of node failure or of permanent global non-decision.

For safety intuition, compare any two sets of `q` voters among `N=5` nodes. Their guaranteed
minimum overlap is

`I_min = max(0, 2q - N)`.

When `q=3`, at least one node is shared. If each node supports at most one value in a term/slot,
two conflicting three-vote certificates cannot both be valid. When `q=2`, two disjoint pairs exist,
so that argument disappears. Majority size supplies intersection; the one-vote discipline gives
that intersection meaning.

## One prediction before the baseline

With vote times `[0 14 26 38 62] ms` and `q=3`, which node's returned vote fixes the decision
latency, and why do the two slower votes not delay that decision?

## Baseline observation

Use delay scale `1`, `q=3`, timeout `100 ms`, all nodes online, and no cancellation. Node 1 votes
locally at `0 ms`, Node 2's evidence arrives at `14 ms`, and Node 3's at `26 ms`. Those three nodes
form the first certificate, so value `65` is chosen at `26 ms`. Nodes 4 and 5 could return at
`38` and `62 ms`, but their votes are not required for this request.

The cumulative view rises `[1 2 3]` at `[0 14 26] ms`. Do not read “three” as a magic message
count. Its safety meaning comes from fixed membership: every other three-node set shares at least
one voter with this certificate. The model assumes that shared voter will not support a conflicting
value in the same term/slot.

## Lever 1: round-trip delay scale

Hold `q=3`, timeout `100 ms`, availability, and cancellation fixed. Move only `s` through
`[0 0.5 1 2]`. Decision latency becomes `[2 14 26 50] ms`. At `s=0`, path delay vanishes but the
four followers still require `2 ms` processing; all four follower votes tie, and lower node ID
selects the retained three-node certificate deterministically.

Scaling path delay moves the time at which evidence is observable. It does not change quorum
size, minimum intersection, proposal value, membership, or voting discipline.

## Lever 2: quorum size

Reset delay scale to `1`. Move only `q` through `[2 3 4 5]` votes.

- Decision latency is `[14 26 38 62] ms`.
- Guaranteed minimum intersection is `[0 1 3 5]` nodes.
- Unavailable-follower tolerance is `[3 2 1 0]` nodes while the fixed proposer remains online.

Waiting for more votes increases the evidence wait and the overlap between any two certificates,
but reduces how many unavailable followers the round can tolerate with the fixed proposer online.
The fixture does not model proposer failure or election. `q=3` is the smallest safe majority for
five fixed nodes under the one-vote assumption. Requiring four or five votes is still intersecting,
yet it is slower here and loses availability sooner.

## Deliberately broken threshold assumption

Set `q=2`. The first single proposal can decide quickly at `14 ms`, but speed hides a safety hole.
Certificate X can use nodes `{1,2}` while conflicting certificate Y uses `{4,5}`. Their intersection
is empty, so no node is forced to see and reject both values. Both pairs can meet the configured
threshold in separated communication components.

The violated assumption is “any fast threshold is enough for agreement.” The figure is certificate
geometry, not an executed partition or two-leader protocol. P19 later studies network partitions;
P12 isolates why a below-majority threshold lacks the overlap consensus protocols rely on.

## Timeout, availability, and cancellation

With `q=4`, the fourth potential vote arrives at `38 ms`. A timeout of exactly `38 ms` accepts the
certificate because evidence wins the tie. A timeout just below `38 ms` observes only three votes
and this evaluator returns without observing a certificate. The potential fourth vote at `38 ms`
remains visible, but whether a real protocol later chooses is outside the model. Partial observed
evidence is not silently promoted into a local decision claim.

With `q=5` and Node 5 offline, only four votes are possible. The request times out at `100 ms`.
That demonstrates the liveness side of quorum choice: a threshold can remain safe yet be
unreachable with the available nodes. The arithmetic timeout does not detect why Node 5 is absent
and does not prove it crashed.

Enable pending cancellation at `20 ms` under the baseline. Only Nodes 1 and 2 have voted, so the
evaluator closes its observation window without a certificate. Later global choice is outside the
model. At scale `0.75`, Node 3's vote arrives exactly at `20 ms`; quorum evidence wins and the
cancellation cannot undo that local certificate result. With `q=2`, the certificate was already
observed at `14 ms`, so the same request is too late. If timeout and cancellation both occur at
`20 ms` without a certificate, cancellation deterministically classifies the local result.

## Rollback and recovery boundary

Observed votes are not rolled back after timeout or cancellation. They are evidence records in a
finite calculation, not applied state. A locally observed certificate is likewise not erased by a
later cancellation request. Real protocols need durable term/slot rules to turn certificate
evidence into a global safety promise across crashes; durable voting is not modeled here.

Restoring all nodes, timeout `100 ms`, no cancellation, and `q=3` in a fresh call reproduces the
`26 ms` baseline. That is stateless reevaluation, not retry, leader election, replay, catch-up,
checkpoint restore, storage repair, or live recovery.

## Common mistakes

- Replication acknowledgments do not automatically carry consensus safety semantics.
- Sequence order from one sender does not prove agreement among competing proposers.
- Quorum means distinct eligible voters, not duplicate messages or raw packet count.
- A majority certificate is evidence for one decision, not proof every node applied the value.
- Majority intersection needs a one-vote-per-node-per-term rule to block conflicting values.
- Faster votes improve liveness only if the chosen threshold remains safe.
- A larger quorum can be safe but unavailable when too many nodes are absent.
- A local timeout or cancellation is not proof that no later global choice can occur.
- A timeout says insufficient evidence arrived by a deadline; it does not diagnose a crash.
- Cancellation of a pending proposal is not rollback of a completed decision.
- The q=2 certificate view proves a possibility; it does not execute a network partition.
- Fixed synthetic milliseconds are not measured latency, throughput, reliability, or performance.
- Static/reference checks are not MATLAB execution, UI validation, protocol testing, or hardware evidence.

## Completion standard

Run `run_checks`, answer one prompt from `checks.md` at a time, and give a two-sentence teach-back.
First relate round-trip vote timing, the q-th distinct vote, and quorum intersection. Then explain
how threshold, availability, timeout, or pending cancellation affects safety or progress without
claiming a full consensus protocol, rollback, recovery, MATLAB runtime, or physical validation.
