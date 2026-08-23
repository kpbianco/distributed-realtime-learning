# P06 — Model NTP-Style Exchange

**Track:** Distributed Real-Time Systems and Networks  
**Phase 2:** Time and synchronization  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you model NTP-Style Exchange?

## Compounds on P05

P05 showed that one receiver-minus-sender timestamp contains `clock offset + one-way delay`, so a
constant path delay aliases with clock offset. P06 adds a request and a reply. The client records
transmit timestamp `T1` and receive timestamp `T4`; the server records receive timestamp `T2` and
transmit timestamp `T3`. Four timestamps expose a round-trip constraint, but the offset result is
still conditional on a named assumption about the two path directions.

## Computational mental model

Let `theta` be **server clock minus client clock**, `d_f` the forward network delay, `d_r` the
reverse network delay, and `p` the server residence/processing time. With the client clock used as
the reference, the four local timestamp readings are

- `T1 = T0`;
- `T2 = T0 + d_f + theta`;
- `T3 = T0 + d_f + p + theta`; and
- `T4 = T0 + d_f + p + d_r`.

The NTP-style arithmetic is visible rather than hidden behind a protocol API:

`theta_hat = ((T2-T1) + (T3-T4))/2 = theta + (d_f-d_r)/2`

`delta_hat = (T4-T1) - (T3-T2) = d_f + d_r`.

Subtracting the server residence `T3-T2` removes processing time from the network round-trip
estimate. The offset estimate is exact when the path is symmetric. When it is not, half the signed
path asymmetry becomes offset error. For positive round-trip delay, the four observations cannot
generally reveal how delay split between directions. In ideal arithmetic, the truth-only
zero-round-trip limit is the trivial exception: nonnegative directional delays must both be zero.

At the baseline, `(T0, theta, d_f, d_r, p) = (100, 7, 4, 4, 2) ms`. The local timestamp vector is
`[100 111 113 110] ms`, client elapsed time is `10 ms`, server residence is `2 ms`, estimated
network round trip is `8 ms`, and estimated offset is the true `7 ms`.

## Controlled experiments

1. Read the four-event mechanism and make one prediction before viewing the baseline.
2. Visualize the deterministic event path and the two offset terms that bracket the estimate.
3. Sweep true server-minus-client offset through `[-8 0 12] ms` with both directions fixed at
   `4 ms`. The estimate tracks offset while network round trip stays `8 ms`.
4. Reset offset to `7 ms`, then sweep symmetric one-way delay through `[1 4 10] ms`. Estimated
   round trip changes through `[2 8 20] ms`, while estimated offset stays `7 ms`.
5. Break path symmetry with `7 ms` forward and `1 ms` reverse delay. That true `7 ms` offset case
   produces exactly the same four timestamps as a symmetric `4/4 ms` path with true offset
   `10 ms`. The asymmetric case is biased by `+3 ms` even though every arithmetic residual is zero.
6. Run independent checks, answer one interpretation prompt at a time, and teach back mechanism
   before consequence.

## Transparent abstraction boundary

This is one bounded, deterministic, two-message analytical exchange with exactly four ideal
software timestamp values. It is NTP-style arithmetic, not a full NTP implementation. It performs
no socket or network I/O, clock read, clock adjustment, timer wait, timeout, cancellation, retry,
packet selection, filtering, polling, timestamp-format conversion, authentication, leap handling,
or packet-loss recovery. It assumes equal client/server clock rates during the exchange and has no
clock skew, noise, timestamp quantization, route change, or multiple-server behavior. Truth-only
symmetry diagnostics are generally unavailable to real endpoints. The simulator separately marks
the ideal zero-delay truth boundary; finite timestamp precision may still obscure it in represented
intervals. Hardware timestamp placement and its error boundary remain P07's topic.

All five inputs are finite scalars bounded to `1e6 ms`; delay and processing inputs are
nonnegative. Work is fixed at four timestamps. At extreme absolute time origins, subtractive
floating-point cancellation can make the raw computed round trip slightly negative even though
truth delay is nonnegative. The model retains that raw value and residual, normalizes the physical
teaching estimate to zero, and exposes whether normalization occurred. No toolbox is required.
Truth-only symmetry and zero-round-trip classifications compare the provided directional delays
exactly, so shifting the arbitrary time origin cannot change the physical truth state.

## Files

- `model.m` — bounded four-event truth, local timestamps, estimator arithmetic, errors, and claim
  boundaries.
- `experiment.m` — deterministic baseline, offset and symmetric-delay sweeps, and exact asymmetry
  alias.
- `interactive.m` — offset, forward delay, reverse delay, and server-residence controls with reset.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent invariants, limits, malformed recovery, questions,
  and teach-back.

Static validation and independently recomputed arithmetic do not imply MATLAB-runtime, UI,
MATLAB numerical-fidelity, NTP protocol, clock-device, bench, HIL, field, deployment, or production
validation.
