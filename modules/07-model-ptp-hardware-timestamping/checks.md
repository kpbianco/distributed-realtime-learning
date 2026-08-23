# P07 checks: Model PTP Hardware Timestamping

## Independent numerical invariants

- For each exchange, derive ideal wire-plane timestamps from `T1`, forward delay, follower offset,
  follower turnaround, and reverse delay. Confirm the `4000 ns` turnaround cancels from both
  four-timestamp estimates.
- Substitute `captured T_i = ideal T_i + e_i` and independently derive
  `theta_hat = theta + (d_f-d_r)/2 + (e2-e1+e3-e4)/2` and
  `delay_hat = d_f+d_r+e4-e1-e3+e2`.
- At the baseline, derive software offset estimates
  `[170 320 120 270 220 70 420 120] ns` and hardware estimates
  `[118 118 122 118 122 122 118 122] ns`.
- Derive true round trip `1600 ns`, software estimates
  `[4500 4800 4800 5100 5000 5100 5200 4800] ns`, and hardware estimates
  `[1596 1596 1604 1596 1604 1604 1596 1604] ns`.
- Confirm repeated calls and accepted integer inputs reproduce every timestamp, error, and metric.
- Shift the start time by a multiple of the hardware tick. Ideal intervals and all estimates must
  remain unchanged.

## Sweeps and limiting cases

- Sweep host timestamp-path scale through `[0 1 2]`. Derive software offset peak-to-peak
  `[0 350 700] ns` and maximum absolute errors `[0 300 600] ns`; hardware values stay
  `4 ns` peak-to-peak and `2 ns` maximum error.
- Sweep hardware tick through `[1 8 64] ns`. Derive hardware offset peak-to-peak `[0 4 32] ns`,
  maximum offset errors `[0 2 22] ns`, round-trip peak-to-peak `[0 8 64] ns`, and maximum
  round-trip errors `[0 4 52] ns`. Software estimates must remain bit-for-bit unchanged.
- At host scale zero, software placement errors vanish and software estimates equal ideal
  reference-plane estimates.
- With a `1 ns` tick and complete calibration, hardware placement and quantization errors vanish.
- Change follower turnaround while holding every capture error and path value fixed. `T3/T4`
  move, but offset and round-trip estimates do not.
- At all-zero offset, path, and turnaround inputs with the exact limiting settings, every capture
  error and estimate is zero; each exchange's four timestamps equal that exchange's start time.
- For every tick, verify per-stamp quantization error is at most `q/2`, offset quantization
  contribution at most `q`, and round-trip contribution at most `2q`.
- At an `8 ns` tick, verify exact signed half-tick raw values round away from zero: `-20 ns`
  becomes `-24 ns`, while `+20 ns` becomes `+24 ns`.
- With `1200/400 ns` forward/reverse delay, fine calibrated hardware still has `+400 ns` offset
  bias. Swapping path directions flips the sign without changing round trip.
- At maximum accepted inputs, confirm exactly eight exchanges, 32 finite timestamps, bounded
  derived magnitude, and identity residuals within the declared tolerance.

## Deliberately broken case, malformed input, and recovery

- Compare complete calibration with omitted calibration at a `1 ns` tick. Calibrated hardware must
  report `120 ns` offset and `1600 ns` round trip; omitted calibration must report `150 ns` and
  `1740 ns` across all eight exchanges.
- Name the violated assumption: all timestamps must be corrected to the same reference plane.
- Confirm the broken offset spread is zero while error is `+30 ns`; precision does not prove
  accuracy. Applying twice the correction flips offset error to `-30 ns` and round-trip error to
  `-140 ns`.
- Reject empty, text, non-scalar, complex, nonfinite, negative nonnegative-time inputs, zero or
  out-of-range tick, and every over-bound value with stable `P07:*` identifiers.
- A valid baseline after the complete failure sequence must reproduce the exact trace. The model
  retains no state and performs fixed work.
- The calculation uses no global, persistent, random, file, timer, UI, socket, network, PHC, NIC,
  or physical-hardware state.
- `actualWaitPerformed`, `timeoutModeled`, and `cancellationModeled` remain false. Timeout and
  cancellation behavior is not relevant to this finite synchronous arithmetic; no fake wait or
  lifecycle test is claimed.

## Interpretation questions

Answer one at a time:

1. What new `e_i` terms does P07 add to P06's four-timestamp equations?
2. Why does a software TX placement error have the opposite sign from an RX placement error?
3. Why does moving capture near the wire reduce sensitivity to the host latency lever?
4. Why can corrected hardware timestamps still vary at a coarse tick?
5. How do the `q/2`, `q`, and `2q` quantization bounds relate?
6. Why is a zero-spread `150 ns` broken result not accurate for `120 ns` truth?
7. What does ingress/egress calibration accomplish, and what does it not accomplish?
8. Why does forward/reverse path asymmetry survive perfect capture placement?
9. Why is the follower turnaround gap neither an offset error nor network round trip?
10. Which real PTP, timestamp-correlation, clock-domain, servo, timeout, and hardware behaviors are
    outside this analytical model?
11. What evidence would be required before treating the static/reference results as MATLAB-runtime,
    UI, PTP protocol, NIC/PHY/PHC, bench, HIL, or field behavior?

## Executable check and teach-back

Run:

```matlab
run_checks
```

All assertions must pass before completion is considered. Then teach back in two sentences:
mechanism first (capture errors enter offset and round trip with different signs), consequence
second (near-wire capture excludes modeled host latency, while tick, calibration, path symmetry,
and evidence boundaries remain).
