# P04 lesson: Build a Queue and Watch Latency Grow

## Guiding question

What inputs, observable effects, and failure modes matter when you build a Queue and Watch Latency Grow?

## Compounds on P03

P03 separated application send time from transport delivery time. UDP could expose later records
around a gap; TCP could release several ordered records when a missing prefix finally arrived. P04
starts at that delivery boundary: every record exposed by transport becomes an arrival to one FIFO
worker. Queue latency is therefore downstream of transport latency, not a replacement for it.

## Mental model

Picture a single worker and a finite holding area. An arriving record either joins the unfinished
work or is dropped if every slot is occupied. For an admitted record:

`service start = max(arrival, previous admitted departure)`

`waiting = service start - arrival`

`system latency = waiting + service time`

The capacity counts the worker's current record plus records waiting behind it. A coincident
departure frees a slot before admission. Records arriving together are ordered by record index.
Dropped records have no departure or latency, so treating their latency as zero would corrupt an
average.

For periodic arrivals, `rho = service time / arrival period` compares offered work with service
capacity. `rho < 1` drains an evenly spaced stream, `rho = 1` is the departure/arrival boundary,
and `rho > 1` grows backlog until a finite capacity forces drops. This ratio describes average
load; it does not describe every arrival shape.

## One prediction before the baseline

The arrival period is `4 ms` and service always takes `6 ms`. Will the service component or the
waiting component explain the change in system latency as more records arrive?

## Baseline observation

Inspect occupancy first. The server cannot finish each record before the next arrival, so
unfinished work accumulates toward the four-record capacity. Then inspect latency: service remains
exactly `6 ms`, while FIFO waiting grows from `0` to `18 ms`. Of 12 offered records, 11 are
accepted, one drops, eight finish by `20 ms`, and three accepted records finish late.

The dropped record is not a fast result. Its latency is undefined because no departure occurs.
Likewise, the deadline is an application classification: it labels stale accepted work but does
not cancel, dequeue, or speed it up.

## Lever 1: arrival period

Hold service at `6 ms`, capacity at four records, deadline at `20 ms`, and periodic shape fixed.
Move only the period through `[4 6 8] ms`. Utilization moves through `[1.5 1 0.75]`. At the
critical and underloaded cases, each arrival coincides with or follows the prior departure, so the
departure-first policy produces no waiting. Shortening the period to `4 ms` supplies work faster
than it can leave, making waiting, lateness, and eventually drops visible.

## Lever 2: finite capacity

Reset the period to `4 ms`, then move only capacity through `[1 2 4 8]` records. More storage
reduces drops `[6 3 1 0]`, but it cannot change the `6 ms` service time. Maximum accepted latency
therefore grows `[6 12 24 28] ms`. A larger queue can turn missing work into stale work; the best
capacity depends on whether the application values completeness, freshness, or both.

## Deliberately broken average-rate assumption

Compare eight smooth arrivals, ten milliseconds apart, with the same nominal stream after four
records become visible together at the P04 input. This represents P03's ordered transport releasing
a contiguous prefix after a gap. Both cases have `rho = 0.6`, no drops, and the same fixed service.
The smooth case stays at `6 ms` latency. The release burst reaches `24 ms` and misses three `15 ms`
deadlines. “Average utilization below one means latency cannot spike” is the violated assumption;
transient arrival shape is the recognizable cause.

## Common mistakes

- Utilization below one is a long-run average condition, not a per-record latency guarantee.
- Queue waiting and fixed service are different latency components.
- Capacity bounds unfinished work; it does not create throughput.
- A drop has undefined latency, not zero latency.
- Accepted does not mean on time, and a deadline does not cancel service.
- Departure-before-arrival and record-index tie handling are explicit policies, not universal facts.
- The deterministic release batch is a P03 connection, not measured TCP, socket, scheduler, or
  MATLAB-runtime behavior.
- This finite synchronous model performs no wall-clock wait, timeout, retry, or cancellation.

## Completion standard

Run `run_checks`, answer the interpretation questions in `checks.md`, identify the broken average-
rate assumption from its latency symptom, and give a two-sentence teach-back: FIFO mechanism first,
freshness/drop consequence second.
