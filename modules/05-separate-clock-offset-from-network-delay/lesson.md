# P05 lesson: Separate Clock Offset from Network Delay

## Guiding question

What inputs, observable effects, and failure modes matter when you separate Clock Offset from Network Delay?

## Compounds on P04

P04 separated fixed service from queue waiting. P05 treats propagation, hidden constant path time,
and that variable queue waiting as parts of one-way network delay. The new difficulty is that the
delay is observed through two clocks rather than one reference clock.

## Mental model

Clock A timestamps send time. Clock B, which is `theta` milliseconds ahead of A, timestamps the
arrival after network delay `d_i`:

`z_i = B(arrival_i) - A(send_i) = theta + d_i`.

The receiver sees `z_i`, not the two terms. Adding `5 ms` to every network delay has the same
effect as adding `5 ms` to the clock offset. Repetition can reveal a changing component through the
spread of `z`, but a constant component remains ambiguous.

An external fact can resolve the ambiguity. If `d_min` is the exact attainable total fixed-delay
floor—not merely a lower bound—and at least one observed sample reaches it, then
`theta_hat = min(z)-d_min`. Subtract that offset estimate from every observation to estimate
network delay. This is a conditional inference, not a property of timestamps alone.

## One prediction before the baseline

A receiver-minus-sender timestamp difference is `10 ms`. Without a trusted minimum-delay anchor,
can you tell how many milliseconds came from clock offset and how many came from the network?

## Baseline observation

Inspect the observed-difference view first. The eight values are
`[10 12 16 14 18 12 14 10] ms`; each is a sum. The external `3 ms` path floor lets the minimum
observation identify a `7 ms` clock offset. Only then does subtraction recover network delays
`[3 5 9 7 11 5 7 3] ms`.

The reconstruction residual is zero, but zero residual alone does not prove the decomposition.
The trusted anchor supplies the missing information.

## Lever 1: clock offset

Hold propagation at `3 ms`, queue-delay peak at `8 ms`, and hidden common delay at zero. Sweep
offset through `[-8 0 12] ms`. Every observed difference moves by the same amount; the observed
spread remains `8 ms`, and the estimated network-delay trace is unchanged. A negative observed
difference can occur when clock B is behind clock A even though physical network delay is positive.

## Lever 2: variable queue delay

Reset offset to `7 ms`, then sweep only queue-delay peak through `[0 4 12] ms`. The observed spread
moves through `[0 4 12] ms`, while the minimum remains `10 ms` and the anchored offset estimate
remains `7 ms`. Variation is evidence about changing delay, not about a changing constant offset in
this no-skew model.

## Deliberately broken minimum-delay assumption

Add `5 ms` of hidden common network delay while continuing to assume the minimum is the `3 ms`
propagation floor. The estimator reports `12 ms` of offset instead of the true `7 ms` and
underestimates every network delay by `5 ms`. Its reconstruction residual is still zero.

Worse, this case has exactly the same one-way observations as another permitted decomposition with
`12 ms` clock offset and no hidden delay. The symptom is observational aliasing: no one-way plot or
perfect fit can choose between them. More samples do not repair a false anchor.

## Common mistakes

- A receiver-minus-sender timestamp difference is not automatically a network delay.
- Zero reconstruction residual proves only that the two estimated terms sum correctly.
- Jitter or spread exposes variation; it does not identify the constant delay floor.
- `min(z)` is not clock offset unless the minimum network delay is known to be zero.
- A minimum sample is an anchor only when it reaches a justified physical path floor.
- Negative one-way timestamp differences do not imply negative physical delay.
- This constant-offset model excludes clock skew; a drifting offset would change the pattern.
- P05 assumes paired samples and an external anchor. P06 will introduce a two-way exchange rather
  than pretending that one-way data solved the ambiguity.
- The deterministic calculation performs no network I/O, wall-clock wait, timeout, cancellation,
  or clock adjustment.

## Completion standard

Run `run_checks`, answer the interpretation questions in `checks.md`, identify the broken anchor
from its aliased decomposition, and give a two-sentence teach-back: sum mechanism first, evidence
limit and anchor consequence second.
