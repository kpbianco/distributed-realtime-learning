# P04 checks: Build a Queue and Watch Latency Grow

## Independent numerical invariants

- For 12 periodic arrivals at `[0 4 8 ... 44] ms`, fixed `6 ms` service, and capacity four, derive
  accepted departures `[6 12 18 24 30 36 42 48 54 60 NaN 66] ms`.
- Derive FIFO waits `[0 2 4 6 8 10 12 14 16 18 NaN 16] ms` and system latencies
  `[6 8 10 12 14 16 18 20 22 24 NaN 22] ms`.
- Verify that record 11 drops when four earlier records remain unfinished. Its times remain `NaN`,
  and it does not advance record 12's departure beyond `66 ms`.
- Verify conservation: 12 offered equals 11 accepted plus one dropped. At a `20 ms` deadline,
  eight records are on time and three accepted records are late.
- For every accepted record, check FIFO order, `start >= arrival`,
  `departure = start + 6 ms`, and `latency = waiting + 6 ms`.
- Confirm occupancy never exceeds capacity and exact-time departures free capacity before admission.

## Sweep and limiting cases

- Sweep periods `[4 6 8] ms` with all other baseline inputs fixed. Derive utilization
  `[1.5 1 0.75]`, on-time counts `[8 12 12]`, drops `[1 0 0]`, and maximum accepted latencies
  `[24 6 6] ms`.
- Sweep capacity `[1 2 4 8]` records under the baseline overload. Derive on-time counts
  `[6 9 8 8]`, accepted-late counts `[0 0 3 4]`, drops `[6 3 1 0]`, and maximum accepted
  latencies `[6 12 24 28] ms`.
- At underload (`period > service`), verify zero waiting and no drops. At critical load
  (`period = service`) with capacity one, verify that the departure-before-arrival policy still
  accepts every record with zero waiting.
- At the one-record minimum, verify one admission, one service interval, and no queue waiting.
- Set a deadline exactly equal to an accepted record's latency and just below it. Equality is on
  time, and neither deadline changes the queue timeline.
- At 64 records and the largest time inputs, confirm relative arithmetic creates no artificial
  waiting at critical load.
- At the resource bound, confirm fixed 64-element outputs, occupancy at most 64, an eight-record
  release bound, and at most `64*63/2 = 2016` transparent admission comparisons.

## Deliberately broken case, timeout, and recovery

- Compare smooth `model(8,10,6,8,15,1)` with broken `model(8,10,6,8,15,4)`. Both have nominal
  utilization `0.6` and zero drops. Smooth latency remains `6 ms`; the P03-style release burst
  produces `[6 6 6 6 12 18 24 20] ms`, three deadline misses, and `24 ms` maximum latency.
- Reduce capacity to two with `model(8,10,6,2,15,4)`. At the four-record equal-time release,
  records 4 and 5 are admitted in record order, records 6 and 7 tail-drop with undefined times,
  and record 8 is admitted after record 4 departs. Its `2 ms` wait and `78 ms` departure show that
  dropped records neither reserve capacity nor advance later service.
- Name the violated assumption: an average utilization below one does not guarantee the absence of
  transient backlog or deadline misses when arrivals cluster.
- Reject non-scalar, complex, nonfinite, zero, dependent, and over-bound inputs, plus fractional
  values for discrete count/capacity/release fields, with stable identifiers. A valid baseline call
  after each failure must reproduce the same outputs.
- The model is a finite synchronous calculation. `actualWaitPerformed`, `timeoutModeled`, and
  `cancellationModeled` remain false; the deadline classifies but never cancels work. No fabricated
  wall-clock timeout or cancellation test is claimed.
- Repeated and accepted integer-class calls must reproduce the baseline with no global, persistent,
  file, timer, random, network, or UI state in the model.

## Interpretation questions

Answer one at a time:

1. Why does system latency grow when fixed service time does not?
2. What exactly does nominal utilization compare, and what arrival-shape information does it omit?
3. Why can increasing capacity reduce drops while increasing maximum accepted latency?
4. Why is a dropped record's latency undefined rather than zero?
5. How can P03 ordered recovery create a P04 transient queue even when the nominal rate is safe?
6. Which admission, tie, deadline, and drop policies would need to be stated before comparing this
   model with another queue?
7. What evidence would be required before treating these analytical results as MATLAB-runtime,
   scheduler, protocol, bench, HIL, or field behavior?

## Executable check and teach-back

Run:

```matlab
run_checks
```

All assertions must pass before completion is considered. Then teach back in two sentences:
mechanism first (`start`, `wait`, and `departure`), application consequence second (latency,
deadline, or drop).
