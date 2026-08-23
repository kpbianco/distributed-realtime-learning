# P11 lesson: Apply Backpressure

## Guiding question

What inputs, observable effects, and failure modes matter when you apply Backpressure?

## Compounds on P10

P10 preserved one sender's order by holding later messages in a finite receiver buffer. Once every
slot is occupied, ordering alone cannot say what the sender should do next. P11 makes that boundary
explicit: a completion returns one readiness credit, and a producer that honors readiness keeps
new work upstream instead of overflowing the receiver.

P04 supplies the FIFO service recurrence. The new observable is where overload waits: inside the
receiver, pending upstream, or nowhere because work was dropped.

## Mental model

One ordered producer has 12 demands. Demand `i` becomes ready at

`R_i = (i-1)P`,

where `P` is the producer interval in milliseconds. One FIFO consumer has fixed service time `s`
and `K` total receiver slots, including the message in service. With completion-credit
backpressure, admission `A_i` is the earliest time at or after `R_i` when fewer than `K` admitted
messages remain unfinished. A completion at that exact time frees its slot first. For an admitted
message,

`S_i = max(A_i, D_previous admitted)`,

`D_i = S_i + s`,

`B_i = A_i - R_i`, and `Q_i = S_i - A_i`.

`B_i` is upstream backpressure wait. `Q_i` is receiver FIFO wait. Moving wait between these two
places does not shorten `s` or create consumer throughput. This fixture assumes readiness feedback
has zero delay, so no messages overshoot a newly full receiver after a credit change.

## One prediction before the baseline

Demand becomes ready every `10 ms`, but the consumer completes only one message every `20 ms`.
If all 12 messages still complete and receiver occupancy never exceeds three, where must the
growing difference between offered and completed work become visible?

## Baseline observation

Start with `P=10 ms`, `s=20 ms`, `K=3 messages`, a `200 ms` maximum upstream wait, completion-credit
backpressure enabled, and no cancellation. The first five demands enter at their ready times. At
`50 ms`, message 6 finds three unfinished messages and remains upstream until the `60 ms`
completion returns a slot.

Admission then follows `[0 10 20 30 40 60 80 100 120 140 160 180] ms`. Upstream wait grows to
`70 ms` and totals `280 message-ms`. Receiver occupancy stays at or below three, while pending
upstream demand peaks at four. The consumer completes all messages, in source order, at
`[20 40 ... 240] ms`.

That is backpressure's mechanism in this fixture: do not admit past finite readiness; expose
overload as upstream waiting. It is not faster service and does not make the offered load ratio
`s/P = 2` disappear.

## Lever 1: producer interval

Hold service at `20 ms`, capacity at three, maximum wait at `200 ms`, policy enabled, and
cancellation disabled. Move only producer interval through `[5 10 20 30] ms`.

- Total upstream wait is `[585 280 0 0] message-ms`.
- Maximum upstream wait is `[125 70 0 0] ms`.
- Receiver high-water is `[3 3 1 1] messages`.
- Completion time is `[240 240 240 350] ms`.

At `P=5` and `10 ms`, demand becomes ready faster than service can finish it, so completion credits
pace receiver admission. At `P=20 ms`, a departure and the next demand coincide; departure-first
tie handling prevents a false full condition. At `P=30 ms`, the consumer idles, so the finite
12-message batch completes later even though no demand waits.

## Lever 2: receiver capacity

Reset producer interval to `10 ms` and move only capacity through `[1 2 3 6] messages`.

- Total upstream wait is `[660 450 280 10] message-ms`.
- Maximum upstream wait is `[110 90 70 10] ms`.
- Maximum receiver queue wait is `[0 20 40 100] ms`.
- Completion time remains `[240 240 240 240] ms`.

More slots admit demand earlier, which reduces upstream wait but allows more receiver queueing.
The service bottleneck still completes one message every `20 ms`. Capacity changes the location of
waiting, not the service rate. Capacity zero is an always-not-ready limit: the first demand times
out at its finite wait bound and later demand is suppressed without admission.

## Deliberately broken readiness assumption

Disable **Apply completion-credit backpressure** while keeping the baseline demand, service, and
capacity. Each demand now attempts admission at `R_i` even if the receiver reports no slot.
Messages `[6 8 10 12]` meet a full receiver and tail-drop. The accepted IDs are
`[1 2 3 4 5 7 9 11]`; eight complete at `160 ms`.

The broken assumption is “a producer can ignore receiver readiness without loss.” Zero upstream
wait looks attractive only because four messages disappeared. A system could choose reject,
drop-oldest, sample, shed load, or another explicit policy, but it cannot both exceed finite
admission capacity and silently preserve all work.

## Exact timeout and pending cancellation

At the baseline, message 6 needs exactly `10 ms` of upstream wait. With maximum wait `10 ms`, its
slot opening and deadline coincide, so readiness wins and message 6 is admitted at `60 ms`.
Message 7 would then need `20 ms`, so it times out at `70 ms` and later demand is suppressed. With
a bound just below `10 ms`, message 6 times out just before its slot opens and later demand is
suppressed immediately. This fail-closed choice retains P10's accepted ordered prefix.

Enable **Cancel message 6 if it is waiting**. Its deterministic cancellation request occurs at
`55 ms`, before its planned `60 ms` admission. Message 6 is removed from pending demand, messages
`1–5` drain, and later demands are suppressed so the accepted stream remains a prefix. If message
6 had already been admitted, the same request would be too late and could not undo service.

## Cancellation, rollback, and recovery boundary

This finite evaluator compares event timestamps. It performs no blocking wait or timer. The
cancellation branch removes only an unadmitted demand; it does not interrupt a thread, callback,
packet, or consumer because none exists. The fixture suppresses later source demand after timeout
or cancellation to retain an ordered prefix. Accepted messages are neither canceled nor rolled back.

Restoring policy, wait bound, capacity, or cancellation and calling `model` again reproduces a
lossless target. That is stateless reevaluation, not retry, replay, retransmission, checkpoint
restore, durable recovery, or a live credit protocol.

## Common mistakes

- Backpressure bounds receiver admission; it does not erase overload or create service capacity.
- Offered demand, admitted work, queued work, completed work, and failed work are different counts.
- Upstream waiting can grow even while receiver occupancy remains safely bounded.
- A bigger receiver moves wait downstream and can increase receiver latency without improving throughput.
- A completion credit is readiness information, not an extra service completion.
- A timeout is a local demand decision, not proof that the receiver failed.
- Pending cancellation is not rollback of work already admitted.
- Ignoring readiness can look lower-latency because dropped messages have no completion latency.
- Instantaneous feedback omits delayed-credit overshoot, transport windows, and distributed propagation.
- Fixed 12-message arithmetic is not a wall-clock run, throughput benchmark, or capacity measurement.
- Static/reference checks are not MATLAB execution, UI validation, transport testing, or hardware evidence.

## Completion standard

Run `run_checks`, answer one prompt from `checks.md` at a time, and give a two-sentence teach-back.
First relate demand readiness, completion credit, finite receiver capacity, and upstream wait.
Then explain how offered rate, storage, timeout, cancellation, or ignored readiness changes where
work waits or fails without claiming actual blocking, rollback, recovery, MATLAB runtime, or
physical validation.
