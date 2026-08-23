# P07 — Model PTP Hardware Timestamping

**Track:** Distributed Real-Time Systems and Networks  
**Phase 2:** Time and synchronization  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you model PTP Hardware Timestamping?

## Compounds on P06

P06 used four endpoint-local timestamps to estimate clock offset and network round trip. It showed
that server/follower turnaround cancels, while half the forward/reverse path difference aliases
with offset. P07 keeps that estimator and makes a new question visible: where, relative to the
wire, was each timestamp captured?

## Computational mental model

Use `theta = follower clock - leader clock`. `T1` is leader Sync transmit, `T2` is follower
receive, `T3` is follower Delay_Req transmit, and `T4` is leader receive. At an ideal wire
reference plane,

`theta_hat = ((T2-T1) + (T3-T4))/2 = theta + (d_f-d_r)/2`

`delay_hat = (T4-T1) - (T3-T2) = d_f+d_r`.

If captured timestamp `i` differs from its reference-plane value by `e_i`, the visible equations
become

`theta_hat = theta + (d_f-d_r)/2 + (e2-e1+e3-e4)/2`

`delay_hat = d_f+d_r + e4-e1-e3+e2`.

Software transmit stamps in this lesson occur before a deterministic host/NIC path, and software
receive stamps occur after it. Their larger, varying placement terms enter `e_i`. The modeled
hardware stamps occur near the reference plane. Four fixed teaching-fixture pipeline offsets are
then quantized to a configurable tick; configured egress corrections are added and ingress
corrections are subtracted. Round-to-nearest with exact half-tick ties away from zero is this
lesson's explicit quantizer, not a claim about every device.

Near-wire capture can exclude the modeled host path. It cannot make four-timestamp arithmetic
immune to path asymmetry, coarse ticks, mismatched clock domains, missing timestamp correlation,
or wrong reference-plane calibration. Precision (small repeated spread) is not accuracy (small
error from truth).

## Deterministic baseline

Eight exchanges use `(start, theta, d_f, d_r, turnaround) =
(100000, 120, 800, 800, 4000) ns`, a host-path scale of `1`, an `8 ns` hardware tick, and complete
reference-plane calibration.

- Software offset estimates are `[170 320 120 270 220 70 420 120] ns`: mean `213.75 ns`,
  `350 ns` peak-to-peak, and `300 ns` maximum absolute error.
- Corrected hardware estimates are `[118 118 122 118 122 122 118 122] ns`: mean `120 ns`,
  `4 ns` peak-to-peak, and `2 ns` maximum absolute error.
- True network round trip is `1600 ns`. Software estimates span `4500–5200 ns`; hardware estimates
  are `1596` or `1604 ns`.
- Every raw hardware rounding residual is at most half the configured tick (`4 ns`).

These values are deterministic analytical outputs. They are not timestamps measured from software,
a kernel, a NIC, a PHY, or a PTP hardware clock.

## Controlled experiments

1. Read the four error terms and make the prediction in `lesson.md`.
2. Compare software and corrected-hardware offset estimates, then inspect the timestamp-placement
   error at `T1` through `T4`.
3. Sweep host timestamp-path scale through `[0 1 2]`, holding hardware tick and calibration fixed.
   Software offset spread changes through `[0 350 700] ns`; hardware spread stays `4 ns`.
4. Reset host scale to `1`, then sweep hardware tick through `[1 8 64] ns`. Hardware offset spread
   changes through `[0 4 32] ns`; the software trace remains unchanged.
5. Deliberately omit hardware reference-plane calibration at a `1 ns` tick. All eight hardware
   offset estimates become the same precise-looking `150 ns` even though truth is `120 ns`; round
   trip becomes `1740 ns` instead of `1600 ns`.
6. Restore calibration, make the wire path asymmetric, and recall P06: even fine near-wire stamps
   inherit half the directional delay difference as offset bias.
7. Run independent checks, answer one interpretation prompt at a time, and teach back mechanism
   before consequence.

## Transparent abstraction and resource boundary

This is a bounded analytical capture-placement model with eight exchanges and 32 timestamps. It
does not implement IEEE 1588 messages, one-step/two-step operation, correction fields, transparent
clocks, Best Master Clock selection, timestamp correlation, TX timestamp delivery, a servo, PHC
or system-clock conversion, clock adjustment, sockets, network I/O, packet loss, blocking waits,
timeouts, cancellation, or fallback behavior. The fixed software patterns and hardware pipeline
offsets are teaching fixtures, not device specifications or empirical distributions.

Time inputs are finite scalars bounded to `1e6 ns`; host scale is bounded to `0–4`, hardware tick
to `0.125–1024 ns`, and calibration fraction to `0–2`. Work remains fixed at eight exchanges.
Base MATLAB arithmetic is used; no toolbox is required.

## Files

- `model.m` — deterministic reference-plane truth, capture errors, estimators, identities, bounds,
  and claim flags.
- `experiment.m` — baseline views, host-path and hardware-tick sweeps, and broken calibration.
- `interactive.m` — host scale, tick, calibration, and reverse-path controls with reset.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent invariants, limits, malformed recovery, questions,
  and teach-back.

Static validation and independently recomputed arithmetic do not imply MATLAB-runtime, UI,
MATLAB numerical-fidelity, PTP protocol, kernel, NIC, PHY, PHC, bench, HIL, field, deployment, or
production validation.
