# P07 lesson: Model PTP Hardware Timestamping

## Guiding question

What inputs, observable effects, and failure modes matter when you model PTP Hardware Timestamping?

## Compounds on P06

P06 separated a four-timestamp exchange into offset and round-trip terms. Under a symmetric path,
its ideal timestamps recovered the true clock offset; under asymmetry, half the directional delay
difference appeared as offset bias. P07 does not replace that result. It adds timestamp placement
error to every P06 observation.

## Mental model

Use `theta = follower clock - leader clock`. At the modeled wire reference plane, leader Sync
transmit is `T1`, follower receive is `T2`, follower Delay_Req transmit is `T3`, and leader receive
is `T4`. The follower's turnaround gap `T3-T2` cancels from the round-trip estimate; it is not a
network delay measurement.

Let `e_i = captured timestamp i - ideal reference-plane timestamp i`. Substituting
`T_i + e_i` into the visible P06 equations gives

`theta_hat = theta + (d_f-d_r)/2 + (e2-e1+e3-e4)/2`,

`delay_hat = d_f+d_r + e4-e1-e3+e2`.

That substitution is the governing operation. A software transmit stamp taken before the modeled
host path has a negative placement error; a software receive stamp taken after the path has a
positive placement error. Near-wire hardware capture excludes those host terms, but its own fixed
pipeline placement, configured correction, and tick quantization still determine `e_i`.

The teaching hardware fixture uses raw placement offsets `[-20 +80 -20 +20] ns` for `T1` through
`T4`. Complete calibration applies the opposite corrections: TX corrections are added and RX
corrections are subtracted. Raw values are rounded to the nearest configured tick first. Each
rounding residual is therefore bounded by half a tick in this model, with exact ties rounded away
from zero. The combined offset quantization contribution is bounded by one tick and the combined
round-trip contribution by two.

## One prediction before the baseline

If variable host-path latency doubles while the wire path, hardware tick, and calibration remain
fixed, which estimate should spread more across repeated exchanges: software capture or near-wire
hardware capture?

## Baseline observation

At true offset `120 ns`, symmetric `800/800 ns` wire delay, and host scale `1`, software offset
estimates range from `70` to `420 ns`. The larger placement errors are different at `T1` through
`T4`, so they do not cancel. Corrected hardware estimates at an `8 ns` tick are only `118` or
`122 ns`. Their mean is exactly `120 ns`, but individual values retain quantization error.

The same capture errors enter round trip with a different sign pattern. True round trip is
`1600 ns`; software estimates span `4500–5200 ns`, whereas modeled hardware estimates are `1596`
or `1604 ns`. Do not call the hardware values exact: moving capture near the wire removes this
lesson's host-path terms, not every error source.

## Lever 1: host timestamp-path latency

Hold the hardware tick at `8 ns`, calibration at `1`, and both wire directions at `800 ns`. Move
host-path scale through `[0 1 2]`. Software offset peak-to-peak changes through `[0 350 700] ns`,
and maximum absolute offset error through `[0 300 600] ns`. Hardware offset peak-to-peak remains
`4 ns` because this lever acts outside the modeled near-wire capture plane.

At scale zero, the software placement errors vanish and software arithmetic collapses to the ideal
P06 result. This is a limiting case, not a claim that a real software stack has zero latency.

## Lever 2: hardware timestamp tick

Reset host scale to `1` and calibration to `1`. Move tick size through `[1 8 64] ns`. Hardware
offset peak-to-peak becomes `[0 4 32] ns`; maximum absolute offset error becomes `[0 2 22] ns`.
Hardware round-trip peak-to-peak becomes `[0 8 64] ns`. The software trace remains exactly the
same because its capture model does not use the hardware tick.

The bounds are more general than the exact fixture values. With four round-to-nearest timestamp
errors, each at most `q/2`, the absolute offset quantization contribution is at most `q`, and the
round-trip contribution is at most `2q`.

## Deliberately broken reference-plane calibration

Set tick to `1 ns`, then omit all configured hardware pipeline corrections. Quantization error is
zero, so every repeated result is identical. Nevertheless the raw placement offsets remain. The
offset estimate is a precise-looking `150 ns`, `30 ns` above truth, and round trip is `1740 ns`,
`140 ns` high.

The violated assumption is that all four timestamps refer to the same calibrated wire plane. Zero
spread only says the deterministic error repeated. It does not establish accuracy. Applying twice
the needed correction flips the offset and round-trip bias signs, another check that calibration—not
randomness—causes the symptom.

## Inherited path-asymmetry limit

With a `1 ns` tick and complete calibration, use `1200 ns` forward and `400 ns` reverse delay.
Hardware placement and quantization errors vanish, but estimated offset becomes `520 ns` for a true
`120 ns` offset. Half the `800 ns` path difference remains. Hardware timestamping improves where
the event is observed; it does not reveal an unobserved directional path split.

## Common mistakes

- Hardware timestamping means closer to a modeled reference plane here, not automatically exact.
- Small spread is precision. Accuracy additionally requires correct placement calibration, path
  assumptions, clock-domain handling, and a valid timestamp-to-message association.
- Nanosecond units do not prove nanosecond accuracy.
- `T3-T2` is a follower turnaround gap that cancels; it is not one-way wire delay.
- Calibration corrections move timestamps to a reference plane; they do not correct asymmetric
  network delay.
- A fine tick removes this fixture's rounding only; it does not prove physical clock quality.
- A hardware timestamp can belong to a PHC rather than the system clock. This model assumes one
  comparable leader/follower clock domain and performs no conversion or discipline.
- Real TX timestamp retrieval and correlation can wait, time out, be cancelled, or mismatch a
  packet. This finite function models none of those lifecycles and fabricates no such test.
- No correction field, transparent clock, one-step/two-step exchange, servo, or full PTP protocol
  is implemented.
- Every timestamp, pipeline value, and host pattern is synthetic and deterministic; no hardware
  or network measurement occurred.

## Completion standard

Run `run_checks`, answer the interpretation questions in `checks.md`, identify the calibration
assumption from the precise-looking broken result, and give a two-sentence teach-back: error
mechanism first, capture-plane benefit and remaining limits second.
