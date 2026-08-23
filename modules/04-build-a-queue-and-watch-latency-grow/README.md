# P04 — Build a Queue and Watch Latency Grow

**Track:** Distributed Real-Time Systems and Networks  
**Phase 1:** Network behavior  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you build a Queue and Watch Latency Grow?

## Compounds on P03

P03 showed that application records may reach the next stage periodically, remain absent as UDP
gaps, or become visible together after TCP closes a missing byte-stream prefix. P04 treats each
available record as one arrival to a deterministic finite-capacity FIFO server. Transport delivery
time becomes queue arrival time; queue waiting is a new latency component after transport.

## Computational mental model

For each admitted record `i`, let `A_i` be its arrival time, `S_i` its service start, `D_i` its
departure, and `s` the fixed service time:

- `S_i = max(A_i, D_previous admitted)`;
- FIFO waiting is `W_i = S_i - A_i`;
- system latency is `T_i = D_i - A_i = W_i + s`;
- for periodic arrivals with period `P`, nominal utilization is `rho = s/P`.

The finite capacity `K` counts all accepted unfinished records, including one in service. A
departure exactly at an arrival time frees its slot first. If `K` records remain unfinished when
the next record arrives, that record is tail-dropped; its waiting and latency are undefined, shown
as `NaN`, and it never advances the server clock. Equal-time arrivals keep record-index order.

At the baseline—12 records, `P = 4 ms`, `s = 6 ms`, `K = 4`, and a `20 ms` deadline—`rho = 1.5`.
Waiting grows to `18 ms`; accepted system latency reaches `24 ms`; 11 records are accepted, one is
dropped, eight finish on time, and three accepted records finish late. The deadline only classifies
usefulness. It does not cancel service or remove queued work.

## Controlled experiments

1. Read the recurrence and predict which latency component changes under overload.
2. Visualize baseline occupancy, waiting/system latency, and outcome counts.
3. Sweep arrival period through `[4 6 8] ms` while service, capacity, deadline, and arrival shape
   stay fixed.
4. Reset and sweep total system capacity through `[1 2 4 8]` records while the overload stays fixed.
5. Break the assumption that average utilization below one prevents latency spikes. Four records
   released together after a P03-style ordered-delivery gap create transient waiting and deadline
   misses even though `rho = 0.6`.
6. Run independent checks, answer one interpretation question at a time, and teach back the
   mechanism before its consequence.

## Transparent abstraction boundary

This is a bounded analytical D/D/1/K-style teaching model with at most 64 records, 64 unfinished
records of capacity, an eight-record release batch, and 2,016 admission comparisons. It uses one
FIFO server, deterministic arrivals, fixed service, tail drop, and no retry. It does not model
threads, locks, schedulers, packets, variable service, stochastic arrivals, priorities, queue
management, backpressure, memory allocation, wall-clock waiting, timeout, or cancellation. The
P03-style release burst is a causal teaching fixture, not a socket or operating-system trace.

## Files

- `model.m` — bounded FIFO admission, service, latency, deadline, and resource arithmetic.
- `experiment.m` — deterministic baseline, arrival-period and capacity sweeps, and broken
  average-rate assumption.
- `interactive.m` — arrival, service, capacity, deadline, and P03 release-shape controls with reset.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent invariants, limits, interpretation, and teach-back.

No toolbox is required. Static validation and independently recomputed reference arithmetic do not
imply MATLAB-runtime, UI, MATLAB numerical-fidelity, protocol, bench, HIL, field, deployment, or
production validation.
