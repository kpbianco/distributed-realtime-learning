# P08 lesson: Distribute a Time-Triggered Schedule

## Guiding question

What inputs, observable effects, and failure modes matter when you distribute a Time-Triggered Schedule?

## Compounds on P07

P07 moved timestamp capture toward a common reference plane but retained bounded calibration,
quantization, and path-asymmetry error. P08 asks what a scheduler can safely do with that bound.
Clock agreement makes a shared activation timestamp meaningful; it does not distribute the slot
map, validate it, or guarantee that all nodes use the same version.

## Mental model

Use `C_i(t)=t+e_i`, where `e_i` is node-local time minus coordinator time. A positive `e_i`
means the node is ahead. When that node waits until its clock reads `A+s_i`, true time is

`t_i=A+s_i-e_i`.

The sign matters: an ahead clock fires early, not late. Every action requires the same exclusive,
non-preemptive shared communication channel. An action with duration `D` owns that channel over the
half-open interval `[t_i,t_i+D)`. Two occupancy intervals may touch with zero gap, but overlap means
two nodes request the exclusive channel concurrently. After sorting all four true starts, include
the last-to-first cycle-wrap gap; otherwise a collision near the cycle boundary can be missed.

The coherent slot spacing is `250 us`, action duration is `160 us`, and nominal guard is `90 us`.
With `|e_i|<=E`, relative clock error can consume at most `2E`, giving the conservative bound

`minimum coherent separation >= 90 us - 2E`.

Schedule distribution has a separate inequality. Delivery plus validation produces a true ready
time; adding `e_i` converts it to the node's local ready time. Node `i` is staged for a common
activation only if

`ready_local_i <= A`.

The version-coherent fixture uses an all-or-nothing policy oracle: select the new map for every
node only if every node is ready; otherwise withhold it and retain the old map everywhere. It
models a selection decision, not the acknowledgment, commit, abort, rollback, or consensus
protocol that a real system would need. This policy preserves one version; it cannot compensate
for a clock-error bound that consumes the complete guard.

## One prediction before the baseline

If the absolute residual clock-error bound doubles while slot spacing, action duration, and the
active schedule version stay fixed, what happens to the worst-case guard guarantee?

## Baseline observation

At `E=20 us`, the synthetic offsets are `[-20 10 20 -10] us`. Version 2 phases
`[0 250 500 750] us` therefore start at true times `[20 240 480 760] us` relative to activation.
The four cyclic gaps are `[60 80 120 100] us`. The smallest actual gap, `60 us`, remains above
the general `50 us` lower bound.

Delivery and validation make the schedule ready at local times `[240 510 900 1210] us`. With
`A=1500 us`, all four slacks are nonnegative: `[1260 990 600 290] us`. Every node uses version 2.
Clock-margin sufficiency and configuration readiness are visible in different views because they
are different mechanisms.

## Lever 1: residual clock-error bound

Hold activation lead at `1500 us`, distribution scale at `1`, and the coherent version fixed.
Move `E` through `[0 20 40] us`. Actual fixture minimum gaps become `[90 60 30] us`; proven lower
bounds become `[90 50 10] us`. Maximum action-start displacement is exactly `[0 20 40] us`.

The fixture's exact gaps depend on the chosen error signs, but `90-2E` does not. At `E=45 us`,
the general guarantee reaches zero even though this exact fixture still has margin. An actual zero
gap is a touching boundary, not negative overlap. A larger bound means this schedule no longer
proves separation even if one chosen offset pattern happens to fit.

## Lever 2: activation lead

Reset `E=20 us`. Move only `A` through `[600 1000 1500] us`. Ready-node counts become `[2 3 4]`,
and minimum readiness slack becomes `[-610 -210 290] us`. At the first two leads, the policy
retains version 1 on all nodes. At the last lead, it activates version 2 on all nodes.

Waiting longer before activation creates staging margin; it does not improve clock agreement. The
minimum action gap remains `60 us` for both coherent maps in this fixture. At exactly `1210 us`,
the last node is ready at the boundary and may participate; at `1209 us`, it is late.

## Deliberately broken version activation

Keep `A=1000 us`, where Nodes A–C are ready and Node D is late, then disable all-or-nothing
activation. The active versions become `[2 2 2 1]`. New version 2 assigns Node C phase `500 us`,
while old version 1 assigns Node D the same phase. Their true starts differ by only `30 us`, but
each action lasts `160 us`, so the cyclic separation is `-130 us`: a `130 us` overlap.

The violated assumption is schedule-version coherence, not the clock-error bound. Both complete
maps are collision-free under the same clocks. Restore the policy at `A=1000 us` to retain the old
map without overlap, then raise `A` to `1500 us` to activate the new map coherently. That is
recovery in this analytical fixture: the new selection was withheld, not applied and rolled back.

At `A=600 us` with the policy disabled, versions `[2 2 1 1]` are mixed but happen not to overlap
because the changed Node C/D assignments are both still old. Absence of a visible collision in one
fixture does not establish version coherence.

## Common mistakes

- Synchronizing clocks does not distribute or atomically activate a schedule.
- A schedule version number is not enough; every participating node must select the same coherent
  slot map at the intended epoch.
- Version coherence is not enough by itself; the residual clock-error bound must leave adequate
  guard on the exclusive shared channel.
- Positive clock offset means the local clock is ahead, so its true action start is early.
- Guard time absorbs relative error between nodes, which can be twice an individual absolute bound.
- Check the cycle-wrap transition after sorting true starts; array order is not necessarily time order.
- A zero half-open-interval gap means touching without overlap; a negative gap means concurrent
  occupancy of the modeled exclusive shared channel.
- Adjacent gaps detect whether occupancy is unsafe, but a three-way overlap contains a nonadjacent
  conflicting pair too; use the exhaustive pair inventory when reporting collision count.
- Readiness is a deterministic deadline classification here, not a blocking timeout or real wait.
- The policy oracle has perfect readiness truth. No acknowledgment loss, retry, cancellation,
  commit race, consensus, or partition is modeled.
- The schedule and delays are synthetic. This is not IEEE 1588, TSN, DetNet, TTEthernet, controller,
  network, operating-system scheduler, or hardware evidence.

## Completion standard

Run `run_checks`, answer one interpretation prompt from `checks.md` at a time, identify the
coherence assumption from the negative-gap symptom, and give a two-sentence teach-back: first the
clock/guard and readiness equations, then why one activation epoch and one schedule version are
both required.
