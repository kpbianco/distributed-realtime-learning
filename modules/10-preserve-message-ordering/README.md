# P10 — Preserve Message Ordering

**Track:** Distributed Real-Time Systems and Networks  
**Phase 3:** Coordination and flow  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you preserve Message Ordering?

## Compounds on P09

P09 followed one version as it became visible on replicas at different times. P10 adds successive
updates: one sender emits versions `1` through `6`, and unequal path delays let later versions
arrive first. A receiver that applies each valid arrival immediately can therefore move shared
state backward even though no individual message is malformed.

## Computational mental model

Message `k` is sent at

`t_send(k) = (k-1)*10 ms`

and arrives on a shared analytical timeline at

`t_arrive(k) = t_send(k) + s*d(k)`,

where path-delay scale `s` multiplies the fixed delay vector
`d = [20 5 35 5 25 0] ms`. Equal arrival times use lower sequence number first as an explicit
deterministic tie rule.

The strict receiver begins with expected sequence `1`. It applies that message, increments the
expected number, and drains every contiguous successor already held in its reorder buffer. A
higher sequence waits. The receiver fails closed if adding a successor would exceed the finite
buffer or if the expected sequence has not arrived by the exact gap deadline. A message at the
deadline is accepted; a later one is not.

Each message assigns its sequence number as the receiver's state version. That non-commutative
visible state makes a wrong order recognizable: applying version `5` after version `6` regresses
state. Sequence numbers preserve only this one sender's stream order. They do not establish causal
order across senders, a global total order, atomic broadcast, exactly-once processing, or consensus.

## Deterministic baseline

The baseline uses delay scale `1`, buffer capacity `2 messages`, gap timeout `100 ms`, all messages
available, and strict sequence delivery.

- Send times are `[0 10 20 30 40 50] ms`.
- Arrival times by sequence are `[20 15 55 35 65 50] ms`.
- Raw arrival order is `[2 1 4 6 3 5]`, with four pairwise inversions.
- Strict delivery order is `[1 2 3 4 5 6]` at `[20 20 55 55 65 65] ms`.
- Per-message holding is `[0 5 0 20 0 15] ms`, totaling `40 message-ms`.
- Buffer occupancy after the six arrival events is `[1 0 1 2 1 0] messages`; its high-water mark is
  `2 messages`.
- The final applied state is version `6`, with no state regression.

These values are deterministic event arithmetic. They are not timestamps measured from MATLAB,
packets, sockets, threads, operating systems, networks, storage, or physical devices.

## Controlled experiments

1. Read the send/arrival equation and inspect sender emission, raw arrival, and strict delivery in
   one timing view.
2. Change to buffer occupancy and per-message holding. Connect each positive hold to a lower
   sequence that has not arrived yet.
3. Sweep only delay scale through `[0 0.5 1 2]`. Raw inversions become `[0 2 4 4]`, buffer
   high-water becomes `[0 1 2 2] messages`, and delivered holding becomes
   `[0 7.5 40 110] message-ms`.
4. Reset scale to `1`, then sweep only buffer capacity through `[0 1 2] messages`. Delivered counts
   before completion/failure are `[0 2 6]`; decisions occur at `[15 50 65] ms`. Capacity `2` is
   the exact baseline success boundary.
5. Deliberately disable strict sequence delivery. Raw order `[2 1 4 6 3 5]` is applied with zero
   holding, causing two state regressions and leaving stale version `5` after version `6`.
6. Set the gap timeout to `20 ms`. Message `3` arrives at the exact deadline and completes. Set it
   just below `20 ms`, or make message `3` unavailable, and the receiver stops after prefix `[1 2]`.
7. Use capacity `1`: sequence `6` reaches the receiver at `50 ms` while sequence `4` already fills
   the only slot, so the stream fails closed after prefix `[1 2]`.
8. Restore the message, timeout, and capacity in a fresh call. The deterministic target completes;
   no retransmission, replay, cancellation, rollback, or recovery protocol was executed.
9. Run the independent checks, answer one interpretation question at a time, and teach back the
   mechanism before the symptom.

## Timeout, cancellation, rollback, and recovery boundary

A gap timeout is an arithmetic comparison in a finite event loop, not a blocking timer. After a
timeout or overflow, the model suppresses remaining receiver delivery. It does not cancel a packet,
thread, task, callback, or network operation because none exists. Messages already applied as an
ordered prefix remain applied; no rollback is modeled or performed.

Making message `3` available again or increasing capacity in a new stateless call demonstrates a
recovery target only. A real system would need an explicit retransmission/replay request, duplicate
handling, sequence-window policy, durable progress, and failure recovery. Those mechanisms are not
smuggled into this lesson.

## Transparent abstraction and resource bound

Every call evaluates exactly six messages and at most six arrival events. Delay scale is bounded to
`0–20`, buffer capacity to integer `0–6 messages`, and gap timeout to `0–1e6 ms`. Inputs must be
finite real scalars; availability and policy controls must be logical/numeric `0` or `1`. Derived
time is bounded below `1.001e6 ms`; message-indexed vectors have six elements, the arrival-event
table has at most six rows and two columns, and every loop bound is at most six messages.

The model uses base MATLAB arithmetic and transparent `sortrows` tie-breaking. It has no random,
global, persistent, file, storage, timer, system, network, parallel, or background operation. It
assumes trusted, unique, non-wrapping sequence numbers from one sender. Authentication, corruption,
duplicates, wraparound, multiple senders, causal/global order, transport guarantees, replication,
consensus, and backpressure are outside the model. P11 next examines the pressure created when held
work meets finite capacity.

## Files

- `model.m` — deterministic arrivals, sequence buffering, deadline/capacity failure, and state trace.
- `experiment.m` — two baseline views, two independent sweeps, broken arrival-order policy, and recovery boundary.
- `interactive.m` — delay, capacity, timeout, availability, ordering-policy, and reset controls.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent identities, exact limits, malformed recovery, interpretation, and teach-back.

Static validation and independently recomputed reference arithmetic do not imply MATLAB-runtime,
UI, MATLAB numerical-fidelity, transport, bench, HIL, field, deployment, or production validation.
