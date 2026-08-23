# P05 checks: Separate Clock Offset from Network Delay

## Independent numerical invariants

- For offset `7 ms`, propagation floor `3 ms`, and variable queue delay
  `[0 2 6 4 8 2 4 0] ms`, derive true network delay `[3 5 9 7 11 5 7 3] ms` and observed
  receiver-minus-sender differences `[10 12 16 14 18 12 14 10] ms`.
- Use `theta_hat = min(z)-3 ms` to recover `7 ms`, then verify estimated delay equals true delay
  and `theta_hat + d_hat_i = z_i` for every sample.
- Verify sender and receiver timestamps independently from true send time, true arrival time,
  network delay, and clock offset.
- Confirm the observed spread equals the true delay spread. A common clock offset changes neither.
- Repeated calls and accepted integer-class inputs must reproduce every baseline vector.

## Sweep and limiting cases

- Sweep clock offset through `[-8 0 12] ms` with the delay trace fixed. Derive observed minima
  `[-5 3 15] ms`, offset estimates `[-8 0 12] ms`, fixed spread `8 ms`, and identical estimated
  network-delay traces.
- Sweep queue-delay peak through `[0 4 12] ms` with offset fixed at `7 ms`. Derive offset estimates
  `[7 7 7] ms`, observed spreads `[0 4 12] ms`, and maximum true delays `[3 7 15] ms`.
- At zero clock offset, confirm observations equal true network delay. At negative offset, confirm
  an observed timestamp difference may be negative while physical network delay remains nonnegative.
- At zero queue peak and a valid floor, confirm every delay is `3 ms` and the constant offset is
  still recoverable from the external anchor.
- At one sample, confirm the anchor can separate the terms only because the deterministic sample
  reaches the queue-free floor; one sample alone supplies no such guarantee.
- At 64 samples and maximum accepted magnitudes, confirm finite outputs, exactly 64 profile
  accesses, and reconstruction within the declared numerical tolerance.

## Deliberately broken case, timeout, and recovery

- Compare `model(8,7,3,8,5,3)` with `model(8,12,3,8,0,3)`. Their observed timestamp differences
  must match exactly. The first case estimates `12 ms` instead of the true `7 ms` offset and
  underestimates every true network delay by `5 ms`.
- Name the violated assumption: the minimum sample contains `5 ms` of hidden common delay and does
  not reach the assumed `3 ms` floor. More one-way samples with the same hidden floor do not restore
  identifiability.
- Reject non-scalar, complex, nonfinite, fractional discrete, negative-delay, and over-bound inputs
  with stable `P05:*` identifiers. A valid baseline call after each failure must reproduce the same
  outputs.
- The model is a finite synchronous calculation. `actualWaitPerformed`, `timeoutModeled`, and
  `cancellationModeled` remain false; no fabricated timeout or cancellation behavior is claimed.
- Confirm there is no global, persistent, file, timer, random, network, UI, or two-way-exchange
  state in the model.

## Interpretation questions

Answer one at a time:

1. Why is a one-way timestamp difference a sum rather than a direct delay measurement?
2. Which visible change indicates a common clock-offset shift, and which indicates variable delay?
3. What external fact makes the lower-envelope estimate valid?
4. Why can zero reconstruction residual coexist with a `5 ms` offset error?
5. How does P04 queue waiting appear in P05's observed timestamp differences?
6. Why does a negative timestamp difference not imply negative propagation time?
7. What does this module intentionally leave for P06's two-way exchange?
8. What evidence would be required before treating the analytical result as MATLAB-runtime,
   protocol, clock-device, bench, HIL, or field behavior?

## Executable check and teach-back

Run:

```matlab
run_checks
```

All assertions must pass before completion is considered. Then teach back in two sentences:
mechanism first (`z_i = theta + d_i`), evidence limit second (the anchor permits separation, and a
hidden constant delay aliases with offset).
