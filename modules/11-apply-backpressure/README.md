# P11 — Apply Backpressure

**Track:** Distributed Real-Time Systems and Networks  
**Phase 3:** Coordination and flow  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you apply Backpressure?

## Compounds on P10

P10 held later sequence numbers in a finite receiver buffer so they could not cross an earlier
gap. P11 keeps ordered messages but changes the control question: when all receiver slots are
occupied, does the producer defer work upstream or keep pushing and lose it? P04's queue equations
still explain FIFO service; P11 adds a visible readiness contract at the admission boundary.

## Computational mental model

Twelve demands become ready every `P ms` and one FIFO consumer takes `s ms` per admitted message.
Capacity `K` counts every unfinished receiver message, including the one in service. If demand `i`
becomes ready at `R_i`, completion credit makes its admission time the earliest `A_i >= R_i` with
fewer than `K` unfinished receiver messages. A completion at `A_i` returns its slot before the
coincident admission. Then

`S_i = max(A_i, D_previous admitted)`

`D_i = S_i + s`.

The producer-side wait is `B_i = A_i - R_i`; receiver queue wait is `Q_i = S_i - A_i`. Completion
credit is instantaneous in this analytical fixture. No wire-level credit/window protocol, feedback
delay, overshoot, blocking thread, or wall-clock timer runs.

With backpressure enabled, a full receiver leaves fixed demand pending upstream until a slot opens.
If the slot cannot open by `R_i + W_max`, that pending demand times out. An optional cancellation
request targets message 6 at `R_6 + 5 ms` and removes it only if it is still pending. Readiness wins
an exact tie with timeout or cancellation. With backpressure disabled, every demand attempts
admission at `R_i`; a full receiver tail-drops it immediately.

## Deterministic baseline

The baseline uses producer interval `10 ms`, service time `20 ms`, receiver capacity `3 messages`,
maximum upstream wait `200 ms`, backpressure enabled, and no cancellation.

- Demand-ready times are `[0 10 20 30 40 50 60 70 80 90 100 110] ms`.
- Admission times are `[0 10 20 30 40 60 80 100 120 140 160 180] ms`.
- Completion times are `[20 40 60 80 100 120 140 160 180 200 220 240] ms`.
- Upstream waits are `[0 0 0 0 0 10 20 30 40 50 60 70] ms`, totaling
  `280 message-ms` with a `70 ms` maximum.
- Receiver queue waits are `[0 10 20 30 40 40 40 40 40 40 40 40] ms`.
- Receiver occupancy never exceeds `3 messages`; upstream pending demand peaks at `4 messages`.
- All 12 messages complete in source order at `240 ms`; backpressure creates no service capacity.

These are deterministic finite-event calculations, not MATLAB timing measurements or observations
from producers, consumers, threads, queues, transports, operating systems, networks, or hardware.

## Controlled experiments

1. Read `R_i -> A_i -> S_i -> D_i`, then inspect demand, admission, and completion in one view.
2. Change to receiver occupancy and upstream pending demand. Identify where overload waits.
3. Sweep only producer interval through `[5 10 20 30] ms`. Total upstream wait becomes
   `[585 280 0 0] message-ms`; all messages still complete because the `200 ms` wait bound holds.
4. Reset interval to `10 ms`, then sweep only capacity through `[1 2 3 6] messages`. Upstream wait
   falls `[660 450 280 10] message-ms`, while maximum receiver queue wait rises
   `[0 20 40 100] ms`; completion remains `240 ms` in every case.
5. Deliberately disable **Apply completion-credit backpressure**. Messages `[6 8 10 12]` arrive
   while all three receiver slots are occupied and drop. Only eight messages complete.
6. Set maximum wait to exactly `10 ms`: message 6 is admitted at its deadline, then message 7
   exceeds that bound and stops the ordered stream. Set it just below `10 ms`: message 6 times out
   immediately before its slot would open and later demand is suppressed.
7. Request cancellation of message 6. It is pending from `50` to `60 ms`, so the request at `55 ms`
   stops on ordered prefix `[1 2 3 4 5]` without undoing those five admitted messages.
8. Restore the baseline in a fresh stateless call. All 12 messages complete; no retry, replay,
   rollback, durable restore, or live recovery protocol was executed.
9. Run independent checks, answer one interpretation question at a time, and teach back the
   mechanism before the symptom.

## Timeout, cancellation, rollback, and recovery boundary

Wait and timeout are arithmetic differences between finite event times, not blocking calls or
wall-clock timers. Cancellation is a deterministic decision on one still-pending demand; it does
not interrupt accepted service or asynchronously signal a producer task. To retain P10's ordered
prefix, a timeout or cancellation suppresses later demand in this fixture. Timed-out, canceled,
suppressed, and dropped messages are never admitted. Already accepted work completes and is not
rolled back.

A fresh call with a larger wait bound, restored policy, or no cancellation demonstrates a recovery
target only. The model performs no retry, retransmission, credit exchange, replay, checkpoint,
durable queue restore, or process recovery.

## Transparent abstraction and resource bound

Every call evaluates exactly 12 demands, at most 12 release scans per demand, at most 638
prior-completion comparisons, and at most 36 observation instants. Producer interval and service time are bounded to
`1–1000 ms`, receiver capacity to integer `0–12 messages`, and maximum wait to `0–1e6 ms`; derived
time stays at or below `1.012e6 ms`.

The model uses base MATLAB scalar/vector arithmetic and bounded `for` loops. It has no random,
global, persistent, file, storage, timer, system, transport, network, parallel, or background
operation. It assumes one ordered producer, one FIFO consumer, lossless instantaneous readiness
feedback when enabled, fixed service, and a fixed 12-demand source backlog. Multiple producers,
fairness, priorities, variable service, delayed/stale feedback, credit/window protocols, retries,
distributed queue memory, transport flow control, and end-to-end deadline guarantees are omitted.

## Files

- `model.m` — deterministic readiness, admission, FIFO service, timeout/cancellation, and flow accounting.
- `experiment.m` — two baseline views, two independent sweeps, broken readiness policy, and recovery boundary.
- `interactive.m` — producer, consumer, capacity, wait, readiness-policy, cancellation, and reset controls.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent identities, exact limits, malformed recovery, interpretation, and teach-back.

Static validation and independently recomputed reference arithmetic do not imply MATLAB-runtime,
UI, MATLAB numerical-fidelity, transport, bench, HIL, field, RT1/RT2, Unreal, deployment, or
production validation.
