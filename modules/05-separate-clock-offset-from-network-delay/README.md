# P05 — Separate Clock Offset from Network Delay

**Track:** Distributed Real-Time Systems and Networks  
**Phase 2:** Time and synchronization  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you separate Clock Offset from Network Delay?

## Compounds on P04

P04 made queue waiting visible as part of arrival-to-departure latency. P05 places that network
delay between two clocks. A sender timestamps an event with clock A and a receiver timestamps its
arrival with clock B. Queueing may change from sample to sample, but a constant portion of path
delay can look exactly like a clock offset in one-way data.

## Computational mental model

With clock B ahead of clock A by `theta` milliseconds and true one-way network delay `d_i`, the
measured timestamp difference is

`z_i = receiver timestamp_i - sender timestamp_i = theta + d_i`.

One equation contains two unknown terms. Repeated samples reveal delay *variation*, because
`max(z)-min(z) = max(d)-min(d)`, but they do not by themselves identify the constant parts. This
lesson supplies an external minimum-delay anchor `d_min`. It must be the exact attainable total
fixed-delay floor, not merely a lower bound, and at least one sample must reach it. Then

`theta_hat = min(z) - d_min`, and `d_hat_i = z_i - theta_hat`.

At the baseline—eight paired timestamps, `theta = 7 ms`, a known `3 ms` propagation floor, and
variable P04-style queue delay `[0 2 6 4 8 2 4 0] ms`—the observed differences are
`[10 12 16 14 18 12 14 10] ms`. The lower envelope recovers `theta_hat = 7 ms`; estimated and true
network delay both equal `[3 5 9 7 11 5 7 3] ms`.

## Controlled experiments

1. Read the sum equation and predict whether one observed timestamp difference is a clock error or
   a network delay.
2. Visualize the deterministic baseline observation and its anchored decomposition.
3. Sweep clock offset through `[-8 0 12] ms` while the delay trace stays fixed. Every observation
   translates equally, but its spread stays `8 ms`.
4. Reset and sweep queue-delay peak through `[0 4 12] ms` while the offset stays `7 ms`. The lower
   envelope stays fixed, while spread follows the changing delay.
5. Break the minimum-delay assumption by hiding a constant `5 ms` network component. The true
   `(7 ms offset, 5 ms hidden delay)` case produces exactly the same observations as a
   `(12 ms offset, 0 ms hidden delay)` case. The estimator reconstructs every observation but is
   wrong by `5 ms` about both terms.
6. Run independent checks, answer one interpretation question at a time, and teach back the
   mechanism before its consequence.

## Transparent abstraction boundary

This is a bounded analytical one-way timestamp model with at most 64 paired samples and a fixed,
visible eight-value queue profile. It assumes exact timestamps, correct event pairing, constant
clock offset, no clock skew or measurement noise, and an externally supplied minimum-delay anchor.
It does not estimate an anchor from a protocol, perform an NTP-style two-way exchange, synchronize
a clock, read a network or hardware timestamp, wait, time out, cancel work, or model packet loss.
Those omissions keep P06's exchange mechanism separate and make the identifiability limit visible.

## Files

- `model.m` — bounded timestamp, delay, anchor, estimate, error, and ambiguity arithmetic.
- `experiment.m` — deterministic baseline, offset and queue-delay sweeps, and the aliased broken
  assumption.
- `interactive.m` — offset, queue peak, hidden common delay, and assumed-floor controls with reset.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent invariants, limits, interpretation, and teach-back.

No toolbox is required. Static validation and independently recomputed arithmetic do not imply
MATLAB-runtime, UI, MATLAB numerical-fidelity, protocol, bench, HIL, field, deployment, or
production validation.
