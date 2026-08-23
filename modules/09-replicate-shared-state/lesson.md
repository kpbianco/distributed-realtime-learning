# P09 lesson: Replicate Shared State

## Guiding question

What inputs, observable effects, and failure modes matter when you replicate Shared State?

## Compounds on P08

P08 used bounded clock error and one coherent schedule version to coordinate a future transition.
P09 begins after that coherent transition. A primary can accept a new runtime value while one or
more replicas still expose the old value. Shared activation solves neither propagation time nor
the meaning of a write acknowledgment.

## Mental model

Use a single replicated register. It begins at version `0`, value `40%`. Primary A accepts version
`1`, value `65%`, at time zero. Replica `i` applies that version at

`t_apply_i = s*d_i + c_i`,

where `s` scales propagation delay `d_i` and `c_i` is validation/apply cost. Before that exact
boundary, the replica returns version `0`; at or after it, the replica returns version `1`.

The write policy asks for `W` apply acknowledgments. The fixture gives every acknowledgment a
zero-cost, lossless return path, so observed acknowledgment time equals apply time and response is
the `W`-th smallest online apply time. That equality is a teaching oracle, not network behavior.
If the threshold time is unavailable or later than the timeout, the client receives a timeout
classification. The finite model does no waiting. A timeout says the requested evidence did not
arrive in time; it does not prove that zero replicas applied the update.

This fixture has one writer and one update. Therefore it can isolate propagation, visibility,
acknowledgment, and timeout behavior without claiming to solve ordering or agreement among
concurrent writers.

## One prediction before the baseline

If the write waits only for Primary A but the immediate read is routed to slow Replica D, which
version will D expose and why?

## Baseline observation

At propagation scale `1`, apply times are `[0 15 35 75] ms`. With `W=4` and timeout `160 ms`,
the response occurs at `75 ms`. All four replicas then expose version `1`, so an immediate read
from D returns `65%`.

The accumulated version-lag exposure is `125 replica-ms`: each replica contributes the time it
remains on version `0`, namely `0+15+35+75`. This metric describes the deterministic fixture; it
is not measured load, bandwidth, or storage performance.

## Lever 1: propagation delay scale

Hold `W=4`, the read delay at zero, D online, and timeout at `160 ms`. Move only scale through
`[0.5 1 2]`. Apply-time vectors become `[0 10 20 40]`, `[0 15 35 75]`, and
`[0 25 65 145] ms`. All-replica response/convergence becomes `[40 75 145] ms`, while accumulated
lag becomes `[70 125 235] replica-ms`.

Propagation scale changes when replicas can expose the version. It does not change the state
value, the requested acknowledgment count, or the single-writer assumption.

## Lever 2: acknowledgment count

Reset scale to `1`. Move only `W` through `[1 2 4]`. Response latency becomes `[0 15 75] ms`,
and current replicas at response become `[1 2 4]`. An immediate read from D returns versions
`[0 0 1]`.

A smaller `W` reduces response latency by asking for less evidence. It does not accelerate any
replica. The tradeoff is response latency versus how much visibility the response establishes in
this exact one-update model.

## Deliberately broken universal-visibility assumption

Set scale `1`, `W=1`, read delay `0`, D online, and timeout `160 ms`. Primary A applies and
acknowledges at `0 ms`; B, C, and D still expose version `0`. The client then reads D at the same
time and gets `40%`, even though its write call succeeded.

The policy itself can be useful when low latency matters. The broken step is interpreting a
primary-only acknowledgment as proof of universal visibility. Waiting `75 ms`, routing the read
to a known-current replica, or requiring `W=4` changes the evidence available to the client.

## Timeout, rollback, cancellation, and recovery

Take D offline, require `W=4`, and use a `100 ms` timeout. The fourth acknowledgment is
unreachable, so the response times out at `100 ms`; A–C have nevertheless applied version `1`.
There is no automatic rollback. Reversing a partially visible update would itself require another
coordinated state transition.

The timeout is an arithmetic deadline comparison, not a timer or blocking wait. There is no
background request to cancel, and cancellation is outside the fixture. Restoring D and evaluating
the same update again produces all-replica convergence at `75 ms`; that establishes a recovery
target, not a tested catch-up, retry, deduplication, or durable-restore protocol.

## Common mistakes

- Replication copies state; it does not make propagation instantaneous.
- Acknowledged means the requested count applied, not that every read target is current.
- A timeout does not prove that no replica changed.
- Partial apply is not automatically rolled back when a response times out.
- An unavailable read is different from a successful stale read.
- Requiring all four acknowledgments improves visibility evidence here but loses availability if
  any required replica is offline.
- `W` is an acknowledgment count in a single-writer fixture, not a consensus quorum proof.
- Apply and acknowledgment observation coincide only because return delay/loss is explicitly omitted.
- P10's message ordering and P12's consensus questions remain separate mechanisms.
- The delays and values are synthetic; no MATLAB runtime, network, storage engine, or hardware was measured.

## Completion standard

Run `run_checks`, answer one prompt from `checks.md` at a time, and give a two-sentence teach-back.
First relate apply time and the `W`-th acknowledgment to response latency. Then explain the stale
read and timeout/partial-apply symptoms without claiming universal visibility, rollback, ordering,
or consensus.
