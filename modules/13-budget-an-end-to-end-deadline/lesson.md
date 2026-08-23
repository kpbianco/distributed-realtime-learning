# P13 lesson: Budget an End-to-End Deadline

## Guiding question

What inputs, observable effects, and failure modes matter when you budget an End-to-End Deadline?

## Compounds on P12

P12 separated the time at which enough coordination evidence is visible from the safety meaning of
that evidence. Its baseline evaluator reached the third vote at `26 ms`. P13 takes `26 ms` as one
declared stage contribution. It does not reproduce consensus; it asks whether that coordination
wait, queue wait from P04/P11, network work, and endpoint task responses all have explicit owners
inside one end-to-end deadline.

That distinction matters. A subsystem can meet its own local threshold while the whole transaction
misses. Conversely, one stage can exceed a local allocation while spare margin elsewhere keeps the
complete transaction inside its deadline. End-to-end reasoning needs both views.

## Mental model

Follow one sequential transaction from source release through destination completion. The fixture
has five ordered declared contributions:

`c = [source response, queue wait, network, coordination wait, destination response]`.

The complete analytical response contribution is

`R_e2e = sum(c_i)`.

If the requirement is `D`, end-to-end slack is

`S_e2e = D - R_e2e`.

Positive slack means this declared bound is inside the deadline. Zero is an accepted exact tie.
Negative slack means these declared inputs cannot support the guarantee. It does not mean a timer
ran or that every physical transaction must miss.

A reviewable plan also assigns `b_i` to every causal stage. Stage margin is

`M_i = b_i - c_i`,

and unassigned deadline reserve is

`R = D - sum(b_i)`.

When every stage is owned exactly once,

`S_e2e = R + sum(M_i)`.

That identity is an accounting check, not a scheduling theorem. The `c_i` values must already be
credible bounds for their own mechanisms before the sum can support a real guarantee. P13 supplies
synthetic declared values so the accounting can be seen without claiming certified WCET, network
calculus, response-time analysis, clock bounds, or measurements.

## One prediction before the baseline

If the queue contribution rises above its `16 ms` allocation but the complete path remains below
the `90 ms` deadline, should you report an end-to-end miss, a local allocation breach, or both?

## Baseline observation

Use queue wait `12 ms`, coordination wait `26 ms`, deadline `90 ms`, and complete ownership.
Contributions are `[8 12 10 26 9] ms`, so the complete path is `65 ms`. Reference allocations are
`[10 16 14 32 12] ms`, so their total is `84 ms`.

First compare one stage at a time. Margins are `[2 4 4 6 3] ms`: every contribution fits its owner.
Then change to the cumulative view. The complete path ends at `65 ms`, the allocation plan at
`84 ms`, and the requirement at `90 ms`.

The visible identity is

`90 - 65 = (90 - 84) + [(10-8)+(16-12)+(14-10)+(32-26)+(12-9)]`

`25 = 6 + 19`.

The `6 ms` is not yet assigned to a stage. The `19 ms` is distributed among stage margins. Neither
number creates capacity or makes a slow mechanism faster; they record where the declared plan has
room.

## Lever 1: queue/admission wait

Hold coordination at `26 ms`, deadline at `90 ms`, all fixed stages, and complete ownership. Move
only queue wait through `[0 6 12 24] ms`.

- Complete-path contribution becomes `[53 59 65 77] ms`.
- End-to-end slack becomes `[37 31 25 13] ms`.
- Queue-stage margin becomes `[16 10 4 -8] ms`.
- Every complete path remains inside `90 ms`, but the `24 ms` queue case exceeds its `16 ms`
  allocation.

Queue wait adds one-for-one because the stages are sequential in this fixture. At `24 ms`, report
the two facts separately: no end-to-end miss under the declared `90 ms` requirement, and a local
allocation breach that makes the current allocation plan non-credible. Silently borrowing `8 ms`
from other stages hides ownership; an engineer may rebudget, reduce queueing, or change the
requirement, but that is an explicit decision outside this arithmetic evaluator.

P04 showed how FIFO waiting grows, and P11 showed how backpressure can move waiting upstream. P13
does not double-count both mechanisms. `queueWaitMs` is one already-declared contribution at the
chosen transaction boundary.

## Lever 2: end-to-end deadline

Reset queue wait to `12 ms`. Hold all five contributions and allocations fixed, then move only `D`
through `[60 65 84 90] ms`.

- Complete-path contribution stays `[65 65 65 65] ms`.
- End-to-end slack becomes `[-5 0 19 25] ms`.
- Allocation reserve becomes `[-24 -19 0 6] ms`.
- The complete path meets at `[false true true true]`.
- The allocation sum fits at `[false false true true]`.

Changing a requirement does not change execution. At `65 ms`, the declared complete path meets on
an exact tie, but the `84 ms` allocation plan cannot fit inside that requirement. At `84 ms`, both
the complete path and all assigned allocations fit, with zero reserve. At `90 ms`, the plan has
`6 ms` available for explicit assignment.

This separates three questions that are often collapsed:

- Is every causal stage represented?
- Does each declared contribution fit its stage allocation?
- Do the complete contribution and the complete allocation plan fit `D`?

## Deliberately broken ownership assumption

Set `D=60 ms` and turn off **Include coordination stage**. The full transaction still contains the
P12-derived `26 ms` coordination wait, but the accounting mask omits it.

The incomplete account adds only `[8 12 10 9]` and reports `39 ms`, leaving apparent slack
`60-39=+21 ms`. Its owned allocations total `52 ms`, and every owned stage fits. A dashboard that
looks only at those values would report success.

The complete path is still `65 ms`, so true modeled slack is `60-65=-5 ms`. The recognizable
symptom is simultaneous positive apparent slack and a complete-path miss, with exactly `26 ms`
unowned. The violated assumption is “a deadline budget is credible even when one causal stage is
missing.”

Do not repair the symptom by calling `39 ms` “end-to-end.” Restore complete ownership, reveal the
miss, and then make a design decision. Also do not interpret the checkbox as a way to skip
coordination execution: it changes accounting coverage only.

## Exact limits and local allocation boundaries

The complete baseline contribution is `65 ms`. A deadline of exactly `65 ms` passes; a deadline
just below it fails. The evaluator performs a direct `<=` comparison and does not add an epsilon
that weakens the requirement.

Queue wait of exactly `16 ms` uses the whole queue allocation and passes that local boundary.
Queue wait just above `16 ms` breaches the allocation while the complete path still fits `90 ms`.
This is the answer to the prediction: report a local allocation breach, not an end-to-end miss.

At zero queue and coordination wait, fixed source, network, and destination contributions still
sum to `27 ms`. At maximum allowed inputs, the complete contribution is
`8+1000+10+1000+9=2027 ms`. Both limits are fixed finite arithmetic, not performance tests.

## Timeout, cancellation, rollback, and recovery boundary

The word “deadline” does not imply a timer in this module. `D` classifies a declared response bound.
No task blocks, no wall-clock time elapses, and no timeout callback runs. A miss is therefore a
guarantee failure under the fixture, not a timed-out request or proof of a node failure.

There is no pending work to cancel. The model does not send an asynchronous cancellation, stop a
stage, or suppress later work. Deadline classification also does not roll back source work, queued
work, coordination evidence, or destination state. Those processes and state transitions do not
exist in this evaluator; their declared contributions remain visible.

Restoring the baseline after a miss, incomplete budget, allocation breach, or malformed call
reproduces the `65 ms` target in a fresh call. That demonstrates stateless recovery of the
calculation, not retry, replay, checkpoint restore, failover, or live system recovery.

## Common mistakes

- Summing only the stages owned by one team is not an end-to-end budget.
- Positive apparent slack is meaningless when coverage is incomplete.
- A local allocation breach is not automatically an end-to-end miss.
- End-to-end slack does not excuse an unreviewed local overrun; rebudget explicitly.
- A requirement change does not make computation, queueing, coordination, or networking faster.
- Exact equality meets this fixture's deadline; no hidden epsilon widens the requirement.
- The P12 `26 ms` value is a declared input here, not rerun consensus or a universal constant.
- The queue wait is one contribution, not a second simulation of P04 or P11.
- A deadline comparison is not a blocking timeout or cancellation mechanism.
- Re-evaluation is not rollback, retry, or live recovery.
- Synthetic stage values are not measured or certified bounds.
- Static/reference checks are not MATLAB execution, UI validation, numerical-fidelity evidence, or
  physical timing validation.

## Completion standard

Run `run_checks`, answer one prompt from `checks.md` at a time, and give a two-sentence teach-back.
First relate complete stage ownership, `R_e2e=sum(c_i)`, stage allocation margin, and deadline
reserve. Then explain how queue wait, requirement changes, or an omitted coordination stage changes
what can be guaranteed without claiming a running timeout, rollback, recovery, MATLAB runtime, or
measured timing.
