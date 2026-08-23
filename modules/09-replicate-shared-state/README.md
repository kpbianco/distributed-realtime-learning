# P09 — Replicate Shared State

**Track:** Distributed Real-Time Systems and Networks  
**Phase 3:** Coordination and flow  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you replicate Shared State?

## Compounds on P08

P08 coordinated one schedule version at a shared future activation epoch. That makes the nodes'
configuration coherent at one transition; it does not make every later state update appear
everywhere at once. P09 keeps one deterministic primary and follows a single replicated-register
update as it becomes visible on three followers at different times.

## Computational mental model

The primary accepts version `1` at time zero. Replica `i` has transparent propagation delay `d_i`,
delay scale `s`, and validation/apply cost `c_i`, so its update becomes visible at

`t_apply_i = s*d_i + c_i`.

The fixture uses four replicas, base propagation delays `[0 10 30 70] ms`, and apply costs
`[0 5 5 5] ms`. At the baseline scale `s=1`, apply times are `[0 15 35 75] ms`. Until its own
apply time, a replica still exposes initial version `0` and value `40%`; afterward it exposes
version `1` and value `65%`.

A write requiring `W` acknowledgments responds at the `W`-th observed online acknowledgment,
provided that time is no later than the configured timeout. The fixture explicitly assigns zero
acknowledgment-return delay, so observed acknowledgment time equals apply time. That zero-cost,
lossless return is a teaching oracle, not a modeled transport path. The threshold covers one
single-writer update; it is not a quorum-consensus proof, atomic broadcast, conflict resolver, or
ordering protocol.

## Deterministic baseline

The baseline uses propagation scale `1`, `W=4`, an immediate read after the response, Replica D
online, and timeout `160 ms`.

- Apply times are `[0 15 35 75] ms` for Primary A and Replicas B–D.
- The write responds at `75 ms`, when all four replicas expose version `1`.
- Accumulated version lag is `0+15+35+75 = 125 replica-ms`.
- An immediate read routed to Replica D returns version `1` and value `65%`.

These are analytical timestamps and state values. They are not measurements from MATLAB,
network links, storage, clocks, threads, or physical nodes.

## Controlled experiments

1. Read the single-writer model and inspect the replica-version timeline.
2. Change the view to propagation delay plus apply cost for each replica.
3. Sweep only propagation scale through `[0.5 1 2]`. All-replica convergence and `W=4`
   response move through `[40 75 145] ms`; accumulated lag becomes `[70 125 235] replica-ms`.
4. Reset scale to `1`, then sweep only `W` through `[1 2 4]`. Response latency becomes
   `[0 15 75] ms`, and the current-replica count at response becomes `[1 2 4]`.
5. Deliberately set `W=1` and immediately read Replica D. The primary acknowledges at `0 ms`,
   but D still returns version `0`/`40%`. The broken assumption is that one acknowledgment means
   universal visibility.
6. Make the read wait until `75 ms`, or require all four acknowledgments, and observe version `1`.
7. Take D offline while requiring `W=4`. At the `100 ms` timeout, A–C already expose version `1`.
   The response is uncertain to the client; no applied state is rolled back. Restore D and
   reevaluate the fixture to observe convergence.
8. Run the independent checks, answer one interpretation question at a time, and teach back the
   mechanism before the symptom.

## Failure and claim boundary

The model classifies an acknowledgment timeout without blocking. A timeout can coexist with a
partial apply, so it does not mean that no replica changed. The model performs no automatic
rollback, cancellation, retry, deduplication, catch-up transfer, or failure detection. Restoring
Replica D in a fresh deterministic evaluation demonstrates the target recovered state, not a real
recovery protocol or side effect.

One writer and one update are deliberate boundaries. Concurrent writers, message reordering,
conflict resolution, quorum intersection, leader election, consensus, partitions, durable storage,
acknowledgment return delay/loss, message encoding, authentication, and process crashes are outside
this model. P10 next studies
ordering; P12 later builds consensus intuition. P09 establishes the smaller fact they depend on:
replicas can be temporarily different even when every received update is valid.

## Transparent abstraction and resource bound

Every call evaluates exactly four replicas and one update. Propagation scale is bounded to
`0–20`, read delay and timeout to `0–1e6 ms`, and acknowledgment count to integer `1–4`. Inputs
must be finite scalars. The model starts no background work and performs no random, file, storage,
timer, system, or network operation. Base MATLAB arithmetic and graphics are used; no toolbox is
required.

## Files

- `model.m` — deterministic apply, acknowledgment, read, timeout, and bounded-state calculations.
- `experiment.m` — baseline views, two independent sweeps, broken visibility assumption, and recovery boundary.
- `interactive.m` — delay, acknowledgment, read timing, availability, timeout, and reset controls.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent identities, limits, malformed recovery, interpretation, and teach-back.

Static validation and independently recomputed arithmetic do not imply MATLAB-runtime, UI,
MATLAB numerical-fidelity, protocol, storage, bench, HIL, field, deployment, or production validation.
