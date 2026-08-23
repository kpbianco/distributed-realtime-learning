# P08 — Distribute a Time-Triggered Schedule

**Track:** Distributed Real-Time Systems and Networks  
**Phase 2:** Time and synchronization  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you distribute a Time-Triggered Schedule?

## Compounds on P07

P07 showed how capture placement, calibration, quantization, and path asymmetry leave a clock
estimate with residual error. P08 treats that residual as a bound on four node clocks, then adds a
different problem: a schedule update must arrive, be validated, and become one coherent version at
a shared future activation epoch.

## Computational mental model

Let coordinator true time be `t` and node-local clock `i` be

`C_i(t) = t + e_i`,

where positive `e_i` means that node's clock is ahead. If every node receives the same activation
timestamp `A` and its assigned phase `s_i`, action `i` starts at local time `A+s_i` and therefore
at true time

`t_i = A + s_i - e_i`.

Every action requires the same exclusive, non-preemptive shared communication channel. Each
coherent schedule uses four `250 us` channel slots in a `1000 us` cycle. An action occupies the
channel over the half-open interval `[t_i, t_i+160 us)`, leaving a nominal `90 us` guard. If every
`|e_i| <= E`, two node errors can differ by at most `2E`, so every coherent cyclic separation is
bounded below by

`minimum separation >= 90 us - 2E`.

Sorted adjacent gaps are sufficient to detect unsafe occupancy and measure aggregate channel
overcommit. They are not a complete pair inventory when three actions overlap at once, so the
model separately checks all six unordered node pairs before reporting collision count, endpoints,
and pairwise overlap duration.

That bound needs both clock synchronization and one coherent slot map. Schedule version 1 assigns
phases `[0 250 750 500] us` to Nodes A–D; version 2 assigns `[0 250 500 750] us`. At the baseline
clock bound, either complete map has nonoverlapping channel occupancy. Mixing a new Node C
assignment with an old Node D assignment duplicates the `500 us` phase. Version coherence alone
does not prove timing safety: excessive clock error can still consume the complete guard.

Distribution is explicit and bounded. Publication occurs at true time zero. Fixed per-node
delivery delays `[180 420 760 1120] us`, multiplied by a delay scale, precede validation/staging
costs `[80 80 120 100] us`. A node is ready when its local ready timestamp is no later than `A`.
The version-coherent teaching policy selects version 2 only when all four nodes are ready;
otherwise it withholds the new selection and every node retains version 1. This all-ready decision
is an analytical oracle, not a commit, abort, or rollback protocol.

## Deterministic baseline

The baseline uses clock-error bound `E=20 us`, activation lead `A=1500 us`, distribution scale
`1`, and the all-or-nothing policy.

- Residual node offsets are `[-20 10 20 -10] us`; true starts relative to `A` are
  `[20 240 480 760] us`.
- Local schedule-ready times are `[240 510 900 1210] us`; readiness slack is
  `[1260 990 600 290] us`, so all nodes activate version 2.
- Cyclic separations are `[60 80 120 100] us`; the actual minimum is `60 us`, above the
  conservative `90-2(20)=50 us` lower bound.
- Four `160 us` actions use `64%` of the `1000 us` cycle. No interval overlaps.

These are deterministic analytical values, not times measured from MATLAB, an operating system,
a network, a synchronized clock, or a controller.

## Controlled experiments

1. Read the shared-clock equation and make the single prediction in `lesson.md`.
2. Compare local phases with true action windows, then inspect schedule-ready timestamps against
   the common activation epoch.
3. Sweep only `E` through `[0 20 40] us`. Actual minimum separation changes through
   `[90 60 30] us`; the general lower bound changes through `[90 50 10] us`.
4. Reset `E=20 us`, then sweep only activation lead through `[600 1000 1500] us`. Ready-node
   count changes through `[2 3 4]`; the coherence policy selects `[old old new]` coherently.
5. Deliberately disable all-or-nothing activation at `A=1000 us`. Nodes A–C select version 2
   while Node D retains version 1. Their selected phases become `[0 250 500 500] us`, and Node C
   overlaps Node D by exactly `130 us`.
6. Restore the coherence policy at the same lead to retain version 1 without collision, then
   increase lead to `1500 us` to select version 2 coherently. This protects version selection;
   the clock-error guard must still be checked separately.
7. Run independent checks, answer one interpretation question at a time, and teach back mechanism
   before symptom.

## Standards basis and inference boundary

IEEE 802.1Qbv describes scheduled frame transmission from time derived from IEEE 802.1AS, and
IETF DetNet material states that scheduled traffic depends on synchronized time and coordinated
schedule configuration. Those sources motivate the lesson's shared-time and coherent-configuration
requirements. The two schedule maps, delays, validation costs, residual offsets, policy oracle,
and all numerical results are local teaching fixtures. This module does not implement or claim
conformance with IEEE 1588, IEEE 802.1AS/Qbv, DetNet, TSN, TTEthernet, or any configuration or
commit protocol.

- <https://www.ieee802.org/1/pages/802.1bv.html>
- <https://datatracker.ietf.org/doc/rfc9320/>

## Transparent abstraction and resource boundary

The model always evaluates four nodes, four half-open action intervals, two schedule maps, one
cycle, and at most six unordered collision pairs. Clock-error bound is limited to `0–250 us`,
activation lead to `0–1e6 us`, and distribution scale to `0–100`. Inputs are finite scalars; work
and storage do not grow with input magnitude.

The shared channel is an analytical exclusive-resource premise, not a simulated network. There are
no configuration messages, acknowledgments, retries, schedule integrity checks,
transactional commit, consensus, loss, network I/O, blocking waits, timeouts, background
cancellation, clock servo, rate error, task execution, operating-system scheduling, or actual
rollback side effect. The policy merely classifies whether to select the new map or retain the old
one; no applied state transition is reversed.
Base MATLAB arithmetic and graphics are used; no toolbox is required.

## Files

- `model.m` — deterministic clocks, readiness, version selection, cyclic interval arithmetic,
  exhaustive collision-pair accounting, bounds, resource limits, and claim flags.
- `experiment.m` — baseline views, clock-error and activation-lead sweeps, and broken partial
  activation.
- `interactive.m` — clock bound, activation lead, distribution scale, activation policy, and reset.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — independent identities, limits, malformed recovery,
  interpretation prompts, and teach-back.

Static validation and independently recomputed arithmetic do not imply MATLAB-runtime, UI, MATLAB
numerical-fidelity, protocol, bench, HIL, field, deployment, or production validation.
