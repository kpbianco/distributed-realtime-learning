# P06 lesson: Model NTP-Style Exchange

## Guiding question

What inputs, observable effects, and failure modes matter when you model NTP-Style Exchange?

## Compounds on P05

P05's one-way observation was `clock offset + one-way delay`. A constant path component and a
constant offset could produce the same data. P06 sends a request in one direction and a reply in
the other, adding two server timestamps so processing time and round-trip network delay can be
separated.

## Mental model

Use `theta = server clock - client clock`. The client writes `T1` before sending and `T4` after
receiving. The server writes `T2` on receive and `T3` on transmit. If forward delay is `d_f`,
reverse delay is `d_r`, and server residence is `p`, then

`T2-T1 = theta + d_f`, and `T3-T4 = theta - d_r`.

Averaging those two signed terms gives

`theta_hat = theta + (d_f-d_r)/2`.

The same timestamps give

`delta_hat = (T4-T1) - (T3-T2) = d_f+d_r`.

The second subtraction removes server residence from network round trip. The first equation
reveals the remaining assumption: equal forward and reverse delay are needed for an unbiased
offset estimate. When round trip is positive, the four readings do not generally reveal the
directional split. In ideal arithmetic, exact zero true round trip is the truth-only exception:
nonnegative directional delays must both be zero. Finite timestamp precision can still obscure
that boundary in represented intervals.

## One prediction before the baseline

If the server spends longer processing the request but both network directions stay at `4 ms`,
which should change: raw client elapsed time, estimated network round trip, estimated clock offset,
or more than one of them?

## Baseline observation

At `(T0, theta, d_f, d_r, p) = (100, 7, 4, 4, 2) ms`, true event times are
`[100 104 106 110] ms`, while the two local clocks report `[100 111 113 110] ms` for
`[T1 T2 T3 T4]`. Do not plot those cross-clock readings as one physical timeline. The truth view
uses simulated event time; the timestamp view labels local readings.

The client sees `T4-T1 = 10 ms`; the server reports `T3-T2 = 2 ms`. Subtraction leaves the true
`8 ms` network round trip. The two offset terms are `11 ms` and `3 ms`; their average is the true
`7 ms` offset because the path is symmetric.

## Lever 1: true clock offset

Hold forward/reverse delay at `4/4 ms` and server residence at `2 ms`. Sweep true offset through
`[-8 0 12] ms`. The server's `T2` and `T3` readings translate, so estimated offset follows the
lever. Client elapsed, server residence, and estimated network round trip do not change.

## Lever 2: symmetric path delay

Reset offset to `7 ms`. Move both one-way path delays together through `[1 4 10] ms`. The estimated
network round trip becomes `[2 8 20] ms`, and raw client elapsed becomes `[4 10 22] ms` because it
also includes the fixed `2 ms` residence. The offset estimate remains `7 ms`: equal delay enters
the two signed offset terms with opposite signs.

## Deliberately broken path-symmetry assumption

Keep total network round trip at `8 ms`, but put `7 ms` forward and `1 ms` reverse. With true
offset `7 ms`, the observed vector becomes `[100 114 116 110] ms` and the estimator reports
`10 ms`. Half the `6 ms` directional difference became `+3 ms` of offset bias.

A different permitted truth—offset `10 ms` and symmetric `4/4 ms` delay—produces exactly the same
four timestamps. Both cases have zero equation residual and the same `8 ms` round trip. The
symmetry flag in the model comes from simulation truth; an endpoint cannot infer it from those four
readings. More precise arithmetic does not repair an unobserved path assumption.

## Common mistakes

- `T2-T1` is not a direct forward delay because it crosses two clocks.
- `T4-T3` is not a direct reverse delay for the same reason and uses the opposite offset sign.
- Server residence belongs in raw response time but is removed from the network round-trip formula.
- With positive round-trip delay, four timestamps do not generally prove equal directional delays.
- Zero formula residual does not prove an unbiased offset estimate.
- `delta_hat/2` is a symmetric one-way estimate, not either true direction under asymmetry.
- An offset estimate is not a clock-adjustment command; this module never steers a clock.
- One ideal exchange is not the complete NTP protocol: polling, filtering, selection, loss,
  authentication, clock discipline, timestamp representation, and network I/O are absent.
- No timer, wall-clock wait, timeout, cancellation, packet retry, or packet loss is modeled.
- A tiny negative raw round trip caused only by extreme floating-point cancellation is retained as
  a diagnostic while the nonnegative physical teaching estimate normalizes to zero.
- P07 adds hardware timestamp placement; P06 does not claim hardware behavior.

## Completion standard

Run `run_checks`, answer the interpretation questions in `checks.md`, identify the asymmetry alias,
and give a two-sentence teach-back: four-timestamp mechanism first, symmetry consequence and
evidence boundary second.
