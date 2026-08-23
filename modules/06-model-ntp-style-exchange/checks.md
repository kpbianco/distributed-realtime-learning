# P06 checks: Model NTP-Style Exchange

## Independent numerical invariants

- From `(T0, theta, d_f, d_r, p) = (100, 7, 4, 4, 2) ms`, derive true event times
  `[100 104 106 110] ms` and local timestamp observations `[100 111 113 110] ms`.
- Derive `T2-T1 = 11 ms`, `T3-T4 = 3 ms`, and their average `theta_hat = 7 ms`.
- Derive client elapsed `T4-T1 = 10 ms` and server residence `T3-T2 = 2 ms`; subtract them to
  recover network round trip `8 ms` and symmetric one-way estimate `4 ms`.
- Independently verify `theta_hat = theta + (d_f-d_r)/2` and
  `delta_hat = d_f+d_r`.
- Repeated calls, an arbitrary common time-origin shift, and accepted integer numeric classes must
  preserve every derived interval and error.

## Sweep and limiting cases

- Sweep offset through `[-8 0 12] ms` at symmetric `4/4 ms` path delay. Derive matching offset
  estimates, fixed `8 ms` network round trip, and fixed `10 ms` client elapsed time.
- Sweep symmetric one-way delay through `[1 4 10] ms` at offset `7 ms`. Derive fixed offset
  estimates `[7 7 7] ms`, round trips `[2 8 20] ms`, and client elapsed values `[4 10 22] ms`.
- With both path delays zero and nonzero server residence, confirm network round trip is zero and
  processing cancels from both estimates.
- Change server residence while holding path and offset fixed. Raw client elapsed and `T3/T4`
  change, but offset and network round-trip estimates do not.
- At zero true offset with path asymmetry, confirm the estimate can still be nonzero.
- Swap forward and reverse delays. Confirm offset-error sign flips while network round trip remains
  fixed.
- At maximum accepted magnitudes, confirm exactly four finite timestamp values and residuals within
  the declared numerical tolerance.
- At the retained extreme-origin cancellation fixture, confirm the raw timestamp subtraction is a
  tiny negative value within tolerance, the physical teaching estimate normalizes to zero, and the
  raw value plus normalization flag remain visible.
- Confirm a tiny nonzero directional asymmetry remains truth-classified as asymmetric at both zero
  and maximum time origins; absolute timestamp magnitude affects arithmetic tolerance, never the
  exact truth classification.

## Deliberately broken case, malformed input, and recovery

- Compare `model(100,7,7,1,2)` with `model(100,10,4,4,2)`. Their four timestamp observations must
  both equal `[100 114 116 110] ms`, despite different true offset and directional delays.
- In the asymmetric case, derive `theta_hat = 10 ms`, `+3 ms` offset error, and inferred symmetric
  delays `4/4 ms` instead of true `7/1 ms`. Zero identity residual does not reveal this bias.
- Name the violated assumption: forward and reverse path delays are not equal. Symmetry is a
  truth-only teaching diagnostic, not an observable from one exchange.
- Reject empty, text, non-scalar, complex, nonfinite, negative-delay, and over-bound inputs with
  stable `P06:*` identifiers. A valid baseline after the complete failure sequence must reproduce
  the exact trace.
- The model is fixed work and stateless: four timestamps, no global, persistent, random, file,
  timer, UI, socket, network, or hardware state.
- `actualWaitPerformed`, `timeoutModeled`, and `cancellationModeled` remain false. Timeout and
  cancellation tests are not fabricated for a finite synchronous calculation.

## Interpretation questions

Answer one at a time:

1. How do P06's request and reply add information beyond P05's one-way timestamp difference?
2. Why is server residence subtracted from client elapsed time?
3. Why does symmetric path delay change round trip without changing estimated offset?
4. How does signed path asymmetry enter the offset estimate?
5. Why can two different physical paths and offsets produce the same four timestamps?
6. Why can zero residual coexist with a biased offset estimate?
7. What does `delta_hat/2` mean when the two directions differ?
8. Why does the ideal truth-only zero-round-trip, nonnegative-delay limit imply a symmetric
   `0/0 ms` path even though one represented exchange does not generally reveal its directional
   split and finite precision can obscure the boundary?
9. Which parts of a real NTP implementation and P07 hardware timestamping are outside this model?
10. What evidence would be required before treating these static/reference results as MATLAB-runtime,
   NTP protocol, clock-device, bench, HIL, or field behavior?

## Executable check and teach-back

Run:

```matlab
run_checks
```

All assertions must pass before completion is considered. Then teach back in two sentences:
mechanism first (`theta_hat` averages two signed cross-clock terms while `delta_hat` removes server
residence), consequence second (symmetry makes offset unbiased, while asymmetry aliases with offset
and cannot be diagnosed from these four observations alone).
