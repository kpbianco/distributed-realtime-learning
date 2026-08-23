# P10 lesson: Preserve Message Ordering

## Guiding question

What inputs, observable effects, and failure modes matter when you preserve Message Ordering?

## Compounds on P09

P09 established that valid replicas can expose different versions while an update propagates. P10
keeps one receiver and introduces six successive versions. The new question is not whether a copy
eventually arrives; it is whether the receiver applies those versions in the sender's intended
order when path delays cross their arrivals.

## Mental model

One sender emits sequence numbers `1:6` every `10 ms`. For message `k`,

`t_arrive(k) = t_send(k) + s*d(k)`.

The delay scale `s` changes only path delay. It does not change emission order, sequence identity,
buffer capacity, or the receiver policy. Lower sequence wins an exact arrival-time tie, making the
fixture deterministic without relying on an implementation's sort stability.

The strict receiver maintains `nextExpected`. If that message arrives, it applies the version and
drains contiguous buffered successors. If a higher number arrives, it waits in a finite reorder
buffer. Its holding cost is

`hold(k) = t_deliver(k) - t_arrive(k)`.

A gap deadline and capacity bound prevent unbounded waiting/storage. This receiver fails closed:
it stops delivery on timeout or overflow instead of applying across the gap. That protects order,
but it can reduce availability and add head-of-line holding.

## One prediction before the baseline

Message `2` arrives before message `1`. If the receiver applies every arrival immediately, will
its state version move only upward, and which version will be visible after all six arrivals?

## Baseline observation

At scale `1`, the raw arrival sequence is `[2 1 4 6 3 5]`. Four sender-order pairs are inverted.
With capacity `2`, timeout `100 ms`, and strict ordering, the receiver instead delivers
`[1 2 3 4 5 6]`. Delivery times by sequence are `[20 20 55 55 65 65] ms`.

Messages `2`, `4`, and `6` wait `5`, `20`, and `15 ms`. The total is `40 message-ms`, and the
buffer holds at most two successors. That added holding is the visible cost of preserving the
contract in this fixture. Final state is latest version `6` and never regresses.

## Lever 1: path-delay scale

Hold capacity at the baseline `2 messages`, timeout at the baseline `100 ms`, all messages
available, and strict ordering.
Move only scale through `[0 0.5 1 2]`.

- Raw arrival inversions: `[0 2 4 4]`.
- Buffer high-water marks: `[0 1 2 2] messages`.
- Delivered holding: `[0 7.5 40 110] message-ms`.
- Completion times: `[50 52.5 65 90] ms`.

At scale zero, arrival equals emission time and even a zero-capacity reorder buffer is sufficient.
As delay dispersion grows, more successors arrive across gaps and wait longer. Sequence numbers do
not make the paths faster; they make crossed arrivals detectable.

## Lever 2: reorder-buffer capacity

Reset scale to `1`, timeout to `100 ms`, and message `3` to available. Move only capacity through
`[0 1 2] messages`.

- Capacity `0` rejects sequence `2` at `15 ms`, before any version is applied.
- Capacity `1` first delivers prefix `[1 2]`, then rejects sequence `6` at `50 ms` while sequence
  `4` occupies the only slot.
- Capacity `2` holds both successors and completes all six versions at `65 ms`.

Capacity changes how much reordering the receiver can absorb. It does not change arrival time or
the sequence gap. This finite holding requirement leads directly to P11's backpressure question:
what should upstream work do when a bounded receiver cannot accept more?

## Deliberately broken arrival-order assumption

Disable **Use sequence reorder buffer** while keeping the baseline arrivals. Every message is then
applied immediately in order `[2 1 4 6 3 5]`. State regresses twice (`2→1` and `6→3`) and finishes
at version `5`, even though version `6` arrived and every message was individually valid.

Zero holding looks fast, but it no longer satisfies the ordering contract. At delay scale zero the
same naive policy happens to produce `[1 2 3 4 5 6]`; an in-order observation in one case is not a
mechanism or guarantee.

## Exact deadline and missing-message behavior

At baseline scale, sequence `4` reveals a gap for expected sequence `3` at `35 ms`. With a `20 ms`
gap timeout, sequence `3` arrives exactly at the `55 ms` deadline and is accepted. With timeout
`20-1e-12 ms`, the deadline expires just before that arrival and only prefix `[1 2]` is delivered.

If message `3` is unavailable, the same `20 ms` deadline expires at `55 ms`. Sequences `4` and `6`
are buffered and sequence `5` has not yet been processed for delivery. The receiver stops without
crossing the gap. The timeout does not prove the missing message was never sent, and the fixture
does not identify why it is absent.

## Cancellation, rollback, and recovery boundary

Timeout is arithmetic classification; no clock or blocking wait runs. The event evaluator suppresses
remaining receiver delivery after failure, but it does not asynchronously cancel packets, tasks,
threads, or callbacks. None exists. Applied prefix `[1 2]` remains visible. No rollback is modeled
or performed because undoing applied versions would itself require another state transition.

Restoring message `3`, timeout, or capacity and calling the model again reproduces the ordered
target. That demonstrates the stateless deterministic recovery target after a failed or malformed
call. It does not execute retransmission, replay, duplicate suppression, durable recovery, or a
live protocol.

## Common mistakes

- Valid messages can still arrive in an order that is invalid for their state transition.
- Arrival order is evidence about path timing, not sender intent.
- Sequence numbers identify gaps; they do not reduce network delay.
- A reorder buffer preserves a prefix only while both its capacity and gap deadline hold.
- Head-of-line holding is a cost of strict order, not evidence of slower computation in the payload.
- Failing closed preserves order but may leave a stale prefix and reduce availability.
- A timeout is not proof of loss, and it does not imply cancellation or rollback.
- Per-sender FIFO order is not causal order across senders, global total order, atomic broadcast, or consensus.
- Trusted unique sequence numbers omit duplicates, corruption, wraparound, and authentication.
- Static/reference checks are not MATLAB execution, UI validation, transport testing, or hardware evidence.

## Completion standard

Run `run_checks`, answer one prompt from `checks.md` at a time, and give a two-sentence teach-back.
First relate `t_arrive`, `nextExpected`, and buffer holding to ordered delivery. Then explain how raw
arrival, capacity exhaustion, and gap timeout can cause regression or an incomplete prefix, while
stating the single-sender and evidence boundaries.
